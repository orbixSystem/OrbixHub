import { Global, INestApplication, Module, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import Redis from 'ioredis';
import { AppModule } from '../src/app.module';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';
import { REDIS } from '../src/common/redis/redis.module';
import { randomCnpj } from './helpers/cnpj';
import { TenantContext } from '../src/common/database/tenant-context';

interface InboxEntry {
  type: string;
  label: string;
  value: string;
  createdAt: string;
}

const uniq = () => Math.random().toString(36).slice(2, 8);
const OWNER_PW = 'supersecret1';

async function registerOwner(app: INestApplication): Promise<string> {
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
  return reg.body.accessToken as string;
}

async function sendInvite(app: INestApplication, access: string): Promise<void> {
  const res = await request(app.getHttpServer())
    .post('/api/tenants/invites')
    .set('Authorization', `Bearer ${access}`)
    .send({
      email: `${uniq()}@ex.com`,
      role: 'mechanic',
      currentPassword: OWNER_PW,
    });
  expect(res.status).toBe(201);
}

// ---- (b1) ENABLED — .env default DEV_TOOLS_ENABLED=true -------------------
// No mailer override here: the app's real DevMailerService records the invite
// link into DevInboxService, which is exactly what GET /dev/inbox exposes.
describe('dev tools ENABLED', () => {
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
    app.get(TenantContext);
  });

  beforeEach(async () => {
    await redis.flushall();
  });

  afterAll(async () => app?.close());

  it('GET /dev/inbox (public) exposes the latest invite link', async () => {
    const access = await registerOwner(app);
    await sendInvite(app, access);

    const res = await request(app.getHttpServer()).get('/api/dev/inbox');
    expect(res.status).toBe(200);

    const entries = res.body as InboxEntry[];
    const invite = entries.find((e) => e.type === 'invite');
    expect(invite).toBeTruthy();
    expect(invite!.value).toContain('/convite/');
  });

  it('keeps only the latest invite entry after a resend', async () => {
    const access = await registerOwner(app);
    await sendInvite(app, access);
    await sendInvite(app, access);

    const res = await request(app.getHttpServer()).get('/api/dev/inbox');
    expect(res.status).toBe(200);

    const entries = res.body as InboxEntry[];
    const invites = entries.filter((e) => e.type === 'invite');
    expect(invites).toHaveLength(1);
    expect(invites[0].value).toContain('/convite/');
  });
});

// ---- (b2) PROD GATE — DEV_TOOLS_ENABLED off -> 404 (Criterion 9) ---------
//
// DevtoolsModule decides whether to register DevController from
// `process.env.DEV_TOOLS_ENABLED` at MODULE-IMPORT TIME (a top-level const). To
// exercise the OFF state we force a fresh evaluation of that const with the env
// flipped to 'false', then mount the freshly-imported DevtoolsModule on its own.
//
// We deliberately do NOT re-import the whole AppModule here: jest.resetModules()
// also reloads @nestjs/core, which duplicates the `Reflector` token and breaks
// DI for the full graph. DevtoolsModule only depends on ENV, so mounting it in
// isolation (with a stub ENV provider) re-runs its top-level const cleanly and
// proves the gate: env off => DevController absent => GET /dev/inbox is 404.
describe('dev tools DISABLED (prod gate)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const prev = process.env.DEV_TOOLS_ENABLED;
    process.env.DEV_TOOLS_ENABLED = 'false';
    jest.resetModules();
    // re-import AFTER flipping the env so the top-level `devEnabled` const in
    // DevtoolsModule re-evaluates to false (=> controllers: []).
    const { DevtoolsModule } = await import(
      '../src/modules/devtools/devtools.module'
    );
    const { ENV } = await import('../src/common/config/config.module');

    // DevtoolsModule depends (via DevInboxService) on the global ENV token. Wrap
    // a stub in a @Global module so it's visible inside DevtoolsModule's context.
    @Global()
    @Module({
      providers: [
        { provide: ENV, useValue: { APP_PUBLIC_URL: 'http://localhost:8090' } },
      ],
      exports: [ENV],
    })
    class StubEnvModule {}

    const mod = await Test.createTestingModule({
      imports: [StubEnvModule, DevtoolsModule],
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
    process.env.DEV_TOOLS_ENABLED = prev; // restore for any later suites
  });

  afterAll(async () => app?.close());

  it('GET /dev/inbox returns 404 when dev tools are disabled', async () => {
    const res = await request(app.getHttpServer()).get('/api/dev/inbox');
    expect(res.status).toBe(404);
  });
});
