import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import Redis from 'ioredis';
import { AppModule } from '../src/app.module';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';
import { REDIS } from '../src/common/redis/redis.module';

/**
 * Exercises GET /me end-to-end under a real authenticated request. This is the
 * only test that drives the RLS-backed enabledModules() through the
 * mount:true CLS path for a @CurrentUser route (Phase 6 fix): the tenant id
 * verified from the JWT is stored in CLS by the interceptor, and
 * withTenantTx() must see it so the tenant_module read returns the trial
 * modules instead of zero rows.
 */
describe('GET /api/me (e2e)', () => {
  let app: INestApplication;
  let redis: Redis;

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
  beforeEach(async () => {
    await redis.flushall();
  });
  afterAll(async () => app?.close());

  const uniq = () => Math.random().toString(36).slice(2, 8);

  it('returns the full identity for a freshly-registered owner', async () => {
    const email = `${uniq()}@ex.com`;
    const slug = `me-${uniq()}`;
    const tenantName = 'Oficina Me';
    const reg = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({
        tenantName,
        slug,
        fullName: 'Owner Me',
        email,
        password: 'supersecret1',
      });
    expect(reg.status).toBe(201);
    const accessToken = reg.body.accessToken as string;
    const tenantId = reg.body.tenant.id as string;

    const res = await request(app.getHttpServer())
      .get('/api/me')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(res.status).toBe(200);

    // user
    expect(res.body.user.email).toBe(email);
    expect(res.body.user.fullName).toBe('Owner Me');

    // activeTenant
    expect(res.body.activeTenant).toMatchObject({
      id: tenantId,
      slug,
      name: tenantName,
    });

    // role
    expect(res.body.role).toBe('owner');

    // permissions (owner has all)
    expect(res.body.permissions).toEqual(
      expect.arrayContaining(['users.manage', 'tenant.manage']),
    );

    // modules (trial plan enables os + customers) — RLS-scoped read
    expect(res.body.modules).toEqual(
      expect.arrayContaining(['os', 'customers']),
    );

    // memberships — exactly one (the registered tenant)
    expect(res.body.memberships).toHaveLength(1);
    expect(res.body.memberships[0]).toMatchObject({
      tenantSlug: slug,
      role: 'owner',
    });
  });

  it('rejects an unauthenticated request', async () => {
    const res = await request(app.getHttpServer()).get('/api/me');
    expect(res.status).toBe(401);
  });
});
