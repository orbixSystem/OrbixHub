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
import type { TxClient } from '../src/common/database/tenant-context';

/**
 * Captures every email the app would send. The dev mailer only logs the token,
 * so the e2e overrides MailerService to keep the raw invite token in memory —
 * the only way to drive the @Public POST /invites/accept end-to-end (it needs
 * the raw token, not the stored hash).
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

describe('IAM invite flow (e2e)', () => {
  let app: INestApplication;
  let redis: Redis;
  let mailer: CapturingMailer;
  let tenantCtx: TenantContext;

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
    tenantCtx = app.get(TenantContext);
  });

  beforeEach(async () => {
    await redis.flushall();
  });

  afterAll(async () => app?.close());

  const uniq = () => Math.random().toString(36).slice(2, 8);
  const decode = (token: string) => jwt.decode(token) as Record<string, unknown>;

  // Count memberships for a tenant under that tenant's RLS context (the only
  // way app_user can read RLS rows). Proves the membership write landed under
  // the correct tenant.
  async function membershipCount(tenantId: string): Promise<number> {
    return tenantCtx.runWithTenant(tenantId, async () => {
      const db = tenantCtx.getClient() as TxClient;
      const rows = await db.$queryRaw<Array<{ n: bigint }>>`
        SELECT count(*)::bigint AS n FROM membership
      `;
      return Number(rows[0].n);
    });
  }

  it('owner invites a mechanic; mechanic accepts and joins tenant A', async () => {
    // 1) register owner A
    const ownerEmail = `${uniq()}@ex.com`;
    const reg = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({
        tenantName: 'Oficina A',
        slug: `a-${uniq()}`,
        fullName: 'Owner A',
        email: ownerEmail,
        password: 'supersecret1',
      });
    expect(reg.status).toBe(201);
    const ownerAccess = reg.body.accessToken as string;
    const tenantA = reg.body.tenant.id as string;

    const before = await membershipCount(tenantA);

    // 2) owner A invites a new mechanic
    const mechEmail = `${uniq()}@ex.com`;
    const inv = await request(app.getHttpServer())
      .post('/api/tenants/invites')
      .set('Authorization', `Bearer ${ownerAccess}`)
      .send({ email: mechEmail, role: 'mechanic', currentPassword: 'supersecret1' });
    expect(inv.status).toBe(201);
    expect(inv.body).toEqual({ invited: true });

    // 3) capture the raw invite token from the mailer spy and accept it
    const token = mailer.lastTokenFor('invite', mechEmail);
    expect(token).toBeTruthy();

    const accept = await request(app.getHttpServer())
      .post('/api/invites/accept')
      .send({ token, fullName: 'Mecânico Novo', password: 'mechpass123' });
    expect(accept.status).toBe(200);
    expect(accept.body.accessToken).toBeTruthy();
    expect(accept.body.refreshToken).toBeTruthy();

    // the issued access token is scoped to tenant A with role mechanic
    const claims = decode(accept.body.accessToken as string);
    expect(claims.tid).toBe(tenantA);
    expect(claims.role).toBe('mechanic');

    // 4) membership for tenant A grew by exactly one
    const after = await membershipCount(tenantA);
    expect(after).toBe(before + 1);
  });

  it('rejects an unknown invite token with 400', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/invites/accept')
      .send({ token: 'totally-unknown', fullName: 'X', password: 'password123' });
    expect(res.status).toBe(400);
  });

  it('rejects accepting the same invite twice (already accepted)', async () => {
    // register owner B + invite + accept once
    const ownerEmail = `${uniq()}@ex.com`;
    const reg = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({
        tenantName: 'Oficina B',
        slug: `b-${uniq()}`,
        fullName: 'Owner B',
        email: ownerEmail,
        password: 'supersecret1',
      });
    const ownerAccess = reg.body.accessToken as string;
    const mechEmail = `${uniq()}@ex.com`;
    await request(app.getHttpServer())
      .post('/api/tenants/invites')
      .set('Authorization', `Bearer ${ownerAccess}`)
      .send({ email: mechEmail, role: 'mechanic', currentPassword: 'supersecret1' })
      .expect(201);
    const token = mailer.lastTokenFor('invite', mechEmail)!;
    await request(app.getHttpServer())
      .post('/api/invites/accept')
      .send({ token, fullName: 'Mec B', password: 'mechpass123' })
      .expect(200);

    // second accept must be rejected
    const second = await request(app.getHttpServer())
      .post('/api/invites/accept')
      .send({ token, fullName: 'Mec B', password: 'mechpass123' });
    expect(second.status).toBe(400);
  });
});
