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
      // a fresh tenant has no saved settings yet, but getSettings pre-fills
      // from the typed columns set at registration (companyName/legalName/taxId).
      expect(settings.company.companyName).toBeTruthy(); // tenantName → companyName
      expect(settings.company.legalName).toBe('Razão Social Teste');
      expect(settings.company.taxId).toBeTruthy(); // cnpj set at registration
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
      // B sees its own registration data (not A's data)
      expect(bSettings.company.companyName).not.toBe('Empresa A');
    });
  });

  // ---- Criterion 8: fiscal fields + /me sync ---------------------------
  describe('Criterion 8 — fiscal fields and /me sync', () => {
    it('PATCH /settings/company with fiscal fields persists and syncs legalName to /me', async () => {
      const owner = await registerOwner();

      const patch = await request(app.getHttpServer())
        .patch('/api/settings/company')
        .set('Authorization', `Bearer ${owner.access}`)
        .send({
          legalName: 'Razão Social Fiscal Ltda',
          companyName: 'Nome Fantasia Fiscal',
          regimeTributario: 'simples',
          uf: 'SP',
          themePreset: 'azul',
        });
      expect(patch.status).toBe(200);

      // GET /settings reflects the fiscal fields
      const settings = await getSettings(owner.access);
      expect(settings.company.legalName).toBe('Razão Social Fiscal Ltda');
      expect(settings.company.companyName).toBe('Nome Fantasia Fiscal');
      expect(settings.company.regimeTributario).toBe('simples');
      expect(settings.company.uf).toBe('SP');
      expect(settings.company.themePreset).toBe('azul');

      // GET /me reflects synced identity (legalName + tradeName)
      const me = await request(app.getHttpServer())
        .get('/api/me')
        .set('Authorization', `Bearer ${owner.access}`);
      expect(me.status).toBe(200);
      expect(me.body.activeTenant.legalName).toBe('Razão Social Fiscal Ltda');
      expect(me.body.activeTenant.tradeName).toBe('Nome Fantasia Fiscal');
    });

    it('PATCH /settings/company with invalid regimeTributario returns 400', async () => {
      const owner = await registerOwner();
      const res = await request(app.getHttpServer())
        .patch('/api/settings/company')
        .set('Authorization', `Bearer ${owner.access}`)
        .send({ regimeTributario: 'invalido' });
      expect(res.status).toBe(400);
    });

    it('PATCH /settings/company with invalid uf returns 400', async () => {
      const owner = await registerOwner();
      const res = await request(app.getHttpServer())
        .patch('/api/settings/company')
        .set('Authorization', `Bearer ${owner.access}`)
        .send({ uf: 'XX' });
      expect(res.status).toBe(400);
    });
  });

  // ---- Criterion 9: logo upload ----------------------------------------
  describe('Criterion 9 — logo upload', () => {
    // Minimal valid 1×1 PNG (67 bytes)
    const TINY_PNG = Buffer.from([
      0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, // PNG signature
      0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52, // IHDR length + type
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1×1
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, // bit depth, color, crc
      0xde, 0x00, 0x00, 0x00, 0x0c, 0x49, 0x44, 0x41, // IDAT length + type
      0x54, 0x08, 0xd7, 0x63, 0xf8, 0xcf, 0xc0, 0x00, // IDAT data
      0x00, 0x00, 0x02, 0x00, 0x01, 0xe2, 0x21, 0xbc, // IDAT data + crc
      0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, // IEND length + type
      0x44, 0xae, 0x42, 0x60, 0x82,                    // IEND data + crc
    ]);

    it('POST /settings/company/logo with valid PNG sets logoUrl', async () => {
      const owner = await registerOwner();

      const res = await request(app.getHttpServer())
        .post('/api/settings/company/logo')
        .set('Authorization', `Bearer ${owner.access}`)
        .attach('file', TINY_PNG, { filename: 'logo.png', contentType: 'image/png' });
      if (res.status !== 200) {
        // eslint-disable-next-line no-console
        console.error('POST logo unexpected status', res.status, res.body);
      }
      expect(res.status).toBe(200);
      expect(res.body.company.logoUrl).toBeTruthy();
      expect(typeof res.body.company.logoUrl).toBe('string');
      // Local storage URL contains /files/
      expect(res.body.company.logoUrl).toMatch(/files/);

      // GET /settings also reflects the new logoUrl
      const settings = await getSettings(owner.access);
      expect(settings.company.logoUrl).toBe(res.body.company.logoUrl);
    });

    it('POST /settings/company/logo with text/plain returns 400', async () => {
      const owner = await registerOwner();

      const res = await request(app.getHttpServer())
        .post('/api/settings/company/logo')
        .set('Authorization', `Bearer ${owner.access}`)
        .attach('file', Buffer.from('not an image'), {
          filename: 'logo.txt',
          contentType: 'text/plain',
        });
      expect(res.status).toBe(400);
      expect(JSON.stringify(res.body)).toMatch(/imagem/i);
    });

    it('POST /settings/company/logo without settings.manage (mechanic) returns 403', async () => {
      const owner = await registerOwner();
      const mech = await inviteAccept(owner, 'mechanic');

      const res = await request(app.getHttpServer())
        .post('/api/settings/company/logo')
        .set('Authorization', `Bearer ${mech.access}`)
        .attach('file', TINY_PNG, { filename: 'logo.png', contentType: 'image/png' });
      expect(res.status).toBe(403);
    });
  });

  // ---- Criterion 10: tenant isolation for fiscal fields -----------------
  // ---- Criterion 11: PATCH /settings/appearance (sem settings.manage) ---
  describe('Criterion 11 — PATCH appearance (qualquer membro autenticado)', () => {
    it('mechanic sem settings.manage pode PATCH /settings/appearance (200)', async () => {
      const owner = await registerOwner();
      const mech = await inviteAccept(owner, 'mechanic');

      const res = await request(app.getHttpServer())
        .patch('/api/settings/appearance')
        .set('Authorization', `Bearer ${mech.access}`)
        .send({ themePreset: 'azul' });
      if (res.status !== 200) {
        // eslint-disable-next-line no-console
        console.error('PATCH appearance unexpected status', res.status, res.body);
      }
      expect(res.status).toBe(200);
      expect(res.body.company.themePreset).toBe('azul');
    });

    it('mechanic NÃO pode PATCH /settings/company (403)', async () => {
      const owner = await registerOwner();
      const mech = await inviteAccept(owner, 'mechanic');

      const res = await request(app.getHttpServer())
        .patch('/api/settings/company')
        .set('Authorization', `Bearer ${mech.access}`)
        .send({ companyName: 'Invadido' });
      expect(res.status).toBe(403);
    });

    it('PATCH /settings/appearance rejeita campos de empresa (400 forbidNonWhitelisted)', async () => {
      const owner = await registerOwner();

      const res = await request(app.getHttpServer())
        .patch('/api/settings/appearance')
        .set('Authorization', `Bearer ${owner.access}`)
        .send({ themePreset: 'azul', companyName: 'Tentativa de invasao' });
      expect(res.status).toBe(400);
    });

    it('PATCH /settings/appearance rejeita themePreset inválido (400)', async () => {
      const owner = await registerOwner();

      const res = await request(app.getHttpServer())
        .patch('/api/settings/appearance')
        .set('Authorization', `Bearer ${owner.access}`)
        .send({ themePreset: 'arcoiris' });
      expect(res.status).toBe(400);
    });

    it('owner pode PATCH /settings/appearance e round-trip via GET /settings', async () => {
      const owner = await registerOwner();

      const patch = await request(app.getHttpServer())
        .patch('/api/settings/appearance')
        .set('Authorization', `Bearer ${owner.access}`)
        .send({ themePreset: 'roxo', primaryColor: '#6B21A8' });
      expect(patch.status).toBe(200);
      expect(patch.body.company.themePreset).toBe('roxo');

      const settings = await getSettings(owner.access);
      expect(settings.company.themePreset).toBe('roxo');
      expect(settings.company.primaryColor).toBe('#6B21A8');
    });
  });

  describe('Criterion 10 — tenant isolation for fiscal fields', () => {
    it('fiscal fields set by tenant A are not visible to tenant B', async () => {
      const ownerA = await registerOwner();
      const ownerB = await registerOwner();

      // Tenant A sets fiscal data
      const patch = await request(app.getHttpServer())
        .patch('/api/settings/company')
        .set('Authorization', `Bearer ${ownerA.access}`)
        .send({
          companyName: 'Empresa Alpha',
          legalName: 'Alpha Razão Social LTDA',
          regimeTributario: 'presumido',
          uf: 'RJ',
        });
      expect(patch.status).toBe(200);

      // Tenant B sees none of A's fiscal data
      const bSettings = await getSettings(ownerB.access);
      expect(bSettings.company.companyName).not.toBe('Empresa Alpha');
      // legalName comes from B's own registration ('Razão Social Teste'), not from A
      expect(bSettings.company.legalName).not.toBe('Alpha Razão Social LTDA');
      expect(bSettings.company.regimeTributario).toBeUndefined();
      expect(bSettings.company.uf).toBeUndefined();
    });
  });
});
