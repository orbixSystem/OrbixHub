import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import Redis from 'ioredis';
import { AppModule } from '../src/app.module';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';
import { REDIS } from '../src/common/redis/redis.module';
import { randomCnpj } from './helpers/cnpj';
import { NuvemFiscalClient } from '../src/modules/invoice/fiscal/nuvemfiscal-client';
import {
  MailerService,
  VerificationEmail,
} from '../src/common/mailer/mailer.service';

/** Fake do cliente Nuvem Fiscal — passthrough sem rede real (mesmo padrão de
 * override de provider dos demais e2e, ex.: inventory/customers). */
const fakeNuvemFiscalClient = {
  upsertEmpresa: async () => undefined,
  uploadCertificate: async () => ({ notValidAfter: '2027-01-01T00:00:00Z' }),
};

// e2e é determinístico: catálogo externo desligado (mesmo padrão do inventory e2e).
process.env.CATALOG_ENABLED = 'false';
process.env.CATALOG_PROVIDER = 'noop';

class CapturingMailer extends MailerService {
  public readonly sent: VerificationEmail[] = [];
  async send(email: VerificationEmail): Promise<void> {
    this.sent.push(email);
  }
  lastTokenFor(kind: VerificationEmail['kind'], to: string): string | undefined {
    return [...this.sent].reverse().find((e) => e.kind === kind && e.to === to)
      ?.token;
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
}

describe('Invoice — Config fiscal (e2e)', () => {
  let app: INestApplication;
  let redis: Redis;
  let mailer: CapturingMailer;

  const OWNER_PW = 'supersecret1';
  const uniq = () => Math.random().toString(36).slice(2, 8);

  beforeAll(async () => {
    mailer = new CapturingMailer();
    const mod = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(MailerService)
      .useValue(mailer)
      .overrideProvider(NuvemFiscalClient)
      .useValue(fakeNuvemFiscalClient)
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
  });

  beforeEach(async () => {
    await redis.flushall();
  });

  afterAll(async () => app?.close());

  // ---- helpers ----------------------------------------------------------
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
    return { access: accept.body.accessToken as string };
  }

  const auth = (access: string) => ({ Authorization: `Bearer ${access}` });

  function getConfig(access: string) {
    return request(app.getHttpServer())
      .get('/api/invoices/config')
      .set(auth(access));
  }
  function patchConfig(access: string, body: Record<string, unknown>) {
    return request(app.getHttpServer())
      .patch('/api/invoices/config')
      .set(auth(access))
      .send(body);
  }

  // ---- 1. defaults + persist ---------------------------------------------
  describe('GET/PATCH /invoices/config', () => {
    it('GET /invoices/config retorna defaults e PATCH persiste', async () => {
      const o = await registerOwner();

      const get1 = await getConfig(o.access);
      expect(get1.status).toBe(200);
      expect(get1.body.ambiente).toBe('homologacao');
      expect(get1.body.serieNfse).toBe('1');

      const patch = await patchConfig(o.access, {
        serieNfse: '7',
        ambiente: 'producao',
      });
      expect(patch.status).toBe(200);
      expect(patch.body.serieNfse).toBe('7');
      expect(patch.body.ambiente).toBe('producao');

      const get2 = await getConfig(o.access);
      expect(get2.status).toBe(200);
      expect(get2.body.serieNfse).toBe('7');
      expect(get2.body.ambiente).toBe('producao');
    });
  });

  // ---- 2. authorization by role -------------------------------------------
  describe('authorization', () => {
    it('mechanic não pode ler nem alterar a config (403)', async () => {
      const o = await registerOwner();
      const mech = await inviteAccept(o, 'mechanic');

      const get = await getConfig(mech.access);
      expect(get.status).toBe(403);

      const patch = await patchConfig(mech.access, { serieNfse: '9' });
      expect(patch.status).toBe(403);
    });
  });

  // ---- 3. tenant isolation -------------------------------------------------
  describe('tenant isolation', () => {
    it("mudança de config em A não afeta o tenant B", async () => {
      const a = await registerOwner();
      const b = await registerOwner();

      const patch = await patchConfig(a.access, { serieNfse: '5' });
      expect(patch.status).toBe(200);

      const getB = await getConfig(b.access);
      expect(getB.status).toBe(200);
      expect(getB.body.serieNfse).toBe('1');
    });
  });

  // ---- 4. cadastro de empresa (passthrough Nuvem Fiscal) --------------------
  describe('POST /invoices/config/register-empresa', () => {
    it('cadastra a empresa no provedor (mockado) e marca empresaRegistrada=true', async () => {
      const o = await registerOwner();

      const before = await getConfig(o.access);
      expect(before.status).toBe(200);
      expect(before.body.empresaRegistrada).toBe(false);

      const register = await request(app.getHttpServer())
        .post('/api/invoices/config/register-empresa')
        .set(auth(o.access))
        .send({});
      expect(register.status).toBe(200);
      expect(register.body.empresaRegistrada).toBe(true);

      const after = await getConfig(o.access);
      expect(after.status).toBe(200);
      expect(after.body.empresaRegistrada).toBe(true);
    });

    it('mechanic não pode cadastrar a empresa (403)', async () => {
      const o = await registerOwner();
      const mech = await inviteAccept(o, 'mechanic');

      const register = await request(app.getHttpServer())
        .post('/api/invoices/config/register-empresa')
        .set(auth(mech.access))
        .send({});
      expect(register.status).toBe(403);
    });
  });

  // ---- 5. upload de certificado (passthrough Nuvem Fiscal) ------------------
  describe('POST /invoices/config/certificate', () => {
    it('faz upload do .pfx e grava certificado.validoAte (metadado, sem persistir o arquivo)', async () => {
      const o = await registerOwner();

      const upload = await request(app.getHttpServer())
        .post('/api/invoices/config/certificate')
        .set(auth(o.access))
        .field('password', 'senha-do-certificado')
        .attach('file', Buffer.from('conteudo-fake-do-pfx'), 'certificado.pfx');
      expect(upload.status).toBe(200);
      expect(upload.body.certificado.validoAte).toBe('2027-01-01T00:00:00Z');

      const after = await getConfig(o.access);
      expect(after.status).toBe(200);
      expect(after.body.certificado.validoAte).toBe('2027-01-01T00:00:00Z');
    });

    it('rejeita arquivo com extensão inválida (400)', async () => {
      const o = await registerOwner();

      const upload = await request(app.getHttpServer())
        .post('/api/invoices/config/certificate')
        .set(auth(o.access))
        .field('password', 'senha-do-certificado')
        .attach('file', Buffer.from('nao-e-um-certificado'), 'certificado.txt');
      expect(upload.status).toBe(400);
    });
  });
});
