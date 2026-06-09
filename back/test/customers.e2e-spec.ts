import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import Redis from 'ioredis';
import { AppModule } from '../src/app.module';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';
import { REDIS } from '../src/common/redis/redis.module';
import {
  MailerService,
  VerificationEmail,
} from '../src/common/mailer/mailer.service';
import { TenantContext } from '../src/common/database/tenant-context';
import type { TxClient } from '../src/common/database/tenant-context';
import { FIPE_CLIENT } from '../src/modules/customers/fipe.client';
import type { FipeClient } from '../src/modules/customers/fipe.client';

class CountingFipe implements FipeClient {
  public brandCalls = 0;
  async brands() {
    this.brandCalls++;
    return [
      { code: '22', name: 'Ford' },
      { code: '23', name: 'Fiat' },
    ];
  }
  async models(_brandCode: string) {
    return [
      { code: '1', name: 'Ka' },
      { code: '2', name: 'Fiesta' },
    ];
  }
}

/** Captures emails so we can read the raw invite token (drives /invites/accept). */
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

describe('Customers & Subjects (e2e)', () => {
  let app: INestApplication;
  let redis: Redis;
  let mailer: CapturingMailer;
  let tenantCtx: TenantContext;
  let fipeRef: CountingFipe;

  const OWNER_PW = 'supersecret1';
  const uniq = () => Math.random().toString(36).slice(2, 8);

  beforeAll(async () => {
    mailer = new CapturingMailer();
    const fipe = new CountingFipe();
    fipeRef = fipe;
    const mod = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(MailerService)
      .useValue(mailer)
      .overrideProvider(FIPE_CLIENT)
      .useValue(fipe)
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

  // ---- helpers ----------------------------------------------------------
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

  function createCustomer(access: string, body: Record<string, unknown>) {
    return request(app.getHttpServer())
      .post('/api/customers')
      .set(auth(access))
      .send(body);
  }
  function listCustomers(access: string, query = '') {
    return request(app.getHttpServer())
      .get(`/api/customers${query}`)
      .set(auth(access));
  }

  // ---- Criterion 1: tenant isolation -----------------------------------
  describe('tenant isolation (RLS)', () => {
    it("tenant B never sees tenant A's customer", async () => {
      const a = await registerOwner();
      const b = await registerOwner();

      const created = await createCustomer(a.access, { name: 'Cliente A' });
      expect(created.status).toBe(201);
      const id = created.body.id as string;

      const bList = await listCustomers(b.access);
      expect(bList.status).toBe(200);
      expect((bList.body.items as Array<{ id: string }>).map((c) => c.id)).not.toContain(id);

      const bGet = await request(app.getHttpServer())
        .get(`/api/customers/${id}`)
        .set(auth(b.access));
      expect(bGet.status).toBe(404);
    });
  });

  // ---- Criterion 1: CRUD + archive (no hard delete) --------------------
  describe('customer CRUD + archive', () => {
    it('create -> get -> update -> archive -> unarchive (status, never deleted)', async () => {
      const o = await registerOwner();
      const created = await createCustomer(o.access, {
        name: 'João',
        phone: '11999',
      });
      expect(created.status).toBe(201);
      const id = created.body.id as string;
      expect(created.body.status).toBe('active');

      const patch = await request(app.getHttpServer())
        .patch(`/api/customers/${id}`)
        .set(auth(o.access))
        .send({ name: 'João Silva' });
      expect(patch.status).toBe(200);
      expect(patch.body.name).toBe('João Silva');

      const archive = await request(app.getHttpServer())
        .post(`/api/customers/${id}/archive`)
        .set(auth(o.access));
      expect(archive.status).toBe(200);
      expect(archive.body.status).toBe('archived');

      // default list (active) excludes archived
      const activeList = await listCustomers(o.access);
      expect((activeList.body.items as Array<{ id: string }>).map((c) => c.id)).not.toContain(id);
      // status=archived includes it (row still exists -> no hard delete)
      const archivedList = await listCustomers(o.access, '?status=archived');
      expect((archivedList.body.items as Array<{ id: string }>).map((c) => c.id)).toContain(id);

      const unarchive = await request(app.getHttpServer())
        .post(`/api/customers/${id}/unarchive`)
        .set(auth(o.access));
      expect(unarchive.status).toBe(200);
      expect(unarchive.body.status).toBe('active');
    });
  });

  // ---- soft delete -----------------------------------------------------
  describe('soft delete', () => {
    it('DELETE removes from lists (incl. all) but keeps the row', async () => {
      const o = await registerOwner();
      const created = await createCustomer(o.access, { name: 'Para excluir' });
      const id = created.body.id as string;

      const del = await request(app.getHttpServer())
        .delete(`/api/customers/${id}`)
        .set(auth(o.access));
      expect(del.status).toBe(200);
      expect(del.body.status).toBe('deleted');

      // gone from active AND from "all"
      const active = await listCustomers(o.access);
      expect((active.body.items as Array<{ id: string }>).map((c) => c.id)).not.toContain(id);
      const all = await listCustomers(o.access, '?status=all');
      expect((all.body.items as Array<{ id: string }>).map((c) => c.id)).not.toContain(id);

      // row still exists (no hard delete) — fetchable by id with status 'deleted'
      const byId = await request(app.getHttpServer())
        .get(`/api/customers/${id}`)
        .set(auth(o.access));
      expect(byId.status).toBe(200);
      expect(byId.body.status).toBe('deleted');
    });
  });

  // ---- Criterion 2: search ---------------------------------------------
  describe('search', () => {
    it('finds customers by name, document and phone', async () => {
      const o = await registerOwner();
      await createCustomer(o.access, {
        name: 'Maria Fernanda',
        document: '12345678900',
        phone: '11888777',
      });
      await createCustomer(o.access, { name: 'Outro Cliente' });

      const byName = await listCustomers(o.access, '?q=Fernanda');
      expect((byName.body.items as unknown[]).length).toBe(1);
      const byDoc = await listCustomers(o.access, '?q=123456789');
      expect((byDoc.body.items as unknown[]).length).toBe(1);
      const byPhone = await listCustomers(o.access, '?q=888777');
      expect((byPhone.body.items as unknown[]).length).toBe(1);
    });
  });

  // ---- Criterion 3: document optional + unique per tenant --------------
  describe('document uniqueness', () => {
    it('document is optional; unique per tenant when present', async () => {
      const o = await registerOwner();
      // two customers without document are allowed (partial unique index)
      expect((await createCustomer(o.access, { name: 'A' })).status).toBe(201);
      expect((await createCustomer(o.access, { name: 'B' })).status).toBe(201);
      // first with document ok
      expect(
        (await createCustomer(o.access, { name: 'C', document: 'DOC-1' })).status,
      ).toBe(201);
      // duplicate document -> 409
      const dup = await createCustomer(o.access, { name: 'D', document: 'DOC-1' });
      expect(dup.status).toBe(409);
    });

    it('same document is allowed across different tenants', async () => {
      const a = await registerOwner();
      const b = await registerOwner();
      expect(
        (await createCustomer(a.access, { name: 'A', document: 'SHARED' })).status,
      ).toBe(201);
      expect(
        (await createCustomer(b.access, { name: 'B', document: 'SHARED' })).status,
      ).toBe(201);
    });
  });

  // ---- Criterion 3: documentRequired config ----------------------------
  describe('documentRequired config', () => {
    it('when enabled, customer creation requires a document', async () => {
      const o = await registerOwner();
      const patch = await request(app.getHttpServer())
        .patch('/api/customers/config')
        .set(auth(o.access))
        .send({ documentRequired: true });
      expect(patch.status).toBe(200);
      expect(patch.body.documentRequired).toBe(true);

      const without = await createCustomer(o.access, { name: 'Sem doc' });
      expect(without.status).toBe(400);
      const withDoc = await createCustomer(o.access, {
        name: 'Com doc',
        document: 'D-1',
      });
      expect(withDoc.status).toBe(201);
    });
  });

  // ---- Criterion 1/2/5: subjects ---------------------------------------
  describe('subjects', () => {
    async function makeCustomer(access: string): Promise<string> {
      const c = await createCustomer(access, { name: 'Dono do objeto' });
      return c.body.id as string;
    }

    it('create under customer (required identifier), list by identifier, history empty', async () => {
      const o = await registerOwner();
      const customerId = await makeCustomer(o.access);

      // default config requires `identifier` (placa) -> missing => 400
      const missing = await request(app.getHttpServer())
        .post(`/api/customers/${customerId}/subjects`)
        .set(auth(o.access))
        .send({ label: 'sem placa' });
      expect(missing.status).toBe(400);

      const created = await request(app.getHttpServer())
        .post(`/api/customers/${customerId}/subjects`)
        .set(auth(o.access))
        .send({
          label: 'Gol do João',
          identifier: 'ABC1D23',
          attributes: { marca: 'VW', modelo: 'Gol' },
        });
      expect(created.status).toBe(201);
      const subjectId = created.body.id as string;

      const byId = await request(app.getHttpServer())
        .get('/api/subjects?q=ABC1D23')
        .set(auth(o.access));
      expect((byId.body.items as Array<{ id: string }>).map((s) => s.id)).toContain(subjectId);

      const hist = await request(app.getHttpServer())
        .get(`/api/subjects/${subjectId}/history`)
        .set(auth(o.access));
      expect(hist.status).toBe(200);
      expect(hist.body).toEqual([]);

      // archive (no hard delete)
      const arch = await request(app.getHttpServer())
        .post(`/api/subjects/${subjectId}/archive`)
        .set(auth(o.access));
      expect(arch.status).toBe(200);
      expect(arch.body.status).toBe('archived');
    });

    it('DELETE subject is a soft delete (gone from list, archive still possible elsewhere)', async () => {
      const o = await registerOwner();
      const customerId = await makeCustomer(o.access);
      const created = await request(app.getHttpServer())
        .post(`/api/customers/${customerId}/subjects`)
        .set(auth(o.access))
        .send({ identifier: 'DEL1234' });
      const subjectId = created.body.id as string;

      const del = await request(app.getHttpServer())
        .delete(`/api/subjects/${subjectId}`)
        .set(auth(o.access));
      expect(del.status).toBe(200);
      expect(del.body.status).toBe('deleted');

      // gone from active and from "all"
      const all = await request(app.getHttpServer())
        .get('/api/subjects?status=all')
        .set(auth(o.access));
      expect((all.body.items as Array<{ id: string }>).map((s) => s.id)).not.toContain(subjectId);

      // row still exists (no hard delete)
      const byId = await request(app.getHttpServer())
        .get(`/api/subjects/${subjectId}`)
        .set(auth(o.access));
      expect(byId.status).toBe(200);
      expect(byId.body.status).toBe('deleted');
    });

    it('creating a subject for an invalid customer fails (400)', async () => {
      const o = await registerOwner();
      const bad = await request(app.getHttpServer())
        .post('/api/customers/00000000-0000-0000-0000-000000000000/subjects')
        .set(auth(o.access))
        .send({ identifier: 'XYZ' });
      expect(bad.status).toBe(400);
    });
  });

  // ---- Criterion 6: usaSubjects=false disables subject endpoints --------
  describe('usaSubjects=false', () => {
    it('disables subject endpoints (403)', async () => {
      const o = await registerOwner();
      const c = await createCustomer(o.access, { name: 'C' });
      const customerId = c.body.id as string;

      await request(app.getHttpServer())
        .patch('/api/customers/config')
        .set(auth(o.access))
        .send({ usaSubjects: false })
        .expect(200);

      const list = await request(app.getHttpServer())
        .get('/api/subjects')
        .set(auth(o.access));
      expect(list.status).toBe(403);

      const create = await request(app.getHttpServer())
        .post(`/api/customers/${customerId}/subjects`)
        .set(auth(o.access))
        .send({ identifier: 'ABC' });
      expect(create.status).toBe(403);
    });
  });

  // ---- authorization by role -------------------------------------------
  describe('authorization', () => {
    it('mechanic can write customers (customer.write) but not edit config (settings.manage)', async () => {
      const o = await registerOwner();
      const mech = await inviteAccept(o, 'mechanic');

      const create = await createCustomer(mech.access, { name: 'By mechanic' });
      expect(create.status).toBe(201);

      const cfg = await request(app.getHttpServer())
        .patch('/api/customers/config')
        .set(auth(mech.access))
        .send({ documentRequired: true });
      expect(cfg.status).toBe(403);
    });
  });

  // ---- module gating ---------------------------------------------------
  describe('module gating', () => {
    it('blocks customers endpoints when the module is disabled for the tenant (403)', async () => {
      const o = await registerOwner();
      // disable the `customers` module for this tenant (write under its RLS ctx)
      await tenantCtx.runWithTenant(o.tenantId, async () => {
        const db = tenantCtx.getClient() as TxClient;
        await db.$executeRaw`UPDATE tenant_module SET enabled=false WHERE module_id=(SELECT id FROM module WHERE key='customers')`;
      });

      const res = await listCustomers(o.access);
      expect(res.status).toBe(403);
    });
  });

  // ---- config defaults -------------------------------------------------
  describe('config defaults', () => {
    it('GET /customers/config returns generic defaults (Veículo label)', async () => {
      const o = await registerOwner();
      const res = await request(app.getHttpServer())
        .get('/api/customers/config')
        .set(auth(o.access));
      expect(res.status).toBe(200);
      expect(res.body.usaSubjects).toBe(true);
      expect(res.body.subjectLabel.singular).toBe('Veículo');
      expect(Array.isArray(res.body.subjectFields)).toBe(true);
    });
  });

  describe('GET /customers/lookups/:fonte', () => {
    it('401 sem token', async () => {
      await request(app.getHttpServer())
        .get('/api/customers/lookups/fipe.marcas')
        .expect(401);
    });

    it('marcas: retorna opções com código no meta e cacheia', async () => {
      const owner = await registerOwner();
      const before = fipeRef.brandCalls;

      const r1 = await request(app.getHttpServer())
        .get('/api/customers/lookups/fipe.marcas')
        .set(auth(owner.access))
        .expect(200);
      expect(r1.body).toContainEqual({
        value: 'Ford',
        label: 'Ford',
        meta: { codigo: '22' },
      });

      // segunda chamada vem do cache: sem novo hit na FIPE
      await request(app.getHttpServer())
        .get('/api/customers/lookups/fipe.marcas?q=fia')
        .set(auth(owner.access))
        .expect(200);
      expect(fipeRef.brandCalls).toBe(before + 1);
    });

    it('fonte desconhecida → 404', async () => {
      const owner = await registerOwner();
      await request(app.getHttpServer())
        .get('/api/customers/lookups/fipe.cor')
        .set(auth(owner.access))
        .expect(404);
    });

    it('modelos: sem marca → []; com marca → modelos', async () => {
      const owner = await registerOwner();

      const semMarca = await request(app.getHttpServer())
        .get('/api/customers/lookups/fipe.modelos')
        .set(auth(owner.access))
        .expect(200);
      expect(semMarca.body).toEqual([]);

      const comMarca = await request(app.getHttpServer())
        .get('/api/customers/lookups/fipe.modelos?marca=22')
        .set(auth(owner.access))
        .expect(200);
      expect(comMarca.body.map((o: { value: string }) => o.value)).toContain(
        'Ka',
      );
    });
  });
});
