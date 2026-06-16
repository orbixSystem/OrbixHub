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

describe('Inventory — Estoque & Serviços (e2e)', () => {
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
  function move(access: string, id: string, body: Record<string, unknown>) {
    return request(app.getHttpServer())
      .post(`/api/inventory/items/${id}/movements`)
      .set(auth(access))
      .send(body);
  }
  function listMovements(access: string, id: string) {
    return request(app.getHttpServer())
      .get(`/api/inventory/items/${id}/movements`)
      .set(auth(access));
  }
  function lowStock(access: string) {
    return request(app.getHttpServer())
      .get('/api/inventory/low-stock')
      .set(auth(access));
  }

  // ---- create + list ----------------------------------------------------
  describe('create + list', () => {
    it('creates a tracked product and lists it', async () => {
      const o = await registerOwner();
      const created = await createItem(o.access, {
        kind: 'product',
        name: 'Óleo 5W30',
        unit: 'L',
        salePriceCents: 4500,
        costPriceCents: 3000,
        marginPercent: 50,
        minQty: 2,
      });
      expect(created.status).toBe(201);
      expect(created.body.kind).toBe('product');
      expect(created.body.track_stock).toBe(true);
      const id = created.body.id as string;

      const list = await listItems(o.access);
      expect(list.status).toBe(200);
      expect(
        (list.body.items as Array<{ id: string }>).map((i) => i.id),
      ).toContain(id);
    });
  });

  // ---- tenant isolation (RLS) — non-negotiable -------------------------
  describe('tenant isolation (RLS)', () => {
    it("tenant B never sees tenant A's item", async () => {
      const a = await registerOwner();
      const b = await registerOwner();

      const created = await createItem(a.access, {
        kind: 'product',
        name: 'Item secreto de A',
      });
      expect(created.status).toBe(201);
      const id = created.body.id as string;

      const bList = await listItems(b.access);
      expect(bList.status).toBe(200);
      expect(
        (bList.body.items as Array<{ id: string }>).map((i) => i.id),
      ).not.toContain(id);

      // direct fetch is invisible under B's RLS -> 404
      const bGet = await getItem(b.access, id);
      expect(bGet.status).toBe(404);
    });
  });

  // ---- movements + cached balance --------------------------------------
  describe('movements + cached balance', () => {
    it('in 10 then out 3 => stock_qty 7, and 2 movements listed', async () => {
      const o = await registerOwner();
      const created = await createItem(o.access, {
        kind: 'product',
        name: 'Parafuso M6',
      });
      const id = created.body.id as string;

      const mIn = await move(o.access, id, { type: 'in', quantity: 10 });
      expect(mIn.status).toBe(201);
      const mOut = await move(o.access, id, { type: 'out', quantity: 3 });
      expect(mOut.status).toBe(201);

      const item = await getItem(o.access, id);
      expect(item.status).toBe(200);
      expect(Number(item.body.stock_qty)).toBe(7);

      const movs = await listMovements(o.access, id);
      expect(movs.status).toBe(200);
      expect((movs.body as unknown[]).length).toBe(2);
    });
  });

  // ---- negative block ---------------------------------------------------
  describe('negative block', () => {
    it('out beyond balance => 400', async () => {
      const o = await registerOwner();
      const created = await createItem(o.access, {
        kind: 'product',
        name: 'Sem estoque',
      });
      const id = created.body.id as string;

      const out = await move(o.access, id, { type: 'out', quantity: 1 });
      expect(out.status).toBe(400);
    });
  });

  // ---- service item rejects movement -----------------------------------
  describe('service item', () => {
    it('is created with track_stock=false and rejects movements (400)', async () => {
      const o = await registerOwner();
      const created = await createItem(o.access, {
        kind: 'service',
        name: 'Troca de óleo',
        salePriceCents: 8000,
        durationMinutes: 30,
      });
      expect(created.status).toBe(201);
      expect(created.body.track_stock).toBe(false);
      const id = created.body.id as string;

      const mov = await move(o.access, id, { type: 'in', quantity: 5 });
      expect(mov.status).toBe(400);
    });
  });

  // ---- low-stock --------------------------------------------------------
  describe('low-stock', () => {
    it('includes a product whose balance is at/below minQty', async () => {
      const o = await registerOwner();
      const created = await createItem(o.access, {
        kind: 'product',
        name: 'Filtro de ar',
        minQty: 5,
      });
      const id = created.body.id as string;

      // add 2 (2 <= 5) -> low stock
      const mIn = await move(o.access, id, { type: 'in', quantity: 2 });
      expect(mIn.status).toBe(201);

      const low = await lowStock(o.access);
      expect(low.status).toBe(200);
      expect((low.body as Array<{ id: string }>).map((i) => i.id)).toContain(id);
    });
  });

  // ---- authorization by role -------------------------------------------
  describe('authorization', () => {
    it('mechanic can read items (inventory.read) but not create them (no inventory.write) -> 403', async () => {
      const o = await registerOwner();
      const mech = await inviteAccept(o, 'mechanic');

      // read is allowed
      const list = await listItems(mech.access);
      expect(list.status).toBe(200);

      // write is denied
      const create = await createItem(mech.access, {
        kind: 'product',
        name: 'Por mecânico',
      });
      expect(create.status).toBe(403);
    });
  });
});
