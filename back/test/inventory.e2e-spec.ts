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

describe('Inventory — Produtos (e2e)', () => {
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

  function createItem(access: string, body: Record<string, unknown>) {
    return request(app.getHttpServer())
      .post('/api/inventory/items')
      .set(auth(access))
      .send(body);
  }
  function listItems(access: string, query = '') {
    return request(app.getHttpServer())
      .get(`/api/inventory/items${query}`)
      .set(auth(access));
  }
  function getItem(access: string, id: string) {
    return request(app.getHttpServer())
      .get(`/api/inventory/items/${id}`)
      .set(auth(access));
  }
  function patchItem(access: string, id: string, body: Record<string, unknown>) {
    return request(app.getHttpServer())
      .patch(`/api/inventory/items/${id}`)
      .set(auth(access))
      .send(body);
  }
  function archive(access: string, id: string) {
    return request(app.getHttpServer())
      .post(`/api/inventory/items/${id}/archive`)
      .set(auth(access));
  }
  function unarchive(access: string, id: string) {
    return request(app.getHttpServer())
      .post(`/api/inventory/items/${id}/unarchive`)
      .set(auth(access));
  }
  function patchConfig(access: string, body: Record<string, unknown>) {
    return request(app.getHttpServer())
      .patch('/api/inventory/config')
      .set(auth(access))
      .send(body);
  }
  function getConfig(access: string) {
    return request(app.getHttpServer())
      .get('/api/inventory/config')
      .set(auth(access));
  }
  function lookup(access: string, code: string) {
    return request(app.getHttpServer())
      .get(`/api/inventory/lookup?code=${encodeURIComponent(code)}`)
      .set(auth(access));
  }
  function lowStock(access: string) {
    return request(app.getHttpServer())
      .get('/api/inventory/low-stock')
      .set(auth(access));
  }

  type IdRow = { id: string };
  const ids = (rows: IdRow[]) => rows.map((r) => r.id);

  // ---- 1. create + list (decimal prices) --------------------------------
  describe('create + list', () => {
    it('creates a product with decimal prices and lists it', async () => {
      const o = await registerOwner();
      const created = await createItem(o.access, {
        name: 'Pastilha de freio',
        sku: 'PF-001',
        barcode: '7891000100103',
        salePrice: 45.9,
        costPrice: 30,
        currentStock: 10,
        minStock: 3,
      });
      expect(created.status).toBe(201);
      expect(created.body.is_active).toBe(true);
      // decimal serializes as string -> compare numerically
      expect(Number(created.body.sale_price)).toBe(45.9);
      const id = created.body.id as string;

      const list = await listItems(o.access);
      expect(list.status).toBe(200);
      expect(ids(list.body.items as IdRow[])).toContain(id);
    });
  });

  // ---- 2. tenant isolation (RLS) ---------------------------------------
  describe('tenant isolation (RLS)', () => {
    it("tenant B never sees tenant A's item", async () => {
      const a = await registerOwner();
      const b = await registerOwner();

      const created = await createItem(a.access, { name: 'Item secreto de A' });
      expect(created.status).toBe(201);
      const id = created.body.id as string;

      const bList = await listItems(b.access);
      expect(bList.status).toBe(200);
      expect(ids(bList.body.items as IdRow[])).not.toContain(id);

      // direct fetch is invisible under B's RLS -> 404
      const bGet = await getItem(b.access, id);
      expect(bGet.status).toBe(404);
    });
  });

  // ---- 3. uniques per tenant -------------------------------------------
  describe('uniques per tenant', () => {
    it('rejects duplicate barcode in same tenant (409); another tenant can reuse it', async () => {
      const a = await registerOwner();
      const b = await registerOwner();
      const barcode = '7891000100103';

      const first = await createItem(a.access, { name: 'Primeiro', barcode });
      expect(first.status).toBe(201);

      // same barcode, same tenant -> conflict
      const dupBarcode = await createItem(a.access, { name: 'Duplicado', barcode });
      expect(dupBarcode.status).toBe(409);

      // same sku, same tenant -> conflict
      const sku = 'SKU-DUP-1';
      const firstSku = await createItem(a.access, { name: 'Com SKU', sku });
      expect(firstSku.status).toBe(201);
      const dupSku = await createItem(a.access, { name: 'SKU repetido', sku });
      expect(dupSku.status).toBe(409);

      // a DIFFERENT tenant can reuse the same barcode (no conflict)
      const otherTenant = await createItem(b.access, { name: 'De B', barcode });
      expect(otherTenant.status).toBe(201);
    });
  });

  // ---- 4. attributes whitelist -----------------------------------------
  describe('attributes whitelist', () => {
    it('accepts declared keys, rejects unknown key and wrong type', async () => {
      const o = await registerOwner();
      const cfg = await patchConfig(o.access, {
        itemFields: [
          {
            key: 'vehicleApplication',
            label: 'Aplicação',
            type: 'tags',
            required: false,
          },
        ],
      });
      expect(cfg.status).toBe(200);

      // declared key, correct type -> 201
      const ok = await createItem(o.access, {
        name: 'Com atributo válido',
        attributes: { vehicleApplication: ['Gol G5'] },
      });
      expect(ok.status).toBe(201);
      expect(ok.body.attributes).toEqual({ vehicleApplication: ['Gol G5'] });

      // unknown key -> 400
      const unknown = await createItem(o.access, {
        name: 'Atributo desconhecido',
        attributes: { foo: 'bar' },
      });
      expect(unknown.status).toBe(400);

      // wrong type (should be array of strings) -> 400
      const wrongType = await createItem(o.access, {
        name: 'Tipo errado',
        attributes: { vehicleApplication: 'nota-lista' },
      });
      expect(wrongType.status).toBe(400);
    });
  });

  // ---- 5. lookup cascade -----------------------------------------------
  describe('lookup cascade', () => {
    it('internal for known barcode; none for valid-GTIN-not-in-db and non-GTIN', async () => {
      const o = await registerOwner();
      const barcode = '7891000100103';
      const created = await createItem(o.access, {
        name: 'Pastilha de freio',
        barcode,
      });
      expect(created.status).toBe(201);

      // internal path: code matches an existing item's barcode
      const internal = await lookup(o.access, barcode);
      expect(internal.status).toBe(200);
      expect(internal.body.source).toBe('internal');
      expect(internal.body.item).toBeDefined();
      expect(internal.body.item.id).toBe(created.body.id);

      // valid GTIN (passes GS1 mod-10) but not in db; catalog disabled (Noop) -> none
      const validNotInDb = await lookup(o.access, '7896005800010');
      expect(validNotInDb.status).toBe(200);
      expect(validNotInDb.body.source).toBe('none');

      // non-GTIN, not in db -> none
      const nonGtin = await lookup(o.access, 'abc');
      expect(nonGtin.status).toBe(200);
      expect(nonGtin.body.source).toBe('none');
    });
  });

  // ---- 6. archive / unarchive ------------------------------------------
  describe('archive / unarchive', () => {
    it('archived item leaves the default list but is not deleted; unarchive restores', async () => {
      const o = await registerOwner();
      const created = await createItem(o.access, { name: 'Para arquivar' });
      const id = created.body.id as string;

      const arch = await archive(o.access, id);
      expect(arch.status).toBe(200);
      expect(arch.body.is_active).toBe(false);

      // gone from default (active-only) list
      const defaultList = await listItems(o.access);
      expect(ids(defaultList.body.items as IdRow[])).not.toContain(id);

      // present with active=all and active=false
      const allList = await listItems(o.access, '?active=all');
      expect(ids(allList.body.items as IdRow[])).toContain(id);
      const archivedList = await listItems(o.access, '?active=false');
      expect(ids(archivedList.body.items as IdRow[])).toContain(id);

      // row still exists (not hard-deleted)
      const stillThere = await getItem(o.access, id);
      expect(stillThere.status).toBe(200);
      expect(stillThere.body.is_active).toBe(false);

      // unarchive restores
      const un = await unarchive(o.access, id);
      expect(un.status).toBe(200);
      expect(un.body.is_active).toBe(true);
      const restored = await listItems(o.access);
      expect(ids(restored.body.items as IdRow[])).toContain(id);
    });
  });

  // ---- 7. low-stock -----------------------------------------------------
  describe('low-stock', () => {
    it('lists a product at/below min and excludes one above min', async () => {
      const o = await registerOwner();
      const low = await createItem(o.access, {
        name: 'Filtro de ar',
        minStock: 5,
        currentStock: 2,
      });
      expect(low.status).toBe(201);
      const lowId = low.body.id as string;

      const ok = await createItem(o.access, {
        name: 'Bem abastecido',
        minStock: 5,
        currentStock: 50,
      });
      expect(ok.status).toBe(201);
      const okId = ok.body.id as string;

      const res = await lowStock(o.access);
      expect(res.status).toBe(200);
      const lowIds = ids(res.body as IdRow[]);
      expect(lowIds).toContain(lowId);
      expect(lowIds).not.toContain(okId);
    });
  });

  // ---- 8. authorization by role ----------------------------------------
  describe('authorization', () => {
    it('mechanic reads items (200) but cannot create (403) nor patch config (403)', async () => {
      const o = await registerOwner();
      const mech = await inviteAccept(o, 'mechanic');

      // inventory.read -> list allowed
      const list = await listItems(mech.access);
      expect(list.status).toBe(200);

      // no inventory.write -> create denied
      const create = await createItem(mech.access, { name: 'Por mecânico' });
      expect(create.status).toBe(403);

      // no settings.manage -> config patch denied
      const cfg = await patchConfig(mech.access, { itemFields: [] });
      expect(cfg.status).toBe(403);

      // read config is allowed (inventory.read)
      const readCfg = await getConfig(mech.access);
      expect(readCfg.status).toBe(200);
      expect(readCfg.body.itemFields).toEqual([]);
    });
  });
});
