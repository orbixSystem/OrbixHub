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

/** Captures emails so we can read the raw invite token (drives /invites/accept). */
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

describe('Sale — Venda avulsa (e2e)', () => {
  let app: INestApplication;
  let redis: Redis;
  let mailer: CapturingMailer;

  const OWNER_PW = 'supersecret1';
  const uniq = () => Math.random().toString(36).slice(2, 8);
  const srv = () => app.getHttpServer();
  const auth = (access: string) => ({ Authorization: `Bearer ${access}` });

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
        tenantName: `Loja ${uniq()}`,
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

  async function inviteAccept(owner: Owner, role: string): Promise<string> {
    const email = `${uniq()}@ex.com`;
    const inv = await request(srv())
      .post('/api/tenants/invites')
      .set(auth(owner.access))
      .send({ email, role, currentPassword: owner.password });
    expect(inv.status).toBe(201);
    const token = mailer.lastTokenFor('invite', email);
    expect(token).toBeTruthy();
    const accept = await request(srv())
      .post('/api/invites/accept')
      .send({ token, fullName: 'Member', password: 'memberpass123' });
    expect(accept.status).toBe(200);
    return accept.body.accessToken as string;
  }

  // inventory: cria um produto com estoque conhecido
  async function createProduct(
    access: string,
    salePrice: number,
    stock: number,
  ): Promise<string> {
    const res = await request(srv())
      .post('/api/inventory/items')
      .set(auth(access))
      .send({
        name: `Produto ${uniq()}`,
        kind: 'product',
        salePrice,
        currentStock: stock,
      });
    expect(res.status).toBe(201);
    return res.body.id as string;
  }
  const getProduct = (access: string, id: string) =>
    request(srv()).get(`/api/inventory/items/${id}`).set(auth(access));

  // sale + cashier endpoints
  const createSale = (access: string, body: Record<string, unknown>) =>
    request(srv()).post('/api/sales').set(auth(access)).send(body);
  const getSale = (access: string, id: string) =>
    request(srv()).get(`/api/sales/${id}`).set(auth(access));
  const listSales = (access: string, query = '') =>
    request(srv()).get(`/api/sales${query}`).set(auth(access));
  const cancelSale = (access: string, id: string, body: Record<string, unknown> = {}) =>
    request(srv()).post(`/api/sales/${id}/cancel`).set(auth(access)).send(body);
  const emitInvoice = (access: string, id: string) =>
    request(srv()).post('/api/invoices').set(auth(access)).send({ saleId: id });
  const openSession = (access: string, body: Record<string, unknown> = {}) =>
    request(srv()).post('/api/cashier/sessions/open').set(auth(access)).send(body);
  const createEntry = (access: string, body: Record<string, unknown>) =>
    request(srv()).post('/api/cashier/entries').set(auth(access)).send(body);
  const reportSales = (access: string, query = '') =>
    request(srv()).get(`/api/report/sales${query}`).set(auth(access));

  // cria uma OS (serviço) com total conhecido — p/ a lente unificada do relatório
  async function createOrderWithTotal(
    access: string,
    total: number,
  ): Promise<string> {
    const cust = await request(srv())
      .post('/api/customers')
      .set(auth(access))
      .send({ name: `Cliente ${uniq()}`, phone: '11999999999' });
    expect(cust.status).toBe(201);
    const order = await request(srv())
      .post('/api/os/orders')
      .set(auth(access))
      .send({ customerId: cust.body.id });
    expect(order.status).toBe(201);
    const orderId = order.body.id as string;
    const item = await request(srv())
      .post(`/api/os/orders/${orderId}/items`)
      .set(auth(access))
      .send({ kind: 'service', name: 'Mão de obra', quantity: 1, unitPrice: total });
    expect(item.status).toBe(201);
    return orderId;
  }

  // ====================================================================
  // 1. Criar venda (sem cliente), baixa de estoque (só produto)
  // ====================================================================
  describe('criação + baixa de estoque', () => {
    it('cria venda de balcão sem cliente; baixa o estoque do produto', async () => {
      const o = await registerOwner();
      const prod = await createProduct(o.access, 40, 10);

      const sale = await createSale(o.access, {
        items: [
          { inventoryItemId: prod, quantity: 2 },
          { name: 'Serviço avulso', kind: 'service', quantity: 1, unitPrice: 20 },
        ],
      });
      expect(sale.status).toBe(201);
      expect(sale.body.customer_id).toBeNull();
      expect(Number(sale.body.total)).toBe(100); // 2×40 + 20
      expect(sale.body.status).toBe('active');
      expect(sale.body.payment_status).toBe('a_receber');
      expect(sale.body.number).toMatch(/^VND-\d{4}$/);

      // estoque baixou 2 (10 → 8); serviço não mexe em estoque
      const after = await getProduct(o.access, prod);
      expect(Number(after.body.current_stock)).toBe(8);
    });

    it('rejeita venda sem itens (400)', async () => {
      const o = await registerOwner();
      const res = await createSale(o.access, { items: [] });
      expect(res.status).toBe(400);
    });
  });

  // ====================================================================
  // 2. Pagamento derivado do caixa (nasce a_receber; vira pago ao receber)
  // ====================================================================
  describe('pagamento derivado do caixa', () => {
    it('a_receber → pago quando o caixa registra o recebimento (batch na lista)', async () => {
      const o = await registerOwner();
      const sale = await createSale(o.access, {
        items: [{ name: 'Item', kind: 'service', quantity: 1, unitPrice: 100 }],
      });
      const saleId = sale.body.id as string;
      expect(sale.body.payment_status).toBe('a_receber');

      await openSession(o.access, { openingAmount: 0 });
      // recebimento de venda avulsa apontando para a sale (sale_kind='sale')
      const entry = await createEntry(o.access, {
        amount: 100,
        method: 'dinheiro',
        category: 'venda_avulsa',
        saleKind: 'sale',
        saleId,
      });
      expect(entry.status).toBe(201);

      const got = await getSale(o.access, saleId);
      expect(got.body.payment.total).toBe(100);
      expect(got.body.payment.paid).toBe(100);
      expect(got.body.payment.status).toBe('pago');

      // tag de pagamento na listagem (derivada em batch)
      const list = await listSales(o.access);
      const row = (list.body.items as Array<{ id: string; payment_status: string }>)
        .find((r) => r.id === saleId);
      expect(row?.payment_status).toBe('pago');
    });
  });

  // ====================================================================
  // 3. Cancelamento (estorno lógico + devolve estoque)
  // ====================================================================
  describe('cancelamento', () => {
    it('cancela, devolve o estoque e bloqueia 2º cancelamento (409)', async () => {
      const o = await registerOwner();
      const prod = await createProduct(o.access, 30, 5);
      const sale = await createSale(o.access, {
        items: [{ inventoryItemId: prod, quantity: 3 }],
      });
      const saleId = sale.body.id as string;
      // baixou 3 (5 → 2)
      expect(Number((await getProduct(o.access, prod)).body.current_stock)).toBe(2);

      const canc = await cancelSale(o.access, saleId, { reason: 'desistência' });
      expect(canc.status).toBe(200);
      expect(canc.body.status).toBe('canceled');
      expect(canc.body.payment_status).toBe('cancelada');

      // estoque devolvido (2 → 5)
      expect(Number((await getProduct(o.access, prod)).body.current_stock)).toBe(5);

      const again = await cancelSale(o.access, saleId, {});
      expect(again.status).toBe(409);
    });
  });

  // ====================================================================
  // 4. Emitir nota — Fiscal Noop ⇒ autoriza sincronamente (201)
  // ====================================================================
  describe('emitir nota fiscal', () => {
    it('emite nota com sucesso via Noop (autoriza sincronamente)', async () => {
      const o = await registerOwner();
      const sale = await createSale(o.access, {
        items: [{ name: 'X', kind: 'service', quantity: 1, unitPrice: 10 }],
      });
      const res = await emitInvoice(o.access, sale.body.id as string);
      expect(res.status).toBe(201);
    });
  });

  // ====================================================================
  // 5. Isolamento de tenant
  // ====================================================================
  describe('isolamento de tenant', () => {
    it('B não vê a venda de A', async () => {
      const a = await registerOwner();
      const b = await registerOwner();
      const sale = await createSale(a.access, {
        items: [{ name: 'A', kind: 'service', quantity: 1, unitPrice: 50 }],
      });
      const saleId = sale.body.id as string;

      expect((await getSale(b.access, saleId)).status).toBe(404);
      expect((await listSales(b.access)).body.total).toBe(0);
    });
  });

  // ====================================================================
  // 7. Lente "Vendas" no relatório — OS (serviço) + venda (produto) unificado
  // ====================================================================
  describe('relatório — lente Vendas', () => {
    it('lista OS + venda unificado, com tipo/origem e status de pagamento', async () => {
      const o = await registerOwner();
      const orderId = await createOrderWithTotal(o.access, 200);
      const sale = await createSale(o.access, {
        items: [{ name: 'Produto', kind: 'product', quantity: 1, unitPrice: 50 }],
      });
      const saleId = sale.body.id as string;

      const rep = await reportSales(o.access);
      expect(rep.status).toBe(200);
      const rows = rep.body.rows as Array<{
        id: string;
        type: string;
        origin: string;
        paymentStatus: string;
        value: number;
      }>;
      const osRow = rows.find((r) => r.id === orderId);
      const saleRow = rows.find((r) => r.id === saleId);
      expect(osRow).toMatchObject({ type: 'servico', origin: 'os', value: 200 });
      expect(saleRow).toMatchObject({ type: 'produto', origin: 'sale', value: 50 });
      // ambos nascem a_receber (nada recebido no caixa ainda)
      expect(osRow?.paymentStatus).toBe('a_receber');
      expect(saleRow?.paymentStatus).toBe('a_receber');

      // recebe a venda no caixa ⇒ vira pago na lente
      await openSession(o.access, { openingAmount: 0 });
      await createEntry(o.access, {
        amount: 50,
        method: 'dinheiro',
        category: 'venda_avulsa',
        saleKind: 'sale',
        saleId,
      });
      const after = await reportSales(o.access);
      const saleAfter = (after.body.rows as Array<{ id: string; paymentStatus: string }>)
        .find((r) => r.id === saleId);
      expect(saleAfter?.paymentStatus).toBe('pago');

      // filtro por tipo=produto ⇒ só a venda
      const onlyProduto = await reportSales(o.access, '?type=produto');
      const ids = (onlyProduto.body.rows as Array<{ id: string }>).map((r) => r.id);
      expect(ids).toContain(saleId);
      expect(ids).not.toContain(orderId);
    });

    it('faturamento (revenue) inclui as vendas avulsas', async () => {
      const o = await registerOwner();
      // venda ativa de 70 hoje
      await createSale(o.access, {
        items: [{ name: 'Item', kind: 'product', quantity: 1, unitPrice: 70 }],
      });
      const rev = await request(srv())
        .get('/api/report/revenue')
        .set(auth(o.access));
      expect(rev.status).toBe(200);
      // total de faturamento >= 70 (a venda entra), e a quebra expõe a fatia 'venda'
      expect(rev.body.total).toBeGreaterThanOrEqual(70);
      expect(rev.body.byStatus?.venda?.revenue).toBe(70);
    });

    it('isola por tenant: B não vê as vendas/OS de A', async () => {
      const a = await registerOwner();
      const b = await registerOwner();
      await createOrderWithTotal(a.access, 100);
      await createSale(a.access, {
        items: [{ name: 'X', kind: 'product', quantity: 1, unitPrice: 10 }],
      });
      const rep = await reportSales(b.access);
      expect(rep.status).toBe(200);
      expect((rep.body.rows as unknown[]).length).toBe(0);
    });
  });

  // ====================================================================
  // 6. Autorização por cargo
  // ====================================================================
  describe('autorização', () => {
    it('caixa registra venda; mechanic recebe 403', async () => {
      const o = await registerOwner();
      const caixa = await inviteAccept(o, 'caixa');
      const mechanic = await inviteAccept(o, 'mechanic');

      const ok = await createSale(caixa, {
        items: [{ name: 'Item', kind: 'service', quantity: 1, unitPrice: 10 }],
      });
      expect(ok.status).toBe(201);

      // mechanic: sem sale.* → 403 em leitura e escrita
      expect((await listSales(mechanic)).status).toBe(403);
      expect(
        (
          await createSale(mechanic, {
            items: [{ name: 'Item', kind: 'service', quantity: 1, unitPrice: 10 }],
          })
        ).status,
      ).toBe(403);
    });
  });
});
