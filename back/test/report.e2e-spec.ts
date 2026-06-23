import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import Redis from 'ioredis';
import { AppModule } from '../src/app.module';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';
import { REDIS } from '../src/common/redis/redis.module';
import { TenantContext } from '../src/common/database/tenant-context';
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

describe('Módulo report (e2e) — Fase 2', () => {
  let app: INestApplication;
  let redis: Redis;
  let mailer: CapturingMailer;
  let tenant: TenantContext;

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
    tenant = app.get(TenantContext);
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
  async function concludeOrder(access: string, id: string) {
    expect((await changeStatus(access, id, 'em_execucao')).status).toBe(200);
    expect((await changeStatus(access, id, 'concluida')).status).toBe(200);
  }

  /** Desabilita o módulo `report` para um tenant (simula tenant sem o módulo). */
  async function disableReport(tenantId: string): Promise<void> {
    await tenant.runWithTenant(tenantId, async () => {
      const db = tenant.getClient();
      await db.tenant_module.updateMany({
        where: { module: { key: 'report' }, tenant_id: tenantId },
        data: { enabled: false },
      });
    });
  }

  const rep = (access: string, path: string) =>
    request(srv()).get(`/api/report/${path}`).set(auth(access));

  // ====================================================================
  // 1. Authentication required (401 sem token)
  // ====================================================================
  it('GET /report/* needs a token (401)', async () => {
    expect((await request(srv()).get('/api/report/revenue')).status).toBe(401);
    expect((await request(srv()).get('/api/report/os')).status).toBe(401);
  });

  // ====================================================================
  // 2. GATE — permissão (mecânico sem report.read → 403)
  // ====================================================================
  it('mechanic (sem report.read) → 403 em /report/*', async () => {
    const o = await registerOwner();
    const mech = await inviteAccept(o, 'mechanic');
    expect((await rep(mech.access, 'revenue')).status).toBe(403);
    expect((await rep(mech.access, 'os')).status).toBe(403);
    expect((await rep(mech.access, 'inventory')).status).toBe(403);
    expect((await rep(mech.access, 'customers')).status).toBe(403);
    expect((await rep(mech.access, 'team')).status).toBe(403);
    expect((await rep(mech.access, 'top-items')).status).toBe(403);
  });

  it('owner (com report.read) → 200 em /report/*', async () => {
    const o = await registerOwner();
    expect((await rep(o.access, 'revenue')).status).toBe(200);
    expect((await rep(o.access, 'os')).status).toBe(200);
    expect((await rep(o.access, 'inventory')).status).toBe(200);
    expect((await rep(o.access, 'customers')).status).toBe(200);
    expect((await rep(o.access, 'team')).status).toBe(200);
    expect((await rep(o.access, 'top-items')).status).toBe(200);
  });

  // ====================================================================
  // 3. GATE — módulo (tenant sem `report` → ModuleAccessGuard bloqueia)
  // ====================================================================
  it('tenant sem o módulo report → bloqueado pelo ModuleAccessGuard', async () => {
    const o = await registerOwner();
    await disableReport(o.tenantId);
    const res = await rep(o.access, 'revenue');
    expect([402, 403]).toContain(res.status);
  });

  // ====================================================================
  // 4. Correctness — revenue (total + byDay)
  // ====================================================================
  it('revenue: total/byStatus/byDay corretos', async () => {
    const o = await registerOwner();
    const customerId = await createCustomer(o.access);

    // 2 OS concluídas: 100 + 300 = 400
    const o1 = await createOrder(o.access, { customerId });
    await addItem(o.access, o1.body.id, {
      kind: 'service',
      name: 'Mão de obra',
      quantity: 1,
      unitPrice: 100,
    });
    await concludeOrder(o.access, o1.body.id);

    const o2 = await createOrder(o.access, { customerId });
    await addItem(o.access, o2.body.id, {
      kind: 'service',
      name: 'Serviço',
      quantity: 1,
      unitPrice: 300,
    });
    await concludeOrder(o.access, o2.body.id);

    const m = await rep(o.access, 'revenue');
    expect(m.status).toBe(200);
    expect(m.body.total).toBe(400);
    expect(m.body.avgTicket).toBe(200);
    // byStatus concluida: 2 / 400
    expect(m.body.byStatus.concluida.count).toBe(2);
    expect(m.body.byStatus.concluida.revenue).toBe(400);
    // byDay: ambas concluídas hoje → 1 bucket, revenue 400, count 2
    expect(Array.isArray(m.body.byDay)).toBe(true);
    const totalByDay = m.body.byDay.reduce(
      (s: number, d: { revenue: number }) => s + d.revenue,
      0,
    );
    expect(totalByDay).toBe(400);
    const countByDay = m.body.byDay.reduce(
      (s: number, d: { count: number }) => s + d.count,
      0,
    );
    expect(countByDay).toBe(2);
  });

  // ====================================================================
  // 5. Correctness — team (agregado por responsável)
  // ====================================================================
  it('team: agregados por responsável (inclui Sem responsável = null)', async () => {
    const o = await registerOwner();
    const customerId = await createCustomer(o.access);
    const mech = await inviteAccept(o, 'mechanic');
    const me = await request(srv()).get('/api/me').set(auth(mech.access));
    const mechUserId = me.body.user.id as string;

    // OS atribuída ao mecânico, concluída (revenue 200)
    const o1 = await createOrder(o.access, {
      customerId,
      assignedTo: mechUserId,
    });
    await addItem(o.access, o1.body.id, {
      kind: 'service',
      name: 'X',
      quantity: 1,
      unitPrice: 200,
    });
    await concludeOrder(o.access, o1.body.id);

    // OS sem responsável, aberta (não concluída)
    const o2 = await createOrder(o.access, { customerId });
    expect(o2.status).toBe(201);

    const t = await rep(o.access, 'team');
    expect(t.status).toBe(200);
    const rows = t.body.rows as Array<{
      assignedTo: string | null;
      orders: number;
      completed: number;
      revenue: number;
    }>;
    const mine = rows.find((r) => r.assignedTo === mechUserId);
    expect(mine).toBeDefined();
    expect(mine!.orders).toBe(1);
    expect(mine!.completed).toBe(1);
    expect(mine!.revenue).toBe(200);
    const unassigned = rows.find((r) => r.assignedTo === null);
    expect(unassigned).toBeDefined();
    expect(unassigned!.orders).toBe(1);
    expect(unassigned!.completed).toBe(0);
  });

  // ====================================================================
  // 6. Correctness — top-items (ordenação por receita desc + kind)
  // ====================================================================
  it('top-items: ordenado por receita desc + filtro kind', async () => {
    const o = await registerOwner();
    const customerId = await createCustomer(o.access);

    const ord = await createOrder(o.access, { customerId });
    // serviço A: 1 x 500 = 500
    await addItem(o.access, ord.body.id, {
      kind: 'service',
      name: 'Serviço A',
      quantity: 1,
      unitPrice: 500,
    });
    // produto B: 2 x 100 = 200
    await addItem(o.access, ord.body.id, {
      kind: 'product',
      name: 'Produto B',
      quantity: 2,
      unitPrice: 100,
    });

    const all = await rep(o.access, 'top-items');
    expect(all.status).toBe(200);
    const rows = all.body.rows as Array<{
      name: string;
      kind: string;
      revenue: number;
      qty: number;
      orders: number;
    }>;
    expect(rows.length).toBe(2);
    // ordenado por receita desc: Serviço A (500) antes de Produto B (200)
    expect(rows[0].name).toBe('Serviço A');
    expect(rows[0].revenue).toBe(500);
    expect(rows[1].name).toBe('Produto B');
    expect(rows[1].revenue).toBe(200);
    expect(rows[1].qty).toBe(2);
    expect(rows[1].orders).toBe(1);

    // filtro kind=product → só Produto B
    const prod = await rep(o.access, 'top-items?kind=product');
    expect(prod.status).toBe(200);
    expect(prod.body.rows.length).toBe(1);
    expect(prod.body.rows[0].name).toBe('Produto B');
    expect(prod.body.kind).toBe('product');
  });

  // ====================================================================
  // 7. Correctness — inventory + customers (linhas)
  // ====================================================================
  it('inventory: posição com linhas + valor', async () => {
    const o = await registerOwner();
    await request(srv())
      .post('/api/inventory/items')
      .set(auth(o.access))
      .send({ name: 'Peça', currentStock: 4, minStock: 1, costPrice: 10 });

    const inv = await rep(o.access, 'inventory');
    expect(inv.status).toBe(200);
    expect(inv.body.stockValue).toBe(40);
    expect(inv.body.rows.length).toBe(1);
    expect(inv.body.rows[0].stockValue).toBe(40);
  });

  it('customers: novos no range + linhas', async () => {
    const o = await registerOwner();
    await createCustomer(o.access);
    await createCustomer(o.access);

    const c = await rep(o.access, 'customers');
    expect(c.status).toBe(200);
    expect(c.body.active).toBe(2);
    expect(c.body.newInRange).toBe(2);
    expect(c.body.rows.length).toBe(2);
  });

  // ====================================================================
  // 8. Tenant isolation — A exclui B
  // ====================================================================
  it("revenue: tenant A's números excluem B", async () => {
    const a = await registerOwner();
    const b = await registerOwner();

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

    const ra = await rep(a.access, 'revenue');
    expect(ra.body.total).toBe(0);

    const rb = await rep(b.access, 'revenue');
    expect(rb.body.total).toBe(300);
  });
});
