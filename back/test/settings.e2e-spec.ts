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
import type { TxClient } from '../src/common/database/tenant-context';
import { SettingsSectionRegistry } from '../src/modules/settings/settings.section-registry';

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
  email: string;
  password: string;
}

interface SettingsSectionView {
  key: string;
  title: string;
  moduleKey: string | null;
  fields: unknown[];
}

interface SettingsView {
  company: Record<string, unknown>;
  sections: SettingsSectionView[];
}

describe('Settings host (e2e)', () => {
  let app: INestApplication;
  let redis: Redis;
  let mailer: CapturingMailer;
  let tenantCtx: TenantContext;
  let registry: SettingsSectionRegistry;

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
    tenantCtx = app.get(TenantContext);
    registry = app.get(SettingsSectionRegistry);
  });

  beforeEach(async () => {
    await redis.flushall();
  });

  afterAll(async () => app?.close());

  const uniq = () => Math.random().toString(36).slice(2, 8);

  /** Register a brand-new owner + tenant (trial -> os + customers enabled). */
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
    if (reg.status !== 201) {
      // eslint-disable-next-line no-console
      console.error('registerOwner unexpected status', reg.status, reg.body);
    }
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
    return { access: accept.body.accessToken as string, email, password };
  }

  async function getSettings(access: string): Promise<SettingsView> {
    const res = await request(app.getHttpServer())
      .get('/api/settings')
      .set('Authorization', `Bearer ${access}`);
    if (res.status !== 200) {
      // eslint-disable-next-line no-console
      console.error('GET /settings unexpected status', res.status, res.body);
    }
    expect(res.status).toBe(200);
    return res.body as SettingsView;
  }

  const sectionKeys = (s: SettingsView) => s.sections.map((sec) => sec.key);

  // ---- Criterion 4: core company section + enabled-module sections ------
  describe('Criterion 4 — core company section is always present', () => {
    it('GET /settings includes the core company section (moduleKey null) + empty company', async () => {
      const owner = await registerOwner();
      const settings = await getSettings(owner.access);

      const company = settings.sections.find((s) => s.key === 'company');
      expect(company).toBeDefined();
      expect(company?.moduleKey).toBeNull();
      // trial enables `customers` -> its registered config section shows up too.
      expect(sectionKeys(settings)).toContain('clientes_veiculos');
      expect(typeof settings.company).toBe('object');
      expect(settings.company).not.toBeNull();
      // a fresh tenant has no company settings yet -> defaults to {}
      expect(settings.company).toEqual({});
    });
  });

  // ---- Criterion 5: PATCH /settings/company ----------------------------
  describe('Criterion 5 — PATCH company', () => {
    it('owner updates company; persists and round-trips via GET', async () => {
      const owner = await registerOwner();

      const patch = await request(app.getHttpServer())
        .patch('/api/settings/company')
        .set('Authorization', `Bearer ${owner.access}`)
        .send({ companyName: 'Auto Center X', primaryColor: '#1E5BFF' });
      if (patch.status !== 200) {
        // eslint-disable-next-line no-console
        console.error('PATCH company unexpected status', patch.status, patch.body);
      }
      expect(patch.status).toBe(200);
      expect(patch.body.company.companyName).toBe('Auto Center X');

      const settings = await getSettings(owner.access);
      expect(settings.company.companyName).toBe('Auto Center X');
      expect(settings.company.primaryColor).toBe('#1E5BFF');
    });

    it('rejects an invalid color with 400', async () => {
      const owner = await registerOwner();
      const res = await request(app.getHttpServer())
        .patch('/api/settings/company')
        .set('Authorization', `Bearer ${owner.access}`)
        .send({ primaryColor: 'notacolor' });
      expect(res.status).toBe(400);
    });

    it('mechanic without settings.manage cannot PATCH company (403)', async () => {
      const owner = await registerOwner();
      const mech = await inviteAccept(owner, 'mechanic');

      const res = await request(app.getHttpServer())
        .patch('/api/settings/company')
        .set('Authorization', `Bearer ${mech.access}`)
        .send({ companyName: 'x' });
      expect(res.status).toBe(403);
    });
  });

  // ---- Criterion 6: incremental registry -------------------------------
  describe('Criterion 6 — incremental section registry', () => {
    it('a registered section appears/disappears with tenant_module.enabled', async () => {
      registry.register({
        key: 'os-cfg',
        title: 'Config OS',
        moduleKey: 'os',
        fields: [],
      });

      const owner = await registerOwner(); // trial -> os enabled

      // os enabled -> os-cfg section is present (alongside company)
      const withOs = await getSettings(owner.access);
      const keysWithOs = sectionKeys(withOs);
      expect(keysWithOs).toContain('company');
      expect(keysWithOs).toContain('os-cfg');

      // disable os for this tenant (write under its RLS context)
      await tenantCtx.runWithTenant(owner.tenantId, async () => {
        const db = tenantCtx.getClient() as TxClient;
        await db.$executeRaw`UPDATE tenant_module SET enabled=false WHERE module_id=(SELECT id FROM module WHERE key='os')`;
      });

      // os disabled -> os-cfg section disappears, company still present
      const withoutOs = await getSettings(owner.access);
      const keysWithoutOs = sectionKeys(withoutOs);
      expect(keysWithoutOs).toContain('company');
      expect(keysWithoutOs).not.toContain('os-cfg');
    });
  });

  // ---- Criterion 7: tenant isolation -----------------------------------
  describe('Criterion 7 — tenant isolation', () => {
    it("tenant B does not see tenant A's company settings", async () => {
      const ownerA = await registerOwner();
      const ownerB = await registerOwner();

      const patch = await request(app.getHttpServer())
        .patch('/api/settings/company')
        .set('Authorization', `Bearer ${ownerA.access}`)
        .send({ companyName: 'Empresa A' });
      expect(patch.status).toBe(200);

      const bSettings = await getSettings(ownerB.access);
      expect(bSettings.company.companyName).not.toBe('Empresa A');
      // B sees its own defaults
      expect(bSettings.company.companyName).toBeUndefined();
    });
  });
});
