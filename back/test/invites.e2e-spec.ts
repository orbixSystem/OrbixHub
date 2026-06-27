import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import Redis from 'ioredis';
import { AppModule } from '../src/app.module';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';
import { REDIS } from '../src/common/redis/redis.module';
import { randomCnpj } from './helpers/cnpj';
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

interface PendingInvite {
  id: string;
  email: string;
  role: string;
  expiresAt: string | null;
  createdAt: string;
}

describe('Invites lifecycle (e2e)', () => {
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

  /** Register a brand-new owner + tenant. */
  async function registerOwner(): Promise<Owner> {
    const email = `${uniq()}@ex.com`;
    const reg = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({
        tenantName: `Oficina ${uniq()}`,
        cnpj: randomCnpj(),
        legalName: 'Razão Social Teste',
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

  async function listInvites(access: string): Promise<PendingInvite[]> {
    const res = await request(app.getHttpServer())
      .get('/api/invites')
      .set('Authorization', `Bearer ${access}`);
    expect(res.status).toBe(200);
    return res.body as PendingInvite[];
  }

  const findInvite = (invites: PendingInvite[], email: string) =>
    invites.find((i) => i.email === email.toLowerCase());

  /** Owner sends an invite; returns the (lowercased) email + the captured raw token. */
  async function createInvite(
    owner: Owner,
    opts: { role?: string; expiresIn?: string } = {},
  ): Promise<{ email: string; token: string }> {
    const email = `${uniq()}@ex.com`;
    const res = await request(app.getHttpServer())
      .post('/api/tenants/invites')
      .set('Authorization', `Bearer ${owner.access}`)
      .send({
        email,
        role: opts.role ?? 'mechanic',
        ...(opts.expiresIn ? { expiresIn: opts.expiresIn } : {}),
        currentPassword: owner.password,
      });
    expect(res.status).toBe(201);
    const token = mailer.lastTokenFor('invite', email.toLowerCase());
    expect(token).toBeTruthy();
    return { email: email.toLowerCase(), token: token! };
  }

  const accept = (token: string) =>
    request(app.getHttpServer())
      .post('/api/invites/accept')
      .send({ token, fullName: 'Member', password: 'memberpass123' });

  // 1 — create + list
  it('creates an invite and lists it as pending with expiresAt set', async () => {
    const owner = await registerOwner();
    const { email } = await createInvite(owner, {
      role: 'mechanic',
      expiresIn: '15min',
    });

    const invites = await listInvites(owner.access);
    const found = findInvite(invites, email);
    expect(found).toBeTruthy();
    expect(found!.role).toBe('mechanic');
    expect(found!.expiresAt).not.toBeNull();
  });

  // 2 — resend invalidates old token
  it('resend rotates the token: old token dies, new token accepts', async () => {
    const owner = await registerOwner();
    const { email, token: t1 } = await createInvite(owner, {
      expiresIn: '15min',
    });

    const invites = await listInvites(owner.access);
    const found = findInvite(invites, email);
    expect(found).toBeTruthy();

    const res = await request(app.getHttpServer())
      .post(`/api/invites/${found!.id}/resend`)
      .set('Authorization', `Bearer ${owner.access}`)
      .send({ currentPassword: owner.password });
    expect(res.status).toBe(200);

    const t2 = mailer.lastTokenFor('invite', email);
    expect(t2).toBeTruthy();
    expect(t2).not.toBe(t1);

    // old token is dead
    const oldAccept = await accept(t1);
    expect(oldAccept.status).toBe(400);

    // new token works
    const newAccept = await accept(t2!);
    expect(newAccept.status).toBe(200);
    expect(newAccept.body.accessToken).toBeTruthy();
  });

  // 3 — cancel
  it('cancel removes the invite from the pending list and kills its token', async () => {
    const owner = await registerOwner();
    const { email, token } = await createInvite(owner, { expiresIn: '1day' });

    const invites = await listInvites(owner.access);
    const found = findInvite(invites, email);
    expect(found).toBeTruthy();

    const del = await request(app.getHttpServer())
      .delete(`/api/invites/${found!.id}`)
      .set('Authorization', `Bearer ${owner.access}`);
    expect(del.status).toBe(200);
    expect(del.body.ok).toBe(true);

    const after = await listInvites(owner.access);
    expect(findInvite(after, email)).toBeFalsy();

    const acc = await accept(token);
    expect(acc.status).toBe(400);
  });

  // 4 — never expiry
  it('expiresIn:never stores a null expiry and still accepts', async () => {
    const owner = await registerOwner();
    const { email, token } = await createInvite(owner, { expiresIn: 'never' });

    const invites = await listInvites(owner.access);
    const found = findInvite(invites, email);
    expect(found).toBeTruthy();
    expect(found!.expiresAt).toBeNull();

    const acc = await accept(token);
    expect(acc.status).toBe(200);
    expect(acc.body.accessToken).toBeTruthy();
  });

  // 5 — single-use
  it('a token cannot be reused after a successful accept', async () => {
    const owner = await registerOwner();
    const { token } = await createInvite(owner, { expiresIn: '1day' });

    const first = await accept(token);
    expect(first.status).toBe(200);

    const second = await accept(token);
    expect(second.status).toBe(400);
  });

  // 6 — isolation
  it("owner B cannot see or cancel owner A's invites", async () => {
    const ownerA = await registerOwner();
    const { email: emailA, id: idA } = await (async () => {
      const created = await createInvite(ownerA, { expiresIn: '1day' });
      const invites = await listInvites(ownerA.access);
      const found = findInvite(invites, created.email);
      expect(found).toBeTruthy();
      return { email: created.email, id: found!.id };
    })();

    const ownerB = await registerOwner();

    // B's pending list does not leak A's invite
    const bInvites = await listInvites(ownerB.access);
    expect(findInvite(bInvites, emailA)).toBeFalsy();

    // B cannot cancel A's invite (invisible under B's RLS -> 400 not found)
    const del = await request(app.getHttpServer())
      .delete(`/api/invites/${idA}`)
      .set('Authorization', `Bearer ${ownerB.access}`);
    expect(del.status).toBe(400);
    expect(del.status).not.toBe(200);

    // A's invite still pending
    const aInvites = await listInvites(ownerA.access);
    expect(findInvite(aInvites, emailA)).toBeTruthy();
  });
});
