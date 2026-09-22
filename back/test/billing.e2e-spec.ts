import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import Redis from 'ioredis';
import { AppModule } from '../src/app.module';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';
import { REDIS } from '../src/common/redis/redis.module';
import { randomCnpj } from './helpers/cnpj';
import { PrismaService } from '../src/common/database/prisma.service';
import { TenantContext } from '../src/common/database/tenant-context';
import { NoopPaymentGateway } from '../src/modules/billing/payment/noop-payment-gateway';

const uniq = () => Math.random().toString(36).slice(2, 8);
const SECRET = process.env.BILLING_WEBHOOK_SECRET ?? 'dev_billing_webhook_secret_change_me';

async function registerOwner(app: INestApplication) {
  const email = `${uniq()}@ex.com`;
  const slug = `b-${uniq()}`;
  const res = await request(app.getHttpServer()).post('/api/auth/register').send({
    tenantName: 'Oficina B', cnpj: randomCnpj(), legalName: 'Razão Social Teste', slug, fullName: 'Owner B', email, password: 'supersecret1',
  });
  return { token: res.body.accessToken as string, tenantId: res.body.tenant.id as string, slug };
}

describe('Billing (e2e)', () => {
  let app: INestApplication;
  let redis: Redis;
  let prisma: PrismaService;
  let tenant: TenantContext;

  beforeAll(async () => {
    const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = mod.createNestApplication({ rawBody: true });
    app.setGlobalPrefix('api');
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
    app.useGlobalFilters(new AllExceptionsFilter());
    await app.init();
    redis = app.get<Redis>(REDIS);
    prisma = app.get(PrismaService);
    tenant = app.get(TenantContext);
  });
  beforeEach(async () => { await redis.flushall(); });
  afterAll(async () => { await app?.close(); });

  // Criterion 9: createTrial ran inside register -> trial sub + modules exist
  it('register provisions a trialing subscription and trial modules', async () => {
    const { token } = await registerOwner(app);
    const sub = await request(app.getHttpServer())
      .get('/api/billing/subscription').set('Authorization', `Bearer ${token}`);
    expect(sub.status).toBe(200);
    expect(sub.body.status).toBe('trialing');
    expect(sub.body.trialEndsAt).toBeTruthy();
  });

  // Criterion 8: invalid planKey rejected
  it('subscribe with an unknown plan -> 400', async () => {
    const { token } = await registerOwner(app);
    const res = await request(app.getHttpServer())
      .post('/api/billing/subscribe').set('Authorization', `Bearer ${token}`).send({ planKey: 'nope' });
    expect(res.status).toBe(400);
  });

  // Criterion 1: subscribe populates tenant_module from plan_module (idempotent)
  it('subscribe to pro enables pro modules; repeat is idempotent', async () => {
    const { token, tenantId } = await registerOwner(app);
    const first = await request(app.getHttpServer())
      .post('/api/billing/subscribe').set('Authorization', `Bearer ${token}`).send({ planKey: 'pro' });
    expect(first.status).toBe(200);
    const me1 = await request(app.getHttpServer()).get('/api/me').set('Authorization', `Bearer ${token}`);
    expect(me1.body.modules).toEqual(expect.arrayContaining(['os', 'inventory', 'customers']));

    await request(app.getHttpServer())
      .post('/api/billing/subscribe').set('Authorization', `Bearer ${token}`).send({ planKey: 'pro' });
    const count = await tenant.runWithTenant(tenantId, async () => {
      const db = tenant.getClient();
      return db.tenant_module.count({ where: { enabled: true } });
    });
    expect(count).toBeGreaterThanOrEqual(3);
  });

  // Criterion 4 + 5: webhook idempotency, signature, tenant resolution
  it('webhook: invalid signature -> 400 and no change; valid -> status update; duplicate -> no-op', async () => {
    const { tenantId } = await registerOwner(app);
    const extId = `noop_sub_${tenantId}_pro`;
    await tenant.runWithTenant(tenantId, async () => {
      const db = tenant.getClient();
      const sub = await db.subscription.findFirst();
      await db.subscription.update({ where: { id: sub!.id }, data: { external_subscription_id: extId } });
    });

    const body = JSON.stringify({ id: `evt_${uniq()}`, type: 'subscription.past_due', data: { subscriptionId: extId } });
    const sig = NoopPaymentGateway.sign(body, SECRET);

    const bad = await request(app.getHttpServer())
      .post('/api/billing/webhook').set('x-webhook-signature', 'bad').set('content-type', 'application/json').send(body);
    expect(bad.status).toBe(400);

    const ok = await request(app.getHttpServer())
      .post('/api/billing/webhook').set('x-webhook-signature', sig).set('content-type', 'application/json').send(body);
    expect(ok.status).toBe(200);
    const after = await tenant.runWithTenant(tenantId, async () => {
      const db = tenant.getClient();
      return (await db.subscription.findFirst())!.status;
    });
    expect(after).toBe('past_due');

    const dup = await request(app.getHttpServer())
      .post('/api/billing/webhook').set('x-webhook-signature', sig).set('content-type', 'application/json').send(body);
    expect(dup.status).toBe(200);
  });

  // Criterion 7: tenant isolation
  it('tenant isolation: subscribing tenant A does not change tenant B modules', async () => {
    const a = await registerOwner(app);
    const b = await registerOwner(app);
    const subA = await request(app.getHttpServer()).get('/api/billing/subscription').set('Authorization', `Bearer ${a.token}`);
    const subB = await request(app.getHttpServer()).get('/api/billing/subscription').set('Authorization', `Bearer ${b.token}`);
    expect(subA.body.status).toBe('trialing');
    expect(subB.body.status).toBe('trialing');
    await request(app.getHttpServer()).post('/api/billing/subscribe').set('Authorization', `Bearer ${a.token}`).send({ planKey: 'pro' });
    const meB = await request(app.getHttpServer()).get('/api/me').set('Authorization', `Bearer ${b.token}`);
    // B continua com exatamente os módulos do trial (A assinar pro não vaza pra B).
    // trial = cashier+customers+expenses+inventory+invoice+os+report+sale (plan_module seed).
    expect([...(meB.body.modules as string[])].sort()).toEqual(
      ['cashier', 'customers', 'expenses', 'inventory', 'invoice', 'os', 'report', 'sale'],
    );
  });
});
