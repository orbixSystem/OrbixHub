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
import { NoopFiscalGateway } from '../src/modules/invoice/fiscal/noop-fiscal-gateway';

const SECRET =
  process.env.INVOICE_WEBHOOK_SECRET ?? 'dev_invoice_webhook_secret_change_me';
const uniq = () => Math.random().toString(36).slice(2, 8);

// Captura convites (para promover um mecânico e testar autorização por cargo).
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
  password: string;
}

describe('Invoice — Nota Fiscal (e2e)', () => {
  let app: INestApplication;
  let redis: Redis;
  let mailer: CapturingMailer;

  const OWNER_PW = 'supersecret1';

  beforeAll(async () => {
    mailer = new CapturingMailer();
    const mod = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(MailerService)
      .useValue(mailer)
      .compile();
    app = mod.createNestApplication({ rawBody: true });
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
  const srv = () => app.getHttpServer();
  const auth = (access: string) => ({ Authorization: `Bearer ${access}` });

  async function registerOwner(): Promise<Owner> {
    const reg = await request(srv())
      .post('/api/auth/register')
      .send({
        tenantName: `Oficina ${uniq()}`,
        cnpj: randomCnpj(),
        legalName: 'Razão Social Teste',
        slug: `t-${uniq()}`,
        fullName: 'Owner',
        email: `${uniq()}@ex.com`,
        password: OWNER_PW,
      });
    expect(reg.status).toBe(201);
    return {
      access: reg.body.accessToken as string,
      tenantId: reg.body.tenant.id as string,
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

  async function createCustomer(access: string): Promise<string> {
    const res = await request(srv())
      .post('/api/customers')
      .set(auth(access))
      .send({ name: `Cliente ${uniq()}`, phone: '11999999999' });
    expect(res.status).toBe(201);
    return res.body.id as string;
  }

  async function createOrder(access: string, customerId: string): Promise<string> {
    const res = await request(srv())
      .post('/api/os/orders')
      .set(auth(access))
      .send({ customerId });
    expect(res.status).toBe(201);
    return res.body.id as string;
  }

  function addItem(access: string, orderId: string, body: Record<string, unknown>) {
    return request(srv())
      .post(`/api/os/orders/${orderId}/items`)
      .set(auth(access))
      .send(body);
  }

  // OS pronta para faturar: 1 cliente + 1 OS + 1 item avulso de serviço.
  async function billableOrder(access: string): Promise<string> {
    const customerId = await createCustomer(access);
    const orderId = await createOrder(access, customerId);
    const item = await addItem(access, orderId, {
      kind: 'service',
      name: 'Mão de obra',
      quantity: 1,
      unitPrice: 150,
    });
    expect(item.status).toBe(201);
    return orderId;
  }

  async function createSale(access: string): Promise<string> {
    const res = await request(srv())
      .post('/api/sales')
      .set(auth(access))
      .send({
        items: [
          { name: 'Troca de óleo', kind: 'service', quantity: 1, unitPrice: 90 },
        ],
      });
    expect(res.status).toBe(201);
    expect(res.body.status).toBe('active');
    return res.body.id as string;
  }

  function issue(access: string, body: Record<string, unknown>) {
    return request(srv()).post('/api/invoices').set(auth(access)).send(body);
  }
  function listInvoices(access: string, query = '') {
    return request(srv()).get(`/api/invoices${query}`).set(auth(access));
  }
  function getInvoice(access: string, id: string) {
    return request(srv()).get(`/api/invoices/${id}`).set(auth(access));
  }
  function changeStatus(access: string, orderId: string, status: string) {
    return request(srv())
      .post(`/api/os/orders/${orderId}/status`)
      .set(auth(access))
      .send({ status });
  }
  function webhook(body: string, signature: string) {
    return request(srv())
      .post('/api/invoices/webhook')
      .set('x-webhook-signature', signature)
      .set('content-type', 'application/json')
      .send(body);
  }

  type IdRow = { id: string };
  const ids = (rows: IdRow[]) => rows.map((r) => r.id);

  // ---- 1. emissão a partir da OS (happy path) ---------------------------
  describe('emitir a partir da OS', () => {
    it('emite a NF de uma OS: autoriza (Noop), lista e detalha com linhas + timeline', async () => {
      const o = await registerOwner();
      const orderId = await billableOrder(o.access);

      const res = await issue(o.access, { orderId });
      expect(res.status).toBe(201);
      expect(res.body.status).toBe('authorized');
      expect(res.body.document_type).toBe('nfse');
      expect(res.body.number).toBeTruthy();
      expect(res.body.series).toBe('1');
      expect(res.body.access_key).toBeTruthy();
      expect(String(res.body.external_id)).toMatch(/^noop_inv_/);
      expect(Number(res.body.total_amount)).toBe(150);
      expect(res.body.lines).toHaveLength(1);
      expect(res.body.lines[0].kind).toBe('service');

      const list = await listInvoices(o.access);
      expect(list.status).toBe(200);
      expect(ids(list.body.items as IdRow[])).toContain(res.body.id as string);

      const detail = await getInvoice(o.access, res.body.id);
      expect(detail.status).toBe(200);
      expect(detail.body.lines).toHaveLength(1);
      const kinds = (detail.body.events as Array<{ kind: string }>).map(
        (e) => e.kind,
      );
      expect(kinds).toEqual(expect.arrayContaining(['created', 'authorized']));
    });
  });

  // ---- 2. emissão a partir da venda -------------------------------------
  describe('emitir a partir da venda', () => {
    it('emite a NF de uma venda avulsa (consumidor final)', async () => {
      const o = await registerOwner();
      const saleId = await createSale(o.access);

      const res = await issue(o.access, { saleId });
      expect(res.status).toBe(201);
      expect(res.body.status).toBe('authorized');
      expect(res.body.sale_id).toBe(saleId);
      expect(res.body.customer_name).toBe('Consumidor final');
      expect(Number(res.body.total_amount)).toBe(90);
    });
  });

  // ---- 3. guardrails ----------------------------------------------------
  describe('guardrails', () => {
    it('sem OS nem venda -> 400', async () => {
      const o = await registerOwner();
      expect((await issue(o.access, {})).status).toBe(400);
    });

    it('OS e venda ao mesmo tempo -> 400', async () => {
      const o = await registerOwner();
      const orderId = await billableOrder(o.access);
      const saleId = await createSale(o.access);
      expect((await issue(o.access, { orderId, saleId })).status).toBe(400);
    });

    it('OS cancelada -> 400', async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);
      const orderId = await createOrder(o.access, customerId);
      expect((await changeStatus(o.access, orderId, 'cancelada')).status).toBe(200);
      expect((await issue(o.access, { orderId })).status).toBe(400);
    });

    it('OS sem itens -> 400', async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);
      const orderId = await createOrder(o.access, customerId);
      expect((await issue(o.access, { orderId })).status).toBe(400);
    });

    it('nota duplicada na mesma OS -> 409', async () => {
      const o = await registerOwner();
      const orderId = await billableOrder(o.access);
      expect((await issue(o.access, { orderId })).status).toBe(201);
      expect((await issue(o.access, { orderId })).status).toBe(409);
    });
  });

  // ---- 4. autorização por cargo -----------------------------------------
  describe('autorização por cargo', () => {
    it('mecânico lê notas (invoice.read) mas não pode emitir (sem invoice.issue) -> 403', async () => {
      const o = await registerOwner();
      const mechAccess = await inviteAccept(o, 'mechanic');
      const orderId = await billableOrder(o.access);

      // lê (tem invoice.read)
      expect((await listInvoices(mechAccess)).status).toBe(200);
      // emite -> 403 (não tem invoice.issue)
      expect((await issue(mechAccess, { orderId })).status).toBe(403);
    });
  });

  // ---- 5. isolamento de tenant (RLS) ------------------------------------
  describe('isolamento de tenant (RLS)', () => {
    it('tenant B nunca vê a nota do tenant A', async () => {
      const a = await registerOwner();
      const b = await registerOwner();
      const orderId = await billableOrder(a.access);
      const created = await issue(a.access, { orderId });
      expect(created.status).toBe(201);
      const invoiceId = created.body.id as string;

      const bList = await listInvoices(b.access);
      expect(ids(bList.body.items as IdRow[])).not.toContain(invoiceId);

      const bGet = await getInvoice(b.access, invoiceId);
      expect(bGet.status).not.toBe(200);
    });
  });

  // ---- 6. webhook: assinatura + idempotência ----------------------------
  describe('webhook fiscal', () => {
    it('assinatura inválida -> 400; válida atualiza; duplicado -> no-op', async () => {
      const o = await registerOwner();
      const orderId = await billableOrder(o.access);
      const created = await issue(o.access, { orderId });
      expect(created.status).toBe(201);
      const invoiceId = created.body.id as string;
      const externalId = created.body.external_id as string;

      const body = JSON.stringify({
        id: `evt_${uniq()}`,
        type: 'invoice.canceled',
        data: { externalId },
      });
      const sig = NoopFiscalGateway.sign(body, SECRET);

      // assinatura inválida -> 400, sem alterar a nota
      expect((await webhook(body, 'bad')).status).toBe(400);
      const stillAuthorized = await getInvoice(o.access, invoiceId);
      expect(stillAuthorized.body.status).toBe('authorized');

      // assinatura válida -> 200 e status vira 'canceled'
      expect((await webhook(body, sig)).status).toBe(200);
      const afterOk = await getInvoice(o.access, invoiceId);
      expect(afterOk.body.status).toBe('canceled');

      // mesmo id de evento -> 200 no-op (idempotente)
      expect((await webhook(body, sig)).status).toBe(200);
    });
  });
});
