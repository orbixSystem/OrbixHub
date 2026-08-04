import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import Redis from 'ioredis';
import { AppModule } from '../src/app.module';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';
import { REDIS } from '../src/common/redis/redis.module';
import { randomCnpj } from './helpers/cnpj';
import {
  MailerService,
  VerificationEmail,
} from '../src/common/mailer/mailer.service';

// Catálogo externo desligado (sem chamada externa).
process.env.CATALOG_ENABLED = 'false';
process.env.CATALOG_PROVIDER = 'noop';

class CapturingMailer extends MailerService {
  public readonly sent: VerificationEmail[] = [];
  async send(email: VerificationEmail): Promise<void> {
    this.sent.push(email);
  }

  /// `sendMessage` virou abstrato quando o SMTP entrou (merge da `qa`). O e2e não
  /// testa envio de mensagem — engolir aqui mantém o fake compilando sem inventar
  /// asserção sobre um canal que estes testes não exercitam.
  async sendMessage(): Promise<void> {}
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

describe('Métricas por módulo (e2e) — Fase 1 dashboard', () => {
  let app: INestApplication;
  let redis: Redis;
  let mailer: CapturingMailer;

  const OWNER_PW = 'supersecret1';
  const uniq = () => Math.random().toString(36).slice(2, 8);
  const auth = (access: string) => ({ Authorization: `Bearer ${access}` });
  const srv = () => app.getHttpServer();

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
    const reg = await request(srv())
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
    const inv = await request(srv())
      .post('/api/tenants/invites')
      .set(auth(owner.access))
      .send({ email, role, currentPassword: owner.password });
    expect(inv.status).toBe(201);
    const token = mailer.lastTokenFor('invite', email);
    expect(token).toBeTruthy();
    const accept = await request(srv())
      .post('/api/invites/accept')
      .send({ token, fullName: 'Member', password });
    expect(accept.status).toBe(200);
    return { access: accept.body.accessToken as string };
  }

  async function createCustomer(access: string): Promise<string> {
    const res = await request(srv())
      .post('/api/customers')
      .set(auth(access))
      .send({ name: `Cliente ${uniq()}` });
    expect(res.status).toBe(201);
    return res.body.id as string;
  }

  async function createProduct(
    access: string,
    body: Record<string, unknown>,
  ): Promise<string> {
    const res = await request(srv())
      .post('/api/inventory/items')
      .set(auth(access))
      .send({ name: `Peça ${uniq()}`, ...body });
    expect(res.status).toBe(201);
    return res.body.id as string;
  }

  function createOrder(access: string, body: Record<string, unknown>) {
    return request(srv()).post('/api/os/orders').set(auth(access)).send(body);
  }
  function changeStatus(access: string, id: string, status: string) {
    return request(srv())
      .post(`/api/os/orders/${id}/status`)
      .set(auth(access))
      .send({ status });
  }
  function addItem(access: string, id: string, body: Record<string, unknown>) {
    return request(srv())
      .post(`/api/os/orders/${id}/items`)
      .set(auth(access))
      .send(body);
  }
  function patchOrder(access: string, id: string, body: Record<string, unknown>) {
    return request(srv())
      .patch(`/api/os/orders/${id}`)
      .set(auth(access))
      .send(body);
  }

  // Leva uma OS recém-criada até 'concluida' (revenue + ciclo).
  async function concludeOrder(access: string, id: string) {
    expect((await changeStatus(access, id, 'em_execucao')).status).toBe(200);
    expect((await changeStatus(access, id, 'concluida')).status).toBe(200);
  }

  const osMetrics = (access: string, q = '') =>
    request(srv()).get(`/api/os/metrics${q}`).set(auth(access));
  const invMetrics = (access: string) =>
    request(srv()).get('/api/inventory/metrics').set(auth(access));
  const custMetrics = (access: string, q = '') =>
    request(srv()).get(`/api/customers/metrics${q}`).set(auth(access));

  // ====================================================================
  // 1. Authentication required (401 sem token)
  // ====================================================================
  describe('authentication', () => {
    it('GET /os|inventory|customers/metrics needs a token (401)', async () => {
      expect((await request(srv()).get('/api/os/metrics')).status).toBe(401);
      expect((await request(srv()).get('/api/inventory/metrics')).status).toBe(
        401,
      );
      expect((await request(srv()).get('/api/customers/metrics')).status).toBe(
        401,
      );
    });
  });

  // ====================================================================
  // 2. Authorization (papel com a permissão de leitura → 200)
  // ====================================================================
  describe('authorization', () => {
    it('mechanic (has os/inventory/customer.read) reads all three metrics (200)', async () => {
      const o = await registerOwner();
      const mech = await inviteAccept(o, 'mechanic');
      expect((await osMetrics(mech.access)).status).toBe(200);
      expect((await invMetrics(mech.access)).status).toBe(200);
      expect((await custMetrics(mech.access)).status).toBe(200);
    });

    it('rejects an unknown query param (whitelist, 400)', async () => {
      const o = await registerOwner();
      const res = await osMetrics(o.access, '?bogus=1');
      expect(res.status).toBe(400);
    });
  });

  // ====================================================================
  // 3. OS metrics correctness
  // ====================================================================
  describe('os metrics — correctness', () => {
    it('computes byStatus, revenue, avgTicket, inExecution, overdue', async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);

      // OS #1 concluída, total 100 (item avulso 100)
      const o1 = await createOrder(o.access, { customerId });
      expect(o1.status).toBe(201);
      await addItem(o.access, o1.body.id, {
        kind: 'service',
        name: 'Mão de obra',
        quantity: 1,
        unitPrice: 100,
      });
      await concludeOrder(o.access, o1.body.id);

      // OS #2 concluída, total 300
      const o2 = await createOrder(o.access, { customerId });
      await addItem(o.access, o2.body.id, {
        kind: 'service',
        name: 'Serviço',
        quantity: 1,
        unitPrice: 300,
      });
      await concludeOrder(o.access, o2.body.id);

      // OS #3 em execução (não conta no faturamento)
      const o3 = await createOrder(o.access, { customerId });
      expect((await changeStatus(o.access, o3.body.id, 'em_execucao')).status).toBe(
        200,
      );

      // OS #4 atrasada: scheduled_end no passado + ainda aberta
      const o4 = await createOrder(o.access, { customerId });
      const past = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
      expect(
        (await patchOrder(o.access, o4.body.id, { scheduledEnd: past })).status,
      ).toBe(200);

      const m = await osMetrics(o.access);
      expect(m.status).toBe(200);
      // 2 concluídas → revenue 400, avgTicket 200
      expect(m.body.revenue).toBe(400);
      expect(m.body.avgTicket).toBe(200);
      // byStatus: concluida 2, em_execucao 1, aberta 1
      expect(m.body.byStatus.concluida).toBe(2);
      expect(m.body.byStatus.em_execucao).toBe(1);
      expect(m.body.byStatus.aberta).toBe(1);
      expect(m.body.inExecution).toBe(1);
      // o4 está atrasada (aberta + scheduled_end no passado)
      expect(m.body.overdue).toBeGreaterThanOrEqual(1);
      // avgCycleMs presente (>=0) — OS concluídas têm started/finished
      expect(m.body.avgCycleMs).not.toBeNull();
      expect(m.body.avgCycleMs).toBeGreaterThanOrEqual(0);
    });

    it('assignedTo scopes the counts to that mechanic', async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);

      // descobre o membershipId do mecânico via IAM
      const mech = await inviteAccept(o, 'mechanic');
      const me = await request(srv())
        .get('/api/me')
        .set(auth(mech.access));
      expect(me.status).toBe(200);
      const mechUserId = me.body.user.id as string;

      // OS atribuída ao mecânico
      const o1 = await createOrder(o.access, {
        customerId,
        assignedTo: mechUserId,
      });
      expect(o1.status).toBe(201);
      // OS sem atribuição
      const o2 = await createOrder(o.access, { customerId });
      expect(o2.status).toBe(201);

      const scoped = await osMetrics(o.access, `?assignedTo=${mechUserId}`);
      expect(scoped.status).toBe(200);
      // só a OS do mecânico entra na contagem
      expect(scoped.body.byStatus.aberta).toBe(1);

      const all = await osMetrics(o.access);
      expect(all.body.byStatus.aberta).toBe(2);
    });
  });

  // ====================================================================
  // 4. Inventory metrics correctness
  // ====================================================================
  describe('inventory metrics — correctness', () => {
    it('computes belowMin, stockValue, products/services counts + sample', async () => {
      const o = await registerOwner();
      // produto abaixo do mínimo: stock 2 < min 5, cost 10 → value 20
      await createProduct(o.access, {
        currentStock: 2,
        minStock: 5,
        costPrice: 10,
      });
      // produto ok: stock 10 >= min 1, cost 5 → value 50
      await createProduct(o.access, {
        currentStock: 10,
        minStock: 1,
        costPrice: 5,
      });
      // serviço (não entra em stockValue/products)
      const svc = await request(srv())
        .post('/api/inventory/items')
        .set(auth(o.access))
        .send({ name: 'Mão de obra', kind: 'service', salePrice: 80 });
      expect(svc.status).toBe(201);

      const m = await invMetrics(o.access);
      expect(m.status).toBe(200);
      expect(m.body.belowMin).toBe(1);
      // stockValue = 2*10 + 10*5 = 70
      expect(m.body.stockValue).toBe(70);
      expect(m.body.products).toBe(2);
      expect(m.body.services).toBe(1);
      expect(Array.isArray(m.body.lowStockSample)).toBe(true);
      expect(m.body.lowStockSample.length).toBe(1);
      expect(m.body.lowStockSample[0].current_stock).toBe(2);
    });
  });

  // ====================================================================
  // 5. Customers metrics correctness
  // ====================================================================
  describe('customers metrics — correctness', () => {
    it('computes active total + newInRange', async () => {
      const o = await registerOwner();
      await createCustomer(o.access);
      await createCustomer(o.access);

      const m = await custMetrics(o.access);
      expect(m.status).toBe(200);
      expect(m.body.active).toBe(2);
      expect(m.body.newInRange).toBe(2);

      // janela no passado (não pega os clientes criados agora)
      const from = new Date(Date.now() - 60 * 24 * 3600 * 1000).toISOString();
      const to = new Date(Date.now() - 40 * 24 * 3600 * 1000).toISOString();
      const past = await custMetrics(o.access, `?from=${from}&to=${to}`);
      expect(past.status).toBe(200);
      expect(past.body.active).toBe(2); // ativo é total, independe do range
      expect(past.body.newInRange).toBe(0);
    });
  });

  // ====================================================================
  // 6. Tenant isolation (RLS) — A não vê os números de B
  // ====================================================================
  describe('tenant isolation (RLS)', () => {
    it("os metrics: tenant A's aggregates exclude tenant B", async () => {
      const a = await registerOwner();
      const b = await registerOwner();

      // B cria 3 OS concluídas (total 100 cada)
      const bCustomer = await createCustomer(b.access);
      for (let i = 0; i < 3; i++) {
        const ord = await createOrder(b.access, { customerId: bCustomer });
        await addItem(b.access, ord.body.id, {
          kind: 'service',
          name: 'X',
          quantity: 1,
          unitPrice: 100,
        });
        await concludeOrder(b.access, ord.body.id);
      }

      // A não tem nenhuma OS → tudo zerado, sem ver as de B
      const ma = await osMetrics(a.access);
      expect(ma.status).toBe(200);
      expect(ma.body.revenue).toBe(0);
      expect(ma.body.byStatus.concluida ?? 0).toBe(0);

      // B vê as suas (revenue 300, 3 concluídas)
      const mb = await osMetrics(b.access);
      expect(mb.body.revenue).toBe(300);
      expect(mb.body.byStatus.concluida).toBe(3);
    });

    it('inventory + customers metrics: A excludes B', async () => {
      const a = await registerOwner();
      const b = await registerOwner();

      await createProduct(b.access, {
        currentStock: 5,
        minStock: 1,
        costPrice: 10,
      });
      await createCustomer(b.access);

      const invA = await invMetrics(a.access);
      expect(invA.body.products).toBe(0);
      expect(invA.body.stockValue).toBe(0);

      const custA = await custMetrics(a.access);
      expect(custA.body.active).toBe(0);
      expect(custA.body.newInRange).toBe(0);

      const invB = await invMetrics(b.access);
      expect(invB.body.products).toBe(1);
      expect(invB.body.stockValue).toBe(50);
    });
  });
});
