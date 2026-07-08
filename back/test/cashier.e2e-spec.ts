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

describe('Cashier — Caixa (e2e)', () => {
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

  // cashier endpoints
  const openSession = (access: string, body: Record<string, unknown> = {}) =>
    request(srv()).post('/api/cashier/sessions/open').set(auth(access)).send(body);
  const closeSession = (access: string, body: Record<string, unknown>) =>
    request(srv()).post('/api/cashier/sessions/close').set(auth(access)).send(body);
  const currentSession = (access: string, deviceId?: string) =>
    request(srv())
      .get(`/api/cashier/sessions/current${deviceId ? `?deviceId=${deviceId}` : ''}`)
      .set(auth(access));
  const createEntry = (access: string, body: Record<string, unknown>) =>
    request(srv()).post('/api/cashier/entries').set(auth(access)).send(body);
  const reverseEntry = (access: string, id: string, body: Record<string, unknown>) =>
    request(srv())
      .post(`/api/cashier/entries/${id}/reverse`)
      .set(auth(access))
      .send(body);
  const listEntries = (access: string, query = '') =>
    request(srv()).get(`/api/cashier/entries${query}`).set(auth(access));
  const summary = (access: string, query = '') =>
    request(srv()).get(`/api/cashier/summary${query}`).set(auth(access));
  const getConfig = (access: string) =>
    request(srv()).get('/api/cashier/config').set(auth(access));
  const patchConfig = (access: string, body: Record<string, unknown>) =>
    request(srv()).patch('/api/cashier/config').set(auth(access)).send(body);

  // os helpers (cria uma OS com total conhecido)
  async function createOrderWithTotal(access: string, total: number): Promise<string> {
    const cust = await request(srv())
      .post('/api/customers')
      .set(auth(access))
      .send({ name: `Cliente ${uniq()}` });
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
  const getOrder = (access: string, id: string) =>
    request(srv()).get(`/api/os/orders/${id}`).set(auth(access));

  // ====================================================================
  // 1. Sessões — abrir/fechar, uma aberta por tenant, expected×counted
  // ====================================================================
  describe('sessões', () => {
    it('abre uma sessão e rejeita a segunda abertura (409)', async () => {
      const o = await registerOwner();
      const first = await openSession(o.access, { openingAmount: 100 });
      expect(first.status).toBe(201);
      expect(first.body.status).toBe('open');
      expect(Number(first.body.opening_amount)).toBe(100);

      const second = await openSession(o.access, { openingAmount: 50 });
      expect(second.status).toBe(409);
    });

    it('fecha calculando expected×counted×difference (só dinheiro)', async () => {
      const o = await registerOwner();
      await openSession(o.access, { openingAmount: 100 });
      // dinheiro: +50 (suprimento), -20 (despesa) ⇒ esperado = 100 + 50 - 20 = 130
      expect((await createEntry(o.access, { amount: 50, method: 'dinheiro', category: 'suprimento' })).status).toBe(201);
      expect((await createEntry(o.access, { amount: 20, method: 'dinheiro', category: 'despesa' })).status).toBe(201);
      // pix NÃO entra no esperado (countCashOnly): +999 pix
      expect((await createEntry(o.access, { amount: 999, method: 'pix', category: 'suprimento' })).status).toBe(201);

      const cur = await currentSession(o.access);
      expect(cur.body.totals.expected).toBe(130);

      const closed = await closeSession(o.access, { countedAmount: 125 });
      expect(closed.status).toBe(200);
      expect(closed.body.status).toBe('closed');
      expect(Number(closed.body.closing_amount_expected)).toBe(130);
      expect(Number(closed.body.difference)).toBe(-5); // falta de 5

      // fechado ⇒ não há sessão atual (null vira corpo vazio na resposta HTTP)
      const after = await currentSession(o.access);
      expect(after.body).toEqual({});
    });
  });

  // ====================================================================
  // create-with-id (replay offline preserva uuid)
  // ====================================================================
  describe('create com id fixo (replay offline)', () => {
    it('sessão e lançamento aceitam id fornecido; repetir o mesmo create com o mesmo id gera conflito', async () => {
      const o = await registerOwner();
      const deviceId = randomUUID();
      const fixedSessionId = randomUUID();

      const opened = await openSession(o.access, {
        openingAmount: 50,
        deviceId,
        id: fixedSessionId,
      });
      expect(opened.status).toBe(201);
      expect(opened.body.id).toBe(fixedSessionId);

      const dupSession = await openSession(o.access, {
        openingAmount: 10,
        deviceId: randomUUID(),
        id: fixedSessionId,
      });
      expect(dupSession.status).toBe(409);

      const fixedEntryId = randomUUID();
      const entry = await createEntry(o.access, {
        amount: 10,
        method: 'dinheiro',
        category: 'suprimento',
        deviceId,
        id: fixedEntryId,
      });
      expect(entry.status).toBe(201);
      expect(entry.body.id).toBe(fixedEntryId);

      const dupEntry = await createEntry(o.access, {
        amount: 20,
        method: 'dinheiro',
        category: 'suprimento',
        deviceId,
        id: fixedEntryId,
      });
      expect(dupEntry.status).toBe(409);
    });
  });

  // ====================================================================
  // 2. Recebimento de OS — parcial + múltiplas formas; getPaymentSummary
  // ====================================================================
  describe('recebimento de OS', () => {
    it('recebe parcial em 2 formas; OS reflete pago/parcial/pago', async () => {
      const o = await registerOwner();
      const orderId = await createOrderWithTotal(o.access, 100);
      await openSession(o.access, { openingAmount: 0 });

      // 40 em dinheiro + 30 em pix ⇒ pago 70, parcial
      expect((await createEntry(o.access, { amount: 40, method: 'dinheiro', category: 'os_payment', saleKind: 'os', saleId: orderId })).status).toBe(201);
      expect((await createEntry(o.access, { amount: 30, method: 'pix', category: 'os_payment', saleKind: 'os', saleId: orderId })).status).toBe(201);

      const got = await getOrder(o.access, orderId);
      expect(got.body.payment.total).toBe(100);
      expect(got.body.payment.paid).toBe(70);
      expect(got.body.payment.balance).toBe(30);
      expect(got.body.payment.status).toBe('parcial');

      // lista de OS traz o payment_status derivado (batch)
      const list = await request(srv())
        .get('/api/os/orders')
        .set(auth(o.access));
      const row = (list.body.items as Array<{ id: string; payment_status: string }>)
        .find((r) => r.id === orderId);
      expect(row?.payment_status).toBe('parcial');

      // quita o restante ⇒ pago
      expect((await createEntry(o.access, { amount: 30, method: 'dinheiro', category: 'os_payment', saleKind: 'os', saleId: orderId })).status).toBe(201);
      const paid = await getOrder(o.access, orderId);
      expect(paid.body.payment.status).toBe('pago');
      expect(paid.body.payment.balance).toBe(0);
    });

    it('os_payment sem saleId é rejeitado (400)', async () => {
      const o = await registerOwner();
      await openSession(o.access, {});
      const res = await createEntry(o.access, {
        amount: 10,
        method: 'dinheiro',
        category: 'os_payment',
      });
      expect(res.status).toBe(400);
    });

    it('lançar sem caixa aberto é rejeitado (400)', async () => {
      const o = await registerOwner();
      const res = await createEntry(o.access, {
        amount: 10,
        method: 'dinheiro',
        category: 'despesa',
      });
      expect(res.status).toBe(400);
    });
  });

  // ====================================================================
  // 3. Extrato + resumo
  // ====================================================================
  describe('extrato & resumo', () => {
    it('lista com filtros e entrega totais por método/categoria', async () => {
      const o = await registerOwner();
      await openSession(o.access, { openingAmount: 0 });
      await createEntry(o.access, { amount: 100, method: 'dinheiro', category: 'suprimento' });
      await createEntry(o.access, { amount: 40, method: 'pix', category: 'venda_avulsa' });
      await createEntry(o.access, { amount: 25, method: 'dinheiro', category: 'despesa' });

      const all = await listEntries(o.access);
      expect(all.body.total).toBe(3);

      const onlyOut = await listEntries(o.access, '?direction=out');
      expect(onlyOut.body.total).toBe(1);
      expect(onlyOut.body.items[0].category).toBe('despesa');

      const onlyPix = await listEntries(o.access, '?method=pix');
      expect(onlyPix.body.total).toBe(1);

      const sum = await summary(o.access);
      expect(sum.body.totalIn).toBe(140); // 100 + 40
      expect(sum.body.totalOut).toBe(25);
      expect(sum.body.net).toBe(115);
      const dinheiro = (sum.body.byMethod as Array<{ method: string; in: number; out: number }>)
        .find((m) => m.method === 'dinheiro');
      expect(dinheiro).toEqual({ method: 'dinheiro', in: 100, out: 25 });
    });
  });

  // ====================================================================
  // 4. Estorno lógico — fora dos totais, nunca hard delete
  // ====================================================================
  describe('estorno lógico', () => {
    it('estorna sem apagar; sai dos somatórios; 2º estorno 409', async () => {
      const o = await registerOwner();
      const orderId = await createOrderWithTotal(o.access, 100);
      await openSession(o.access, { openingAmount: 0 });
      const entry = await createEntry(o.access, { amount: 100, method: 'dinheiro', category: 'os_payment', saleKind: 'os', saleId: orderId });
      expect(entry.status).toBe(201);
      const entryId = entry.body.id as string;

      // antes: pago
      expect((await getOrder(o.access, orderId)).body.payment.status).toBe('pago');

      const rev = await reverseEntry(o.access, entryId, { reason: 'cobrança duplicada' });
      expect(rev.status).toBe(200);
      expect(rev.body.reversed_at).toBeTruthy();

      // entry continua no extrato (não foi apagada)
      const list = await listEntries(o.access);
      expect(list.body.total).toBe(1);
      expect(list.body.items[0].reversed_at).toBeTruthy();

      // somatório/pagamento ignora estornada ⇒ volta a a_receber
      expect((await getOrder(o.access, orderId)).body.payment.status).toBe('a_receber');
      const sum = await summary(o.access);
      expect(sum.body.totalIn).toBe(0);

      // segundo estorno é conflito
      const again = await reverseEntry(o.access, entryId, { reason: 'de novo' });
      expect(again.status).toBe(409);
    });
  });

  // ====================================================================
  // 5. Isolamento de tenant
  // ====================================================================
  describe('isolamento de tenant', () => {
    it('B não vê o caixa de A', async () => {
      const a = await registerOwner();
      const b = await registerOwner();
      await openSession(a.access, { openingAmount: 100 });
      await createEntry(a.access, { amount: 50, method: 'dinheiro', category: 'suprimento' });

      // B tem o módulo, mas seu caixa está vazio e sem sessão (corpo vazio)
      expect((await currentSession(b.access)).body).toEqual({});
      expect((await listEntries(b.access)).body.total).toBe(0);
      // B pode abrir o próprio (não colide com a sessão de A)
      expect((await openSession(b.access, {})).status).toBe(201);
    });
  });

  // ====================================================================
  // 5b. Caixa por dispositivo (ponto de caixa) — A2
  // ====================================================================
  describe('caixa por dispositivo (ponto de caixa)', () => {
    it('dois devices abrem sessões independentes; mesmo device reabrir é 409; current/entry isolam por device', async () => {
      const o = await registerOwner();
      const deviceA = randomUUID();
      const deviceB = randomUUID();

      const openA = await openSession(o.access, { openingAmount: 100, deviceId: deviceA });
      expect(openA.status).toBe(201);
      const openB = await openSession(o.access, { openingAmount: 50, deviceId: deviceB });
      expect(openB.status).toBe(201);
      expect(openB.body.id).not.toBe(openA.body.id);

      // reabrir no mesmo device A é conflito (mesma regra de "um caixa aberto por ponto")
      const reopenA = await openSession(o.access, { deviceId: deviceA });
      expect(reopenA.status).toBe(409);

      // current isolado por deviceId
      const curA = await currentSession(o.access, deviceA);
      expect(curA.body.id).toBe(openA.body.id);
      const curB = await currentSession(o.access, deviceB);
      expect(curB.body.id).toBe(openB.body.id);

      // entry com deviceId cai na sessão daquele device
      const entry = await createEntry(o.access, {
        amount: 10,
        method: 'dinheiro',
        category: 'suprimento',
        deviceId: deviceA,
      });
      expect(entry.status).toBe(201);
      expect(entry.body.cash_session_id).toBe(openA.body.id);
    });

    it('sem deviceId continua funcionando como ponto legado (NULL); um por tenant', async () => {
      const o = await registerOwner();
      const legacy = await openSession(o.access, { openingAmount: 10 });
      expect(legacy.status).toBe(201);

      const second = await openSession(o.access, {});
      expect(second.status).toBe(409);

      // não colide com um device explícito
      const deviceA = randomUUID();
      const openA = await openSession(o.access, { deviceId: deviceA });
      expect(openA.status).toBe(201);

      const cur = await currentSession(o.access);
      expect(cur.body.id).toBe(legacy.body.id);
    });
  });

  // ====================================================================
  // 6. Autorização por cargo
  // ====================================================================
  describe('autorização', () => {
    it('atendente recebe mas NÃO gerencia; gerente gerencia; mechanic 403', async () => {
      const o = await registerOwner();
      const caixa = await inviteAccept(o, 'caixa');
      const gerente = await inviteAccept(o, 'gerente');
      const mechanic = await inviteAccept(o, 'mechanic');

      // owner (gestão) abre o caixa
      expect((await openSession(o.access, { openingAmount: 0 })).status).toBe(201);

      // caixa (cashier.write, SEM cashier.manage): NÃO abre, NÃO ajusta gaveta,
      // NÃO vê o resumo/histórico de gestão.
      expect((await openSession(caixa, {})).status).toBe(403);
      expect((await createEntry(caixa, { amount: 10, method: 'dinheiro', category: 'suprimento' })).status).toBe(403);
      expect((await createEntry(caixa, { amount: 10, method: 'dinheiro', category: 'despesa' })).status).toBe(403);
      expect((await summary(caixa)).status).toBe(403);
      expect((await closeSession(caixa, { countedAmount: 0 })).status).toBe(403);

      // caixa PODE ler o caixa e receber OS (operação do dia)
      expect((await listEntries(caixa)).status).toBe(200);
      const orderId = await createOrderWithTotal(o.access, 100);
      const rec = await createEntry(caixa, {
        amount: 50, method: 'dinheiro', category: 'os_payment', saleKind: 'os', saleId: orderId,
      });
      expect(rec.status).toBe(201);
      // estorno é gestão → caixa 403
      expect((await reverseEntry(caixa, rec.body.id as string, { reason: 'teste' })).status).toBe(403);

      // gerente (cashier.manage): gerencia
      expect((await summary(gerente)).status).toBe(200);
      expect((await createEntry(gerente, { amount: 5, method: 'dinheiro', category: 'suprimento' })).status).toBe(201);
      expect((await reverseEntry(gerente, rec.body.id as string, { reason: 'estorno de teste' })).status).toBe(200);

      // mechanic: sem cashier.* → 403 em tudo
      expect((await listEntries(mechanic)).status).toBe(403);
      expect((await createEntry(mechanic, { amount: 10, method: 'dinheiro', category: 'os_payment', saleKind: 'os', saleId: orderId })).status).toBe(403);
    });
  });

  // ====================================================================
  // 7. Config
  // ====================================================================
  describe('config', () => {
    it('GET defaults; owner faz PATCH; caixa não pode (403)', async () => {
      const o = await registerOwner();
      const def = await getConfig(o.access);
      expect(def.status).toBe(200);
      expect(def.body.requireOpenSession).toBe(true);
      expect(def.body.countCashOnly).toBe(true);

      const patched = await patchConfig(o.access, { countCashOnly: false });
      expect(patched.status).toBe(200);
      expect(patched.body.countCashOnly).toBe(false);
      expect((await getConfig(o.access)).body.countCashOnly).toBe(false);

      const caixa = await inviteAccept(o, 'caixa');
      expect((await patchConfig(caixa, { countCashOnly: true })).status).toBe(403);
    });
  });
});
