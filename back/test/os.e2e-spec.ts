import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import Redis from 'ioredis';
import { randomUUID } from 'crypto';
import { AppModule } from '../src/app.module';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';
import { REDIS } from '../src/common/redis/redis.module';
import { randomCnpj } from './helpers/cnpj';
import {
  MailerService,
  VerificationEmail,
} from '../src/common/mailer/mailer.service';
import {
  STORAGE_PROVIDER,
  StorageProvider,
} from '../src/common/storage/storage.provider';

// Catálogo externo desligado (lookup determinístico — sem API externa).
process.env.CATALOG_ENABLED = 'false';
process.env.CATALOG_PROVIDER = 'noop';

// Storage fake (sem I/O real) — put/remove no-op; url determinística por key.
class FakeStorageProvider extends StorageProvider {
  async put(): Promise<void> {}
  url(key: string): string {
    return `http://test/${key}`;
  }
  async remove(): Promise<void> {}
}

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
      .overrideProvider(STORAGE_PROVIDER)
      .useValue(new FakeStorageProvider())
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
  function addNote(access: string, id: string, body: Record<string, unknown>) {
    return request(srv())
      .post(`/api/os/orders/${id}/notes`)
      .set(auth(access))
      .send(body);
  }
  function addPhoto(
    access: string,
    id: string,
    body: Buffer,
    contentType: string,
    filename = 'x.jpg',
  ) {
    return request(srv())
      .post(`/api/os/orders/${id}/photos`)
      .set(auth(access))
      .attach('file', body, { filename, contentType });
  }
  function deletePhoto(access: string, id: string, photoId: string) {
    return request(srv())
      .delete(`/api/os/orders/${id}/photos/${photoId}`)
      .set(auth(access));
  }
  function subjectHistory(access: string, subjectId: string) {
    return request(srv())
      .get(`/api/subjects/${subjectId}/history`)
      .set(auth(access));
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

  function createTemplate(access: string, body: Record<string, unknown>) {
    return request(srv())
      .post('/api/os/templates')
      .set(auth(access))
      .send(body);
  }
  function listTemplates(access: string) {
    return request(srv()).get('/api/os/templates').set(auth(access));
  }
  function deleteTemplate(access: string, id: string) {
    return request(srv()).delete(`/api/os/templates/${id}`).set(auth(access));
  }
  function applyTemplate(access: string, orderId: string, templateId: string) {
    return request(srv())
      .post(`/api/os/orders/${orderId}/apply-template/${templateId}`)
      .set(auth(access));
  }
  function patchInventoryItem(
    access: string,
    id: string,
    body: Record<string, unknown>,
  ) {
    return request(srv())
      .patch(`/api/inventory/items/${id}`)
      .set(auth(access))
      .send(body);
  }
  function updateItem(
    access: string,
    id: string,
    itemId: string,
    body: Record<string, unknown>,
  ) {
    return request(srv())
      .patch(`/api/os/orders/${id}/items/${itemId}`)
      .set(auth(access))
      .send(body);
  }
  function deleteItem(access: string, id: string, itemId: string) {
    return request(srv())
      .delete(`/api/os/orders/${id}/items/${itemId}`)
      .set(auth(access));
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

  // ---- create-with-id (replay offline preserva uuid) --------------------
  describe('create com id fixo (replay offline)', () => {
    it('order e item aceitam id fornecido; repetir o mesmo create com o mesmo id gera conflito', async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);

      const fixedOrderId = randomUUID();
      const created = await createOrder(o.access, {
        customerId,
        id: fixedOrderId,
      });
      expect(created.status).toBe(201);
      expect(created.body.id).toBe(fixedOrderId);

      const dupOrder = await createOrder(o.access, {
        customerId,
        id: fixedOrderId,
      });
      expect(dupOrder.status).toBe(409);

      const fixedItemId = randomUUID();
      const item = await addItem(o.access, fixedOrderId, {
        kind: 'service',
        name: 'Mão de obra',
        unitPrice: 10,
        id: fixedItemId,
      });
      expect(item.status).toBe(201);
      expect(item.body.id).toBe(fixedItemId);

      const dupItem = await addItem(o.access, fixedOrderId, {
        kind: 'service',
        name: 'Mão de obra 2',
        unitPrice: 5,
        id: fixedItemId,
      });
      expect(dupItem.status).toBe(409);
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

  // ---- 3b. cancelada trava edição + reabertura --------------------------
  describe('cancelada: lock edits + reopen', () => {
    function patchOrder(
      access: string,
      id: string,
      body: Record<string, unknown>,
    ) {
      return request(srv())
        .patch(`/api/os/orders/${id}`)
        .set(auth(access))
        .send(body);
    }

    it('blocks every content mutation once cancelled, then allows them after reopen', async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);
      const order = await createOrder(o.access, { customerId });
      const id = order.body.id as string;

      // aberta → cancelada (transição válida)
      const cancel = await changeStatus(o.access, id, 'cancelada');
      expect(cancel.status).toBe(200);
      expect(cancel.body.status).toBe('cancelada');

      // toda edição de conteúdo é bloqueada (400)
      expect((await patchOrder(o.access, id, { complaint: 'novo' })).status).toBe(
        400,
      );
      expect(
        (await addItem(o.access, id, { kind: 'service', name: 'X', unitPrice: 10 }))
          .status,
      ).toBe(400);
      expect((await addNote(o.access, id, { message: 'nota' })).status).toBe(400);
      expect(
        (await addPhoto(o.access, id, Buffer.from('fakejpg'), 'image/jpeg')).status,
      ).toBe(400);

      // reabrir (cancelada → aberta) — owner tem os.approve
      const reopen = await changeStatus(o.access, id, 'aberta');
      expect(reopen.status).toBe(200);
      expect(reopen.body.status).toBe('aberta');
      // evento de reabertura na timeline (visível ao cliente)
      const ev = (reopen.body.events as Array<{ message: string | null }>)[0];
      expect(ev.message).toBe('OS reaberta');

      // agora volta a aceitar edição
      const addAfter = await addItem(o.access, id, {
        kind: 'service',
        name: 'Mão de obra',
        unitPrice: 50,
      });
      expect(addAfter.status).toBe(201);
    });

    it('mechanic (no os.approve) cannot reopen a cancelled OS (403)', async () => {
      const o = await registerOwner();
      const mech = await inviteAccept(o, 'mechanic');
      const customerId = await createCustomer(o.access);
      const order = await createOrder(o.access, { customerId });
      const id = order.body.id as string;

      const cancel = await changeStatus(o.access, id, 'cancelada');
      expect(cancel.status).toBe(200);

      const mechReopen = await changeStatus(mech.access, id, 'aberta');
      expect(mechReopen.status).toBe(403);
    });

    it('blocks edits on a delivered (entregue) OS too — no reopen path', async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);
      const order = await createOrder(o.access, { customerId });
      const id = order.body.id as string;

      await changeStatus(o.access, id, 'em_execucao');
      await changeStatus(o.access, id, 'concluida');
      const delivered = await changeStatus(o.access, id, 'entregue');
      expect(delivered.status).toBe(200);

      // edição bloqueada
      expect(
        (await addNote(o.access, id, { message: 'tarde demais' })).status,
      ).toBe(400);
      // entregue é terminal — nem reabrir
      expect((await changeStatus(o.access, id, 'aberta')).status).toBe(400);
    });
  });

  // ---- 4. auto stock decrement on em_execucao --------------------------
  describe('stock decrement on em_execucao', () => {
    it('decrements linked inventory product stock when moving to em_execucao', async () => {
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

      // aberta → em_execucao dispara a baixa (o produto já está sendo usado)
      const exec = await changeStatus(o.access, id, 'em_execucao');
      expect(exec.status).toBe(200);

      // estoque caiu de 10 para 7 logo na entrada em execução
      const inv = await getInventoryItem(o.access, prodId);
      expect(Number(inv.body.current_stock)).toBe(7);

      // concluir não baixa de novo (idempotente via reconcileConsumption)
      const done = await changeStatus(o.access, id, 'concluida');
      expect(done.status).toBe(200);
      const inv2 = await getInventoryItem(o.access, prodId);
      expect(Number(inv2.body.current_stock)).toBe(7);
    });
  });

  // ---- 4b. cancelar devolve estoque (fix do bug de cancelamento) --------
  describe('cancelar OS em execução devolve estoque (reconciliação)', () => {
    it('cancelar uma OS em execução devolve as peças ao estoque', async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);

      // 1. cria item de estoque com 10 unidades
      const invId = await createInventoryProduct(o.access, 10, 50);

      // 2. abre OS com 3 unidades do item
      const order = await createOrder(o.access, { customerId });
      expect(order.status).toBe(201);
      const orderId = order.body.id as string;

      const added = await addItem(o.access, orderId, {
        kind: 'product',
        inventoryItemId: invId,
        quantity: 3,
      });
      expect(added.status).toBe(201);

      // 3. coloca em execução → baixa (10 - 3 = 7)
      const exec = await changeStatus(o.access, orderId, 'em_execucao');
      expect(exec.status).toBe(200);
      const inv1 = await getInventoryItem(o.access, invId);
      expect(Number(inv1.body.current_stock)).toBe(7);

      // 4. cancela → estorna (7 + 3 = 10)
      const cancel = await changeStatus(o.access, orderId, 'cancelada');
      expect(cancel.status).toBe(200);
      const inv2 = await getInventoryItem(o.access, invId);
      expect(Number(inv2.body.current_stock)).toBe(10);
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

  // ---- 5b. timeline (events + notes) -----------------------------------
  describe('timeline (events + notes)', () => {
    type EventRow = {
      kind: string;
      message: string | null;
      status_snapshot: string | null;
      visible_public: boolean;
    };

    it('auto-creates a created event, then a status_change event (newest first)', async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);
      const order = await createOrder(o.access, { customerId });
      const id = order.body.id as string;

      // detalhe traz a timeline com o evento 'created' (visível ao cliente)
      const got = await getOrder(o.access, id);
      expect(got.status).toBe(200);
      let events = got.body.events as EventRow[];
      expect(Array.isArray(events)).toBe(true);
      const created = events.find((e) => e.kind === 'created');
      expect(created).toBeTruthy();
      expect(created!.status_snapshot).toBe('aberta');
      expect(created!.visible_public).toBe(true);

      // muda status → surge um evento 'status_change'
      const exec = await changeStatus(o.access, id, 'em_execucao');
      expect(exec.status).toBe(200);

      const after = await getOrder(o.access, id);
      events = after.body.events as EventRow[];
      // mais recente no topo: o status_change é o primeiro
      expect(events[0].kind).toBe('status_change');
      expect(events[0].status_snapshot).toBe('em_execucao');
      expect(events[0].visible_public).toBe(true);
      // o created continua presente
      expect(events.some((e) => e.kind === 'created')).toBe(true);
    });

    it('adds manual notes with visible_public false (default) and true', async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);
      const order = await createOrder(o.access, { customerId });
      const id = order.body.id as string;

      // nota interna (default visiblePublic=false)
      const noteA = await addNote(o.access, id, { message: 'Nota interna' });
      expect(noteA.status).toBe(201);
      expect(noteA.body.kind).toBe('note');
      expect(noteA.body.visible_public).toBe(false);

      // nota visível ao cliente
      const noteB = await addNote(o.access, id, {
        message: 'Visível ao cliente',
        visiblePublic: true,
      });
      expect(noteB.status).toBe(201);
      expect(noteB.body.visible_public).toBe(true);

      const got = await getOrder(o.access, id);
      const notes = (got.body.events as EventRow[]).filter(
        (e) => e.kind === 'note',
      );
      expect(notes).toHaveLength(2);
      const internal = notes.find((n) => n.message === 'Nota interna');
      const publicNote = notes.find((n) => n.message === 'Visível ao cliente');
      expect(internal!.visible_public).toBe(false);
      expect(publicNote!.visible_public).toBe(true);
    });
  });

  // ---- 5c. subject history (SubjectHistoryProvider hookup) -------------
  describe('subject history (customers ↔ os)', () => {
    it("a vehicle's history lists its OS (kind 'os' + number)", async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);
      const subjectId = await createSubject(o.access, customerId);

      const order = await createOrder(o.access, { customerId, subjectId });
      expect(order.status).toBe(201);
      const number = order.body.number as string;

      const hist = await subjectHistory(o.access, subjectId);
      expect(hist.status).toBe(200);
      const entries = hist.body as Array<{
        kind: string;
        title: string;
        status: string;
        subjectId?: string;
      }>;
      const entry = entries.find((e) => e.title === `OS ${number}`);
      expect(entry).toBeTruthy();
      expect(entry!.kind).toBe('os');
      expect(entry!.status).toBe('aberta');
      expect(entry!.subjectId).toBe(subjectId);
    });
  });

  // ---- 5d. photos -------------------------------------------------------
  describe('photos (upload + timeline + delete)', () => {
    type PhotoRow = { id: string; url: string; caption: string | null };
    type EventRow = { kind: string };

    it('uploads an image, appears in detail photos + a photo event, then deletes', async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);
      const order = await createOrder(o.access, { customerId });
      const id = order.body.id as string;

      // upload de uma "imagem" → 201 + url
      const up = await addPhoto(
        o.access,
        id,
        Buffer.from('fakejpg'),
        'image/jpeg',
      );
      expect(up.status).toBe(201);
      expect(up.body.url).toBeTruthy();
      const photoId = up.body.id as string;

      // detalhe traz a foto + um evento 'photo' na timeline
      const got = await getOrder(o.access, id);
      expect(got.status).toBe(200);
      const photos = got.body.photos as PhotoRow[];
      expect(photos).toHaveLength(1);
      expect(photos[0].id).toBe(photoId);
      const events = got.body.events as EventRow[];
      expect(events.some((e) => e.kind === 'photo')).toBe(true);

      // delete → some do detalhe
      const del = await deletePhoto(o.access, id, photoId);
      expect(del.status).toBe(200);
      const after = await getOrder(o.access, id);
      expect((after.body.photos as PhotoRow[])).toHaveLength(0);
    });

    it('rejects a non-image upload (400)', async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);
      const order = await createOrder(o.access, { customerId });
      const id = order.body.id as string;

      const up = await addPhoto(
        o.access,
        id,
        Buffer.from('not an image'),
        'text/plain',
        'x.txt',
      );
      expect(up.status).toBe(400);
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

  // ---- 8. templates de serviço ------------------------------------------
  describe('service templates (CRUD + apply)', () => {
    it('creates a template (inventory-ref + avulso), lists it', async () => {
      const o = await registerOwner();
      const prodId = await createInventoryProduct(o.access, 10, 80);

      const created = await createTemplate(o.access, {
        name: 'Revisão completa',
        description: 'Óleo + filtro + mão de obra',
        items: [
          { kind: 'product', inventoryItemId: prodId, quantity: 2 },
          { kind: 'service', name: 'Mão de obra', quantity: 1, unitPrice: 120 },
        ],
      });
      expect(created.status).toBe(201);
      expect(created.body.name).toBe('Revisão completa');
      expect(created.body.items).toHaveLength(2);
      // Item do estoque foi snapshotado (nome + preço do item).
      const refItem = created.body.items.find(
        (i: { inventory_item_id: string | null }) =>
          i.inventory_item_id === prodId,
      );
      expect(refItem).toBeTruthy();
      expect(Number(refItem.unit_price)).toBe(80);

      const list = await listTemplates(o.access);
      expect(list.status).toBe(200);
      expect(ids(list.body.items as IdRow[])).toContain(
        created.body.id as string,
      );
      expect(typeof list.body.total).toBe('number');
    });

    it('applies a template to an OS: pre-fills items, recomputes total, re-snapshots current price', async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);
      const prodId = await createInventoryProduct(o.access, 10, 80);

      const tpl = await createTemplate(o.access, {
        name: 'Troca de óleo',
        items: [
          { kind: 'product', inventoryItemId: prodId, quantity: 2 },
          { kind: 'service', name: 'Mão de obra', quantity: 1, unitPrice: 120 },
        ],
      });
      expect(tpl.status).toBe(201);

      // Preço do produto sobe DEPOIS de criar o template — apply re-snapshota o atual.
      const patched = await patchInventoryItem(o.access, prodId, {
        salePrice: 100,
      });
      expect(patched.status).toBe(200);

      const order = await createOrder(o.access, { customerId });
      expect(order.status).toBe(201);
      const orderId = order.body.id as string;

      const applied = await applyTemplate(o.access, orderId, tpl.body.id);
      expect(applied.status).toBe(200);
      expect(applied.body.items).toHaveLength(2);
      // Produto re-snapshotado com o preço CORRENTE (100), não o do template (80).
      const prodLine = applied.body.items.find(
        (i: { inventory_item_id: string | null }) =>
          i.inventory_item_id === prodId,
      );
      expect(Number(prodLine.unit_price)).toBe(100);
      // Total = 2*100 (produto) + 1*120 (mão de obra) = 320.
      expect(Number(applied.body.total)).toBe(320);
    });

    it('template total + item price follow the current inventory price (list reflects edits)', async () => {
      const o = await registerOwner();
      const prodId = await createInventoryProduct(o.access, 10, 80);

      const tpl = await createTemplate(o.access, {
        name: 'Revisão',
        items: [
          { kind: 'product', inventoryItemId: prodId, quantity: 2 },
          { kind: 'service', name: 'Mão de obra', quantity: 1, unitPrice: 120 },
        ],
      });
      expect(tpl.status).toBe(201);
      // Na criação: 2*80 (produto) + 1*120 (mão de obra) = 280.
      expect(Number(tpl.body.total)).toBe(280);

      // Sobe o preço do produto no estoque DEPOIS de criar o template.
      const patched = await patchInventoryItem(o.access, prodId, {
        salePrice: 100,
      });
      expect(patched.status).toBe(200);

      // Lista reflete o preço corrente: item do estoque a 100, total = 2*100 + 120 = 320.
      const list = await listTemplates(o.access);
      expect(list.status).toBe(200);
      const found = (
        list.body.items as Array<{
          id: string;
          total: string;
          items: Array<{ inventory_item_id: string | null; unit_price: string }>;
        }>
      ).find((t) => t.id === (tpl.body.id as string))!;
      expect(found).toBeTruthy();
      const prodItem = found.items.find((i) => i.inventory_item_id === prodId)!;
      expect(Number(prodItem.unit_price)).toBe(100);
      expect(Number(found.total)).toBe(320);
    });

    it('soft deletes a template (gone from list)', async () => {
      const o = await registerOwner();
      const tpl = await createTemplate(o.access, {
        name: 'Descartável',
        items: [{ kind: 'service', name: 'X', quantity: 1, unitPrice: 10 }],
      });
      expect(tpl.status).toBe(201);

      const del = await deleteTemplate(o.access, tpl.body.id);
      expect(del.status).toBe(200);

      const list = await listTemplates(o.access);
      expect(ids(list.body.items as IdRow[])).not.toContain(
        tpl.body.id as string,
      );
    });

    it('paginates and searches templates (q matches name, page/pageSize)', async () => {
      const o = await registerOwner();
      for (const name of ['Alpha brake', 'Beta brake', 'Gamma filter']) {
        const r = await createTemplate(o.access, {
          name,
          items: [{ kind: 'service', name: 'X', quantity: 1, unitPrice: 10 }],
        });
        expect(r.status).toBe(201);
      }

      // Busca por nome: só os dois "brake".
      const search = await request(srv())
        .get('/api/os/templates')
        .query({ q: 'brake' })
        .set(auth(o.access));
      expect(search.status).toBe(200);
      expect(search.body.total).toBe(2);
      expect((search.body.items as IdRow[]).length).toBe(2);

      // Paginação: pageSize 1 devolve 1 item mas total reflete o conjunto todo.
      const page1 = await request(srv())
        .get('/api/os/templates')
        .query({ pageSize: 1, page: 1 })
        .set(auth(o.access));
      expect(page1.status).toBe(200);
      expect((page1.body.items as IdRow[]).length).toBe(1);
      expect(page1.body.total).toBe(3);
    });
  });

  // ---- 9b. reconciliar estoque ao editar item de OS em execução ----------
  describe('reconciliar estoque ao editar item de OS em execução', () => {
    it('reduzir a quantidade de um item em execução estorna a diferença', async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);

      // produto com 10 unidades
      const prodId = await createInventoryProduct(o.access, 10, 80);

      const order = await createOrder(o.access, { customerId });
      expect(order.status).toBe(201);
      const orderId = order.body.id as string;

      // adiciona 4 unidades à OS (ainda aberta)
      const addRes = await addItem(o.access, orderId, {
        kind: 'product',
        inventoryItemId: prodId,
        quantity: 4,
      });
      expect(addRes.status).toBe(201);
      const itemId = addRes.body.id as string;

      // coloca em execução → baixa 4 (10 - 4 = 6)
      const exec = await changeStatus(o.access, orderId, 'em_execucao');
      expect(exec.status).toBe(200);
      let inv = await getInventoryItem(o.access, prodId);
      expect(Number(inv.body.current_stock)).toBe(6);

      // reduz de 4 para 1 → estorna 3 (6 + 3 = 9)
      const updRes = await updateItem(o.access, orderId, itemId, { quantity: 1 });
      expect(updRes.status).toBe(200);
      inv = await getInventoryItem(o.access, prodId);
      expect(Number(inv.body.current_stock)).toBe(9);

      // remove o item → estorna o 1 restante (9 + 1 = 10)
      const delRes = await deleteItem(o.access, orderId, itemId);
      expect(delRes.status).toBe(200);
      inv = await getInventoryItem(o.access, prodId);
      expect(Number(inv.body.current_stock)).toBe(10);
    });
  });

  // ---- 9. low-stock notification on em_execucao -------------------------
  function notifications(access: string) {
    return request(srv()).get('/api/notifications').set(auth(access));
  }

  describe('estoque baixo ao executar a OS', () => {
    it('baixa que cruza o mínimo ao entrar em execução gera notificação', async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);

      // produto com saldo 5, mínimo 3 — consumir 3 derruba para 2 (cruza o mínimo)
      const prodId = await createInventoryProduct(o.access, 5, 20);
      const minStockPatch = await patchInventoryItem(o.access, prodId, { minStock: 3 });
      expect(minStockPatch.status).toBe(200);

      const order = await createOrder(o.access, { customerId });
      const orderId = order.body.id as string;

      const added = await addItem(o.access, orderId, {
        kind: 'product',
        inventoryItemId: prodId,
        quantity: 3,
      });
      expect(added.status).toBe(201);

      const exec = await changeStatus(o.access, orderId, 'em_execucao');
      expect(exec.status).toBe(200);

      // estoque caiu de 5 para 2 (abaixo do mínimo 3)
      const inv = await getInventoryItem(o.access, prodId);
      expect(Number(inv.body.current_stock)).toBe(2);

      // notificação inventory_low_stock deve existir para este produto
      const notif = await notifications(o.access);
      expect(notif.status).toBe(200);
      const low = (notif.body.items as Array<Record<string, unknown>>).find(
        (n) => n.type === 'inventory_low_stock' && n.ref_id === prodId,
      );
      expect(low).toBeTruthy();
    });
  });
});
