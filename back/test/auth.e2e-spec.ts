import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import Redis from 'ioredis';
import { AppModule } from '../src/app.module';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';
import { REDIS } from '../src/common/redis/redis.module';
import { randomCnpj } from './helpers/cnpj';

describe('Auth flows (e2e)', () => {
  let app: INestApplication;
  let redis: Redis;
  // Both the global ThrottlerGuard (IP tracker) and the strict AuthThrottlerGuard
  // (IP+email tracker) share one Redis store. @Throttle(STRICT) lowers the limit
  // to 5/min on register/login/forgot for BOTH guards, and the global guard's
  // IP-only key is shared across every test (all run from 127.0.0.1). Flush the
  // store before each test so cross-test accumulation does not bleed into the
  // next test; criterion 4 still trips its own 5/min within a single test.
  beforeEach(async () => {
    await redis.flushall();
  });
  beforeAll(async () => {
    const mod = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
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
  });
  afterAll(async () => app?.close());

  const uniq = () => Math.random().toString(36).slice(2, 8);

  it('criterion 6: register creates tenant+owner+membership+trial atomically', async () => {
    const slug = `ofc-${uniq()}`;
    const res = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({
        tenantName: 'Oficina Teste',
        cnpj: randomCnpj(),
        legalName: 'Razão Social Teste',
        slug,
        fullName: 'Dona Maria',
        email: `${uniq()}@ex.com`,
        password: 'supersecret1',
      });
    expect(res.status).toBe(201);
    expect(res.body.accessToken).toBeTruthy();
    expect(res.body.refreshToken).toBeTruthy();
    expect(res.body.tenant.slug).toBe(slug);
  });

  it('criterion 8: invalid/reserved slug is rejected', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({
        tenantName: 'Oficina Reservada',
        cnpj: randomCnpj(),
        legalName: 'Razão Social Teste',
        slug: 'api',
        fullName: 'Ana Souza',
        email: `${uniq()}@ex.com`,
        password: 'supersecret1',
      });
    expect(res.status).toBe(400);
  });

  it('criterion 5: login does not reveal whether an email exists', async () => {
    const unknown = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ email: `${uniq()}@nope.com`, password: 'whatever1' });
    // register a user, then wrong password
    const email = `${uniq()}@ex.com`;
    await request(app.getHttpServer()).post('/api/auth/register').send({
      tenantName: 'Zona Oficina',
      cnpj: randomCnpj(),
      legalName: 'Razão Social Teste',
      slug: `z-${uniq()}`,
      fullName: 'Zeca Silva',
      email,
      password: 'supersecret1',
    });
    const wrong = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ email, password: 'wrongpass1' });
    expect(unknown.status).toBe(401);
    expect(wrong.status).toBe(401);
    expect(unknown.body.message).toBe(wrong.body.message); // identical generic
  });

  it('criterion 3: refresh rotates; the rotated token works', async () => {
    const email = `${uniq()}@ex.com`;
    const reg = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({
        tenantName: 'Rede Oficina',
        cnpj: randomCnpj(),
        legalName: 'Razão Social Teste',
        slug: `r-${uniq()}`,
        fullName: 'Rui Mendes',
        email,
        password: 'supersecret1',
      });
    const first = reg.body.refreshToken;
    const rot = await request(app.getHttpServer())
      .post('/api/auth/refresh')
      .send({ refreshToken: first });
    expect(rot.status).toBe(200);
    expect(rot.body.refreshToken).not.toBe(first);
    // The new (rotated) token is usable. Family revocation on out-of-tolerance
    // reuse is exercised in the RefreshService unit test (Task 5.3).
    const useNew = await request(app.getHttpServer())
      .post('/api/auth/refresh')
      .send({ refreshToken: rot.body.refreshToken });
    expect(useNew.status).toBe(200);
  });

  it('criterion 4: login is rate-limited after repeated attempts', async () => {
    const email = `${uniq()}@ex.com`;
    let last = 200;
    for (let i = 0; i < 8; i++) {
      const r = await request(app.getHttpServer())
        .post('/api/auth/login')
        .send({ email, password: 'badpassword1' });
      last = r.status;
    }
    expect([401, 429]).toContain(last);
    expect(last).toBe(429); // strict limit (5/min) should trip
  });

  it('criterion 7: register persists; GET /me reflects the committed identity', async () => {
    // DevMailer never throws; the verification email is sent post-commit, so a
    // mailer failure cannot roll back register. Now that Phase 7 ships GET /me,
    // we prove persistence by calling /me with the register accessToken: it only
    // returns 200 with the tenant/role/modules if user+tenant+membership+trial
    // were committed. (Re-login is also checked as a belt-and-braces commit
    // proof.)
    const email = `${uniq()}@ex.com`;
    const password = 'supersecret1';
    const slug = `m-${uniq()}`;
    const reg = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({
        tenantName: 'Mecânica Central',
        cnpj: randomCnpj(),
        legalName: 'Razão Social Teste',
        slug,
        fullName: 'Marta Lima',
        email,
        password,
      });
    expect(reg.status).toBe(201);
    const accessToken = reg.body.accessToken as string;
    expect(accessToken).toBeTruthy();

    const me = await request(app.getHttpServer())
      .get('/api/me')
      .set('Authorization', `Bearer ${accessToken}`);
    expect(me.status).toBe(200);
    expect(me.body.activeTenant.slug).toBe(slug);
    expect(me.body.role).toBe('owner');
    // Trial plan enables os + customers (RLS-scoped tenant_module read).
    expect(me.body.modules).toEqual(
      expect.arrayContaining(['os', 'customers']),
    );

    const relogin = await request(app.getHttpServer())
      .post('/api/auth/login')
      .send({ email, password });
    expect(relogin.status).toBe(200);
    expect(relogin.body.accessToken).toBeTruthy();
    expect(relogin.body.memberships).toHaveLength(1);
  });

  it('rejects a register that reuses an already-taken CNPJ', async () => {
    const cnpj = randomCnpj();
    const first = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({
        tenantName: 'Oficina CNPJ Um',
        cnpj,
        legalName: 'Razão Social Teste',
        slug: `cnpj1-${uniq()}`,
        fullName: 'Owner Um',
        email: `${uniq()}@ex.com`,
        password: 'supersecret1',
      });
    expect(first.status).toBe(201);

    const second = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({
        tenantName: 'Oficina CNPJ Dois',
        cnpj,
        legalName: 'Razão Social Teste',
        slug: `cnpj2-${uniq()}`,
        fullName: 'Owner Dois',
        email: `${uniq()}@ex.com`,
        password: 'supersecret1',
      });
    expect(second.status).toBe(409);
  });
});
