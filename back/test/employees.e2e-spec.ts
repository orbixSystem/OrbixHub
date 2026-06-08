import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import Redis from 'ioredis';
import * as jwt from 'jsonwebtoken';
import { AppModule } from '../src/app.module';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';
import { REDIS } from '../src/common/redis/redis.module';
import { MailerService, VerificationEmail } from '../src/common/mailer/mailer.service';
import { TenantContext } from '../src/common/database/tenant-context';

/**
 * Captures every email the app would send so the e2e can read the raw invite
 * token (the only way to drive @Public POST /invites/accept end-to-end — it
 * needs the raw token, not the stored hash).
 */
class CapturingMailer extends MailerService {
  public readonly sent: VerificationEmail[] = [];
  async send(email: VerificationEmail): Promise<void> {
    this.sent.push(email);
  }
  lastTokenFor(kind: VerificationEmail['kind'], to: string): string | undefined {
    const hit = [...this.sent]
      .reverse()
      .find((e) => e.kind === kind && e.to === to);
    return hit?.token;
  }
}

interface Owner {
  access: string;
  tenantId: string;
  email: string;
  password: string;
}

interface Member {
  access: string;
  refresh: string;
  email: string;
  password: string;
}

interface Employee {
  membershipId: string;
  userId: string;
  fullName: string;
  email: string;
  role: string;
  status: string;
  lastAccess: string | null;
}

describe('Employees feature (e2e)', () => {
  let app: INestApplication;
  let redis: Redis;
  let mailer: CapturingMailer;

  const OWNER_PW = 'supersecret1';

  beforeAll(async () => {
    mailer = new CapturingMailer();
    const mod = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(MailerService)
      .useValue(mailer)
      .compile();
    app = mod.createNestApplication();
    app.setGlobalPrefix('api');
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
    app.useGlobalFilters(new AllExceptionsFilter());
    await app.init();
    redis = app.get<Redis>(REDIS);
    app.get(TenantContext);
  });

  beforeEach(async () => {
    await redis.flushall();
  });

  afterAll(async () => app?.close());

  const uniq = () => Math.random().toString(36).slice(2, 8);
  const decode = (token: string) => jwt.decode(token) as Record<string, unknown>;

  /** Register a brand-new owner + tenant. */
  async function registerOwner(): Promise<Owner> {
    const email = `${uniq()}@ex.com`;
    const reg = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({
        tenantName: `Oficina ${uniq()}`,
        slug: `t-${uniq()}`,
        fullName: 'Owner',
        email,
        password: OWNER_PW,
      });
    expect(reg.status).toBe(201);
    return {
      access: reg.body.accessToken as string,
      tenantId: reg.body.tenant.id as string,
      email,
      password: OWNER_PW,
    };
  }

  /** Owner invites a member with `role`; the member accepts and gets a token. */
  async function inviteAccept(owner: Owner, role: string): Promise<Member> {
    const email = `${uniq()}@ex.com`;
    const password = 'memberpass123';
    const inv = await request(app.getHttpServer())
      .post('/api/tenants/invites')
      .set('Authorization', `Bearer ${owner.access}`)
      .send({ email, role, currentPassword: owner.password });
    expect(inv.status).toBe(201);

    const token = mailer.lastTokenFor('invite', email);
    expect(token).toBeTruthy();

    const accept = await request(app.getHttpServer())
      .post('/api/invites/accept')
      .send({ token, fullName: 'Member', password });
    expect(accept.status).toBe(200);
    return {
      access: accept.body.accessToken as string,
      refresh: accept.body.refreshToken as string,
      email,
      password,
    };
  }

  async function listEmployees(access: string): Promise<Employee[]> {
    const res = await request(app.getHttpServer())
      .get('/api/employees')
      .set('Authorization', `Bearer ${access}`);
    expect(res.status).toBe(200);
    return res.body as Employee[];
  }

  const byEmail = (emps: Employee[], email: string) =>
    emps.find((e) => e.email === email);
  const byRole = (emps: Employee[], role: string) =>
    emps.find((e) => e.role === role);

  // ---- Criterion 1: seeds / roles --------------------------------------
  describe('Criterion 1 — seeded roles & permissions', () => {
    it('GET /api/roles exposes gerente/caixa/mechanic with the right permission sets', async () => {
      const owner = await registerOwner();
      const res = await request(app.getHttpServer())
        .get('/api/roles')
        .set('Authorization', `Bearer ${owner.access}`);
      expect(res.status).toBe(200);

      const roles = res.body as Array<{ key: string; permissions: string[] }>;
      const find = (key: string) => roles.find((r) => r.key === key);

      const gerente = find('gerente');
      expect(gerente).toBeTruthy();
      expect(gerente!.permissions).toEqual(
        expect.arrayContaining(['users.manage', 'os.write', 'tenant.manage']),
      );
      expect(gerente!.permissions).not.toContain('billing.manage');

      const caixa = find('caixa');
      expect(caixa).toBeTruthy();
      expect(caixa!.permissions).toEqual(
        expect.arrayContaining([
          'cashier.read',
          'cashier.write',
          'invoice.issue',
          'customer.write',
        ]),
      );
      expect(caixa!.permissions).not.toContain('billing.manage');
      expect(caixa!.permissions).not.toContain('users.manage');

      const mechanic = find('mechanic');
      expect(mechanic).toBeTruthy();
      expect(mechanic!.permissions).toEqual(
        expect.arrayContaining([
          'tracking.manage',
          'subject.read',
          'subject.write',
          'customer.write',
        ]),
      );
      expect(mechanic!.permissions).not.toContain('cashier.read');
    });
  });

  // ---- Criterion 2: permission gate + reauth ---------------------------
  describe('Criterion 2 — permission gate & reauth', () => {
    it('mechanic without users.manage cannot list employees (403)', async () => {
      const owner = await registerOwner();
      const mech = await inviteAccept(owner, 'mechanic');

      const res = await request(app.getHttpServer())
        .get('/api/employees')
        .set('Authorization', `Bearer ${mech.access}`);
      expect(res.status).toBe(403);
    });

    it('changeRole without currentPassword is 400; with wrong password is 401', async () => {
      const owner = await registerOwner();
      const mech = await inviteAccept(owner, 'mechanic');
      const emps = await listEmployees(owner.access);
      const target = byEmail(emps, mech.email);
      expect(target).toBeTruthy();

      // missing currentPassword -> validation 400
      const missing = await request(app.getHttpServer())
        .patch(`/api/employees/${target!.membershipId}/role`)
        .set('Authorization', `Bearer ${owner.access}`)
        .send({ role: 'caixa' });
      expect(missing.status).toBe(400);

      // wrong currentPassword -> reauth 401
      const wrong = await request(app.getHttpServer())
        .patch(`/api/employees/${target!.membershipId}/role`)
        .set('Authorization', `Bearer ${owner.access}`)
        .send({ role: 'caixa', currentPassword: 'wrong' });
      expect(wrong.status).toBe(401);
    });
  });

  // ---- Criterion 3: guardrails -----------------------------------------
  describe('Criterion 3 — guardrails', () => {
    it('enforces last-owner, self-role, owner-grant, self-deactivate, and no-hard-delete', async () => {
      const ownerA = await registerOwner();
      const gerente = await inviteAccept(ownerA, 'gerente');

      let emps = await listEmployees(ownerA.access);
      const aMembership = byRole(emps, 'owner');
      const gMembership = byEmail(emps, gerente.email);
      expect(aMembership).toBeTruthy();
      expect(gMembership).toBeTruthy();

      // G1 — last owner: gerente tries to demote the only active owner -> 400
      const lastOwner = await request(app.getHttpServer())
        .patch(`/api/employees/${aMembership!.membershipId}/role`)
        .set('Authorization', `Bearer ${gerente.access}`)
        .send({ role: 'mechanic', currentPassword: gerente.password });
      expect(lastOwner.status).toBe(400);

      // G2 — self role: owner A tries to change their own role -> 403
      const selfRole = await request(app.getHttpServer())
        .patch(`/api/employees/${aMembership!.membershipId}/role`)
        .set('Authorization', `Bearer ${ownerA.access}`)
        .send({ role: 'gerente', currentPassword: ownerA.password });
      expect(selfRole.status).toBe(403);

      // G3 — only owner grants owner: gerente promotes a third member to owner -> 403
      const mechX = await inviteAccept(ownerA, 'mechanic');
      emps = await listEmployees(ownerA.access);
      const xMembership = byEmail(emps, mechX.email);
      expect(xMembership).toBeTruthy();
      const grantOwner = await request(app.getHttpServer())
        .patch(`/api/employees/${xMembership!.membershipId}/role`)
        .set('Authorization', `Bearer ${gerente.access}`)
        .send({ role: 'owner', currentPassword: gerente.password });
      expect(grantOwner.status).toBe(403);

      // G5 — self deactivate: owner A tries to deactivate themselves -> 403
      const selfDeact = await request(app.getHttpServer())
        .post(`/api/employees/${aMembership!.membershipId}/deactivate`)
        .set('Authorization', `Bearer ${ownerA.access}`)
        .send({ currentPassword: ownerA.password });
      expect(selfDeact.status).toBe(403);

      // G4 — deactivate gerente: 200, then still listed as disabled (no delete)
      const deact = await request(app.getHttpServer())
        .post(`/api/employees/${gMembership!.membershipId}/deactivate`)
        .set('Authorization', `Bearer ${ownerA.access}`)
        .send({ currentPassword: ownerA.password });
      expect(deact.status).toBe(200);

      emps = await listEmployees(ownerA.access);
      const gAfterDeact = byEmail(emps, gerente.email);
      expect(gAfterDeact).toBeTruthy(); // member NOT deleted
      expect(gAfterDeact!.status).toBe('disabled');

      // re-activate -> 200 and status back to active
      const act = await request(app.getHttpServer())
        .post(`/api/employees/${gMembership!.membershipId}/activate`)
        .set('Authorization', `Bearer ${ownerA.access}`)
        .send({ currentPassword: ownerA.password });
      expect(act.status).toBe(200);

      emps = await listEmployees(ownerA.access);
      const gAfterAct = byEmail(emps, gerente.email);
      expect(gAfterAct!.status).toBe('active');
    });
  });

  // ---- Criterion 8: deactivation revokes the live session --------------
  describe('Criterion 8 — deactivation kills the session immediately', () => {
    it('blocks a deactivated member on the existing access token AND on refresh', async () => {
      const owner = await registerOwner();
      const gerente = await inviteAccept(owner, 'gerente');

      // Sanity: while active, gerente (users.manage) can list employees.
      const before = await request(app.getHttpServer())
        .get('/api/employees')
        .set('Authorization', `Bearer ${gerente.access}`);
      expect(before.status).toBe(200);

      // Owner deactivates the gerente.
      const emps = await listEmployees(owner.access);
      const gMembership = byEmail(emps, gerente.email);
      expect(gMembership).toBeTruthy();
      const deact = await request(app.getHttpServer())
        .post(`/api/employees/${gMembership!.membershipId}/deactivate`)
        .set('Authorization', `Bearer ${owner.access}`)
        .send({ currentPassword: owner.password });
      expect(deact.status).toBe(200);

      // The SAME, still-unexpired access token is now rejected per-request.
      const after = await request(app.getHttpServer())
        .get('/api/employees')
        .set('Authorization', `Bearer ${gerente.access}`);
      expect(after.status).toBe(401);

      // And the refresh token can no longer mint a fresh access token.
      const refreshed = await request(app.getHttpServer())
        .post('/api/auth/refresh')
        .send({ refreshToken: gerente.refresh });
      expect(refreshed.status).toBe(401);
    });
  });

  // ---- Criterion 7: tenant isolation -----------------------------------
  describe('Criterion 7 — tenant isolation', () => {
    it("tenant B cannot see or mutate tenant A's memberships", async () => {
      const ownerA = await registerOwner();
      const member = await inviteAccept(ownerA, 'gerente');
      const aEmps = await listEmployees(ownerA.access);
      const aMembership = byRole(aEmps, 'owner');
      expect(aMembership).toBeTruthy();

      const ownerB = await registerOwner();
      const bEmps = await listEmployees(ownerB.access);

      // none of tenant A's members leak into tenant B's list
      const aEmails = new Set(aEmps.map((e) => e.email));
      for (const e of bEmps) {
        expect(aEmails.has(e.email)).toBe(false);
      }
      expect(bEmps.find((e) => e.email === member.email)).toBeFalsy();
      expect(bEmps.find((e) => e.email === ownerA.email)).toBeFalsy();

      // B cannot mutate A's membership: invisible under B's RLS -> 400 not found
      const cross = await request(app.getHttpServer())
        .patch(`/api/employees/${aMembership!.membershipId}/role`)
        .set('Authorization', `Bearer ${ownerB.access}`)
        .send({ role: 'mechanic', currentPassword: ownerB.password });
      expect(cross.status).toBe(400);
      expect(cross.status).not.toBe(200);

      // A's owner membership is unchanged
      const aEmpsAfter = await listEmployees(ownerA.access);
      const aOwnerAfter = byRole(aEmpsAfter, 'owner');
      expect(aOwnerAfter).toBeTruthy();
      expect(decode(ownerA.access).role).toBe('owner');
    });
  });
});
