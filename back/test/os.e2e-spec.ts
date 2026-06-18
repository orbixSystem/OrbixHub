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

// Catálogo externo desligado (lookup determinístico — sem API externa).
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

describe('OS — Ordens de Serviço (e2e)', () => {
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
  const srv = () => app.getHttpServer();

  async function createCustomer(access: string): Promise<string> {
    const res = await request(srv())
      .post('/api/customers')
      .set(auth(access))
      .send({ name: `Cliente ${uniq()}` });
    expect(res.status).toBe(201);
    return res.body.id as string;
  }

  async function createSubject(
    access: string,
    customerId: string,
  ): Promise<string> {
    const res = await request(srv())
      .post(`/api/customers/${customerId}/subjects`)
      .set(auth(access))
      .send({ identifier: `ABC${uniq().slice(0, 4)}`, label: 'Gol' });
    expect(res.status).toBe(201);
    return res.body.id as string;
  }

  async function createInventoryProduct(
    access: string,
    stock: number,
    salePrice = 50,
  ): Promise<string> {
    const res = await request(srv())
      .post('/api/inventory/items')
      .set(auth(access))
      .send({ name: `Peça ${uniq()}`, currentStock: stock, salePrice });
    expect(res.status).toBe(201);
    return res.body.id as string;
  }

  function createOrder(access: string, body: Record<string, unknown>) {
    return request(srv()).post('/api/os/orders').set(auth(access)).send(body);
  }
  function getOrder(access: string, id: string) {
    return request(srv()).get(`/api/os/orders/${id}`).set(auth(access));
  }
  function listOrders(access: string, query = '') {
    return request(srv()).get(`/api/os/orders${query}`).set(auth(access));
  }
  function addItem(access: string, id: string, body: Record<string, unknown>) {
    return request(srv())
      .post(`/api/os/orders/${id}/items`)
      .set(auth(access))
      .send(body);
  }
  function changeStatus(access: string, id: string, status: string) {
    return request(srv())
      .post(`/api/os/orders/${id}/status`)
      .set(auth(access))
      .send({ status });
  }
  function deleteOrder(access: string, id: string) {
    return request(srv()).delete(`/api/os/orders/${id}`).set(auth(access));
  }
  function getInventoryItem(access: string, id: string) {
    return request(srv())
      .get(`/api/inventory/items/${id}`)
      .set(auth(access));
  }
  function listCustomers(access: string, query = '') {
    return request(srv()).get(`/api/customers${query}`).set(auth(access));
  }
  function listSubjects(access: string, query = '') {
    return request(srv()).get(`/api/subjects${query}`).set(auth(access));
  }

  type IdRow = { id: string };
  const ids = (rows: IdRow[]) => rows.map((r) => r.id);

  // ---- 1. create with snapshot ------------------------------------------
  describe('create + snapshot', () => {
    it('creates an OS with customer+subject snapshot and a sequential number', async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);
      const subjectId = await createSubject(o.access, customerId);

      const created = await createOrder(o.access, {
        customerId,
        subjectId,
        complaint: 'Barulho na frente',
      });
      expect(created.status).toBe(201);
      expect(created.body.status).toBe('aberta');
      expect(created.body.number).toMatch(/^OS-\d{4}$/);
      expect(created.body.customer_name).toBeTruthy();
      expect(created.body.subject_label).toBe('Gol');
      expect(created.body.public_token).toBeTruthy();

      const second = await createOrder(o.access, { customerId });
      expect(second.status).toBe(201);
      expect(second.body.number).not.toBe(created.body.number);

      const got = await getOrder(o.access, created.body.id);
      expect(got.status).toBe(200);
      expect(got.body.items).toEqual([]);
    });
  });

  // ---- 1b. create with a brand-new customer on the fly ------------------
  describe('create with new customer on the fly', () => {
    it('creates an OS with a new customer (name+phone), auto-creating the customer', async () => {
      const o = await registerOwner();

      const created = await createOrder(o.access, {
        newCustomerName: 'Maria Avulsa',
        newCustomerPhone: '11988887777',
      });
      expect(created.status).toBe(201);
      expect(created.body.customer_name).toBe('Maria Avulsa');
      expect(created.body.customer_id).toBeTruthy();

      // o cliente foi de fato criado (aponta, não invade — confere via API pública)
      const list = await listCustomers(o.access, '?q=Maria');
      const names = (list.body.items as Array<{ name: string }>).map(
        (c) => c.name,
      );
      expect(names).toContain('Maria Avulsa');
    });

    it('creates an OS with a new customer + vehicle (identifier+attributes)', async () => {
      const o = await registerOwner();

      const created = await createOrder(o.access, {
        newCustomerName: 'João Veículo',
        newCustomerPhone: '11977776666',
        newSubjectIdentifier: 'ABC1D23',
        newSubjectAttributes: { marca: 'VW', modelo: 'Gol' },
      });
      expect(created.status).toBe(201);
      const customerId = created.body.customer_id as string;
      expect(customerId).toBeTruthy();
      expect(created.body.subject_id).toBeTruthy();
      expect(created.body.subject_label).toBe('ABC1D23');

      // o veículo foi criado e está vinculado ao cliente
      const subjects = await listSubjects(o.access, `?customerId=${customerId}`);
      const identifiers = (
        subjects.body.items as Array<{ identifier: string }>
      ).map((s) => s.identifier);
      expect(identifiers).toContain('ABC1D23');
    });

    it('rejects an OS with neither customerId nor newCustomerName (400)', async () => {
      const o = await registerOwner();
      const res = await createOrder(o.access, { complaint: 'sem cliente' });
      expect(res.status).toBe(400);
    });
  });

  // ---- 2. items + total recompute ---------------------------------------
  describe('items + total', () => {
    it('snapshots an inventory product price, adds an avulso, recomputes total', async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);
      const prodId = await createInventoryProduct(o.access, 10, 50);

      const order = await createOrder(o.access, { customerId });
      const orderId = order.body.id as string;

      // produto do estoque → snapshot do preço (50), qty 2 → total 100
      const itemA = await addItem(o.access, orderId, {
        kind: 'product',
        inventoryItemId: prodId,
        quantity: 2,
      });
      expect(itemA.status).toBe(201);
      expect(Number(itemA.body.unit_price)).toBe(50);
      expect(Number(itemA.body.total)).toBe(100);

      // avulso (serviço sem id de estoque) qty 1 * 80 - 10 = 70
      const itemB = await addItem(o.access, orderId, {
        kind: 'service',
        name: 'Mão de obra',
        quantity: 1,
        unitPrice: 80,
        discount: 10,
      });
      expect(itemB.status).toBe(201);
      expect(Number(itemB.body.total)).toBe(70);

      const got = await getOrder(o.access, orderId);
      expect(got.body.items).toHaveLength(2);
      // total da OS = 100 + 70 = 170
      expect(Number(got.body.total)).toBe(170);
    });

    it('rejects an avulso item without a name (400)', async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);
      const order = await createOrder(o.access, { customerId });
      const res = await addItem(o.access, order.body.id, {
        kind: 'service',
        unitPrice: 20,
      });
      expect(res.status).toBe(400);
    });
  });

  // ---- 3. workflow FSM --------------------------------------------------
  describe('workflow (state machine)', () => {
    it('allows valid transitions and rejects invalid ones (400)', async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);
      const order = await createOrder(o.access, { customerId });
      const id = order.body.id as string;

      // aberta → em_execucao (válida; seta started_at)
      const exec = await changeStatus(o.access, id, 'em_execucao');
      expect(exec.status).toBe(200);
      expect(exec.body.status).toBe('em_execucao');
      expect(exec.body.started_at).toBeTruthy();

      // em_execucao → entregue (inválida)
      const bad = await changeStatus(o.access, id, 'entregue');
      expect(bad.status).toBe(400);

      // em_execucao → concluida → entregue (válidas)
      const done = await changeStatus(o.access, id, 'concluida');
      expect(done.status).toBe(200);
      expect(done.body.finished_at).toBeTruthy();
      const delivered = await changeStatus(o.access, id, 'entregue');
      expect(delivered.status).toBe(200);
      expect(delivered.body.closed_at).toBeTruthy();

      // entregue é terminal → qualquer transição falha
      const terminal = await changeStatus(o.access, id, 'aberta');
      expect(terminal.status).toBe(400);
    });

    it('owner can approve; mechanic (no os.approve) is forbidden (403)', async () => {
      const o = await registerOwner();
      const mech = await inviteAccept(o, 'mechanic');
      const customerId = await createCustomer(o.access);
      const order = await createOrder(o.access, { customerId });
      const id = order.body.id as string;

      // → aguardando_aprovacao (válida, os.write)
      const wait = await changeStatus(o.access, id, 'aguardando_aprovacao');
      expect(wait.status).toBe(200);

      // mecânico lê a OS (os.read)
      const mechRead = await getOrder(mech.access, id);
      expect(mechRead.status).toBe(200);

      // mecânico tenta aprovar → 403 (sem os.approve)
      const mechApprove = await changeStatus(mech.access, id, 'aprovada');
      expect(mechApprove.status).toBe(403);

      // owner aprova → 200
      const ownerApprove = await changeStatus(o.access, id, 'aprovada');
      expect(ownerApprove.status).toBe(200);
      expect(ownerApprove.body.status).toBe('aprovada');
    });
  });

  // ---- 4. auto stock decrement on conclusion ---------------------------
  describe('stock decrement on conclusion', () => {
    it('decrements linked inventory product stock by the item quantity', async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);
      const prodId = await createInventoryProduct(o.access, 10, 50);

      const order = await createOrder(o.access, { customerId });
      const id = order.body.id as string;
      await addItem(o.access, id, {
        kind: 'product',
        inventoryItemId: prodId,
        quantity: 3,
      });

      // aberta → em_execucao → concluida (dispara a baixa)
      expect((await changeStatus(o.access, id, 'em_execucao')).status).toBe(200);
      const done = await changeStatus(o.access, id, 'concluida');
      expect(done.status).toBe(200);
      expect(done.body.stock_applied).toBe(true);

      // estoque caiu de 10 para 7
      const inv = await getInventoryItem(o.access, prodId);
      expect(Number(inv.body.current_stock)).toBe(7);
    });
  });

  // ---- 5. soft delete ---------------------------------------------------
  describe('soft delete', () => {
    it('deleted OS disappears from list and 404s; deleting again 404s', async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);
      const order = await createOrder(o.access, { customerId });
      const id = order.body.id as string;

      const del = await deleteOrder(o.access, id);
      expect(del.status).toBe(200);
      expect(del.body.deleted_at).toBeTruthy();

      const list = await listOrders(o.access);
      expect(ids(list.body.items as IdRow[])).not.toContain(id);

      const gone = await getOrder(o.access, id);
      expect(gone.status).toBe(404);

      const again = await deleteOrder(o.access, id);
      expect(again.status).toBe(404);
    });
  });

  // ---- 6. tenant isolation (RLS) ---------------------------------------
  describe('tenant isolation (RLS)', () => {
    it("tenant B never sees tenant A's OS", async () => {
      const a = await registerOwner();
      const b = await registerOwner();
      const customerId = await createCustomer(a.access);
      const order = await createOrder(a.access, { customerId });
      const id = order.body.id as string;

      const bList = await listOrders(b.access);
      expect(ids(bList.body.items as IdRow[])).not.toContain(id);

      const bGet = await getOrder(b.access, id);
      expect(bGet.status).toBe(404);
    });
  });

  // ---- 7. authorization -------------------------------------------------
  describe('authorization', () => {
    it('mechanic can create (has os.write) and read', async () => {
      const o = await registerOwner();
      const mech = await inviteAccept(o, 'mechanic');
      const customerId = await createCustomer(o.access);

      const created = await createOrder(mech.access, { customerId });
      expect(created.status).toBe(201);
      const list = await listOrders(mech.access);
      expect(list.status).toBe(200);
    });
  });
});
