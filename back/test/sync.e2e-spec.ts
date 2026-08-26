import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import Redis from 'ioredis';
import { randomUUID } from 'crypto';
import { AppModule } from '../src/app.module';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';
import { REDIS } from '../src/common/redis/redis.module';
import { TenantContext } from '../src/common/database/tenant-context';
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

interface Mutation {
  clientMutationId: string;
  entity: string;
  op: string;
  payload: Record<string, unknown>;
  clientUpdatedAt: string;
}

describe('Sync — pull + push offline (e2e)', () => {
  let app: INestApplication;
  let redis: Redis;
  let mailer: CapturingMailer;

  const OWNER_PW = 'supersecret1';
  const uniq = () => Math.random().toString(36).slice(2, 8);
  const srv = () => app.getHttpServer();
  const auth = (access: string) => ({ Authorization: `Bearer ${access}` });

  // "aplicar" (update deve vencer a linha recém-criada): timestamp no futuro →
  // o clamp o traz a `now`, que é >= updated_at do create já processado no lote.
  const soon = () => new Date(Date.now() + 3_600_000).toISOString();
  // "perder" (LWW): timestamp no passado, anterior à escrita online do servidor.
  const past = () => new Date(Date.now() - 3_600_000).toISOString();

  beforeAll(async () => {
    // A régua de status da assinatura nasce DESLIGADA (BILLING_ENFORCE_SUBSCRIPTION,
    // default false) enquanto não existe o módulo de assinatura. Os casos
    // past_due/canceled abaixo exercitam essa régua, então este suite a liga
    // explicitamente — é o comportamento de quando a cobrança entrar em vigor.
    process.env.BILLING_ENFORCE_SUBSCRIPTION = 'true';
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

  afterAll(async () => {
    // Jest reaproveita o processo entre arquivos do mesmo worker — devolver a
    // variável evita que a régua ligada aqui vaze para outro suite.
    delete process.env.BILLING_ENFORCE_SUBSCRIPTION;
    await app?.close();
  });

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

  /** Descobre o userId do dono/membro a partir de /me (autor do outbox). */
  async function myUserId(access: string): Promise<string> {
    const me = await request(srv()).get('/api/me').set(auth(access));
    expect(me.status).toBe(200);
    return me.body.user.id as string;
  }

  async function inviteAccept(
    owner: Owner,
    role: string,
  ): Promise<{ access: string; userId: string }> {
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
    const access = accept.body.accessToken as string;
    return { access, userId: await myUserId(access) };
  }

  /** Liga/desliga um módulo do tenant (simula um plano sem o módulo). */
  async function setModuleEnabled(
    tenantId: string,
    moduleKey: string,
    enabled: boolean,
  ): Promise<void> {
    const tenant = app.get(TenantContext);
    await tenant.runWithTenant(tenantId, async () => {
      const db = tenant.getClient();
      const tm = await db.tenant_module.findFirst({
        where: { module: { key: moduleKey } },
      });
      if (!tm) throw new Error(`tenant_module ausente: ${moduleKey}`);
      await db.tenant_module.update({
        where: {
          tenant_id_module_id: {
            tenant_id: tm.tenant_id,
            module_id: tm.module_id,
          },
        },
        data: { enabled },
      });
    });
  }

  /** Força o status da assinatura do tenant (past_due/canceled). */
  async function setSubscriptionStatus(
    tenantId: string,
    status: string,
  ): Promise<void> {
    const tenant = app.get(TenantContext);
    await tenant.runWithTenant(tenantId, async () => {
      const db = tenant.getClient();
      const sub = await db.subscription.findFirst();
      if (!sub) throw new Error('assinatura ausente');
      await db.subscription.update({ where: { id: sub.id }, data: { status } });
    });
  }

  const createCustomer = (access: string, body: Record<string, unknown>) =>
    request(srv()).post('/api/customers').set(auth(access)).send(body);
  const patchCustomer = (
    access: string,
    id: string,
    body: Record<string, unknown>,
  ) => request(srv()).patch(`/api/customers/${id}`).set(auth(access)).send(body);
  const getCustomer = (access: string, id: string) =>
    request(srv()).get(`/api/customers/${id}`).set(auth(access));
  const listCustomers = (access: string) =>
    request(srv()).get('/api/customers?status=all').set(auth(access));

  const pull = (access: string, query: string) =>
    request(srv()).get(`/api/sync/changes${query}`).set(auth(access));
  const push = (
    access: string,
    authorUserId: string,
    mutations: Mutation[],
  ) =>
    request(srv())
      .post('/api/sync/push')
      .set(auth(access))
      .send({ authorUserId, mutations });

  const mut = (
    entity: string,
    op: string,
    payload: Record<string, unknown>,
    clientUpdatedAt = soon(),
  ): Mutation => ({
    clientMutationId: randomUUID(),
    entity,
    op,
    payload,
    clientUpdatedAt,
  });

  // ====================================================================
  // 1. Pull — paginação por cursor (sem duplicar linhas entre páginas)
  // ====================================================================
  it('pull pagina por cursor: 3 clientes, limit 2 → nextCursor → página 2', async () => {
    const o = await registerOwner();
    const ids = [randomUUID(), randomUUID(), randomUUID()];
    for (const id of ids) {
      expect((await createCustomer(o.access, { id, name: `C ${id.slice(0, 4)}`, phone: '11999999999' })).status).toBe(201);
    }

    const p1 = await pull(o.access, '?entity=customer&limit=2');
    expect(p1.status).toBe(200);
    expect(p1.body.rows).toHaveLength(2);
    expect(p1.body.nextCursor).toBeTruthy();
    expect(p1.body.serverTime).toBeTruthy();

    const c = p1.body.nextCursor as { ts: string; id: string };
    const p2 = await pull(
      o.access,
      `?entity=customer&limit=2&sinceTs=${encodeURIComponent(c.ts)}&sinceId=${c.id}`,
    );
    expect(p2.status).toBe(200);
    expect(p2.body.rows).toHaveLength(1);
    // I3 - a pagina PARCIAL tambem devolve cursor (o cliente sempre o persiste);
    // "acabou" e dito por `hasMore: false`, nao por `nextCursor: null`.
    expect(p2.body.nextCursor).toBeTruthy();
    expect(p2.body.hasMore).toBe(false);
    expect(p1.body.hasMore).toBe(true);

    // união das duas páginas = os 3 ids, sem duplicatas
    const seen = [
      ...(p1.body.rows as Array<{ id: string }>).map((r) => r.id),
      ...(p2.body.rows as Array<{ id: string }>).map((r) => r.id),
    ];
    expect(new Set(seen).size).toBe(3);
    expect([...seen].sort()).toEqual([...ids].sort());
  });

  // ====================================================================
  // 2. Push — aplica create + update via services
  // ====================================================================
  it('push aplica create + update (mesma resposta traz entityId)', async () => {
    const o = await registerOwner();
    const uid = await myUserId(o.access);
    const cId = randomUUID();

    const res = await push(o.access, uid, [
      mut('customer', 'create', { id: cId, name: 'Original', phone: '11999999999' }),
      mut('customer', 'update', { id: cId, name: 'Atualizado' }),
    ]);
    expect(res.status).toBe(201);
    const results = res.body.results as Array<{
      status: string;
      entityId?: string;
    }>;
    expect(results.map((r) => r.status)).toEqual(['applied', 'applied']);
    expect(results[0].entityId).toBe(cId);
    expect(res.body.serverTime).toBeTruthy();

    const got = await getCustomer(o.access, cId);
    expect(got.status).toBe(200);
    expect(got.body.name).toBe('Atualizado');
  });

  // ====================================================================
  // 3. Idempotência — reenviar o mesmo lote → mesmos results, sem duplicar
  // ====================================================================
  it('re-push do mesmo lote é idempotente (mesmos results, sem duplicar)', async () => {
    const o = await registerOwner();
    const uid = await myUserId(o.access);
    const cId = randomUUID();
    const batch = [
      mut('customer', 'create', { id: cId, name: 'Uno', phone: '11999999999' }),
      mut('customer', 'update', { id: cId, name: 'Dos' }),
    ];

    const first = await push(o.access, uid, batch);
    expect((first.body.results as Array<{ status: string }>).map((r) => r.status)).toEqual([
      'applied',
      'applied',
    ]);

    const second = await push(o.access, uid, batch);
    expect(second.status).toBe(201);
    expect((second.body.results as Array<{ status: string }>).map((r) => r.status)).toEqual([
      'applied',
      'applied',
    ]);

    // sem duplicação: continua havendo exatamente 1 cliente
    const list = await listCustomers(o.access);
    expect(list.body.total).toBe(1);
    expect(list.body.items[0].name).toBe('Dos');
  });

  // ====================================================================
  // S1 — autor do lote != usuário autenticado → 403
  // ====================================================================
  it('S1: authorUserId diferente do usuário autenticado → 403', async () => {
    const o = await registerOwner();
    const res = await push(o.access, randomUUID(), [
      mut('customer', 'create', { id: randomUUID(), name: 'X', phone: '11999999999' }),
    ]);
    expect(res.status).toBe(403);
  });

  // ====================================================================
  // S2 — LWW: linha do servidor mais nova vence → discarded
  // ====================================================================
  it('S2: mutação com clientUpdatedAt antigo perde para a linha mais nova → discarded', async () => {
    const o = await registerOwner();
    const uid = await myUserId(o.access);
    const cId = randomUUID();
    expect((await createCustomer(o.access, { id: cId, name: 'Base', phone: '11999999999' })).status).toBe(201);
    // escrita ONLINE (servidor) DEPOIS do timestamp do cliente → updated_at = agora
    expect((await patchCustomer(o.access, cId, { name: 'Servidor Vence' })).status).toBe(200);

    const res = await push(o.access, uid, [
      mut('customer', 'update', { id: cId, name: 'Cliente Perde' }, past()),
    ]);
    expect(res.status).toBe(201);
    expect((res.body.results as Array<{ status: string }>)[0].status).toBe('discarded');

    const got = await getCustomer(o.access, cId);
    expect(got.body.name).toBe('Servidor Vence');
  });

  // ====================================================================
  // S7 — whitelist do replay: op desconhecida e campo extra → error
  // ====================================================================
  it('S7: entity.op desconhecido → error; payload com campo extra → error', async () => {
    const o = await registerOwner();
    const uid = await myUserId(o.access);

    const unknown = await push(o.access, uid, [
      mut('customer', 'frobnicate', { id: randomUUID() }),
    ]);
    expect(unknown.status).toBe(201);
    expect((unknown.body.results as Array<{ status: string }>)[0].status).toBe('error');

    const extra = await push(o.access, uid, [
      mut('customer', 'create', { id: randomUUID(), name: 'Y', phone: '11999999999', bogus: 1 }),
    ]);
    expect((extra.body.results as Array<{ status: string }>)[0].status).toBe('error');

    // nada foi criado pelo payload inválido
    expect((await listCustomers(o.access)).body.total).toBe(0);
  });

  // ====================================================================
  // S8 — mesmo clientMutationId de autores diferentes → ambos aplicam
  // ====================================================================
  it('S8: mesmo clientMutationId de autores distintos aplica para os dois', async () => {
    const o = await registerOwner();
    const ownerId = await myUserId(o.access);
    const b = await inviteAccept(o, 'gerente');

    const sharedCmid = randomUUID();
    const idA = randomUUID();
    const idB = randomUUID();

    const resA = await push(o.access, ownerId, [
      { clientMutationId: sharedCmid, entity: 'customer', op: 'create', payload: { id: idA, name: 'A', phone: '11999999999' }, clientUpdatedAt: soon() },
    ]);
    expect((resA.body.results as Array<{ status: string }>)[0].status).toBe('applied');

    const resB = await push(b.access, b.userId, [
      { clientMutationId: sharedCmid, entity: 'customer', op: 'create', payload: { id: idB, name: 'B', phone: '11999999999' }, clientUpdatedAt: soon() },
    ]);
    expect((resB.body.results as Array<{ status: string }>)[0].status).toBe('applied');

    // ambos os clientes existem no mesmo tenant
    expect((await getCustomer(o.access, idA)).status).toBe(200);
    expect((await getCustomer(o.access, idB)).status).toBe(200);
  });

  // ====================================================================
  // S9 — create com id já existente → error (nunca sobrescreve)
  // ====================================================================
  it('S9: create com id já existente → error', async () => {
    const o = await registerOwner();
    const uid = await myUserId(o.access);
    const cId = randomUUID();
    expect((await createCustomer(o.access, { id: cId, name: 'Dono', phone: '11999999999' })).status).toBe(201);

    const res = await push(o.access, uid, [
      mut('customer', 'create', { id: cId, name: 'Intruso', phone: '11999999999' }),
    ]);
    expect(res.status).toBe(201);
    const item = (res.body.results as Array<{ status: string; message?: string }>)[0];
    expect(item.status).toBe('error');
    // a linha original permanece intacta
    expect((await getCustomer(o.access, cId)).body.name).toBe('Dono');
  });

  // ====================================================================
  // S10 — lote de 101 mutações → 400 (anti-DoS)
  // ====================================================================
  it('S10: lote com 101 mutações → 400', async () => {
    const o = await registerOwner();
    const uid = await myUserId(o.access);
    const mutations = Array.from({ length: 101 }, () =>
      mut('customer', 'create', { id: randomUUID(), name: 'Z', phone: '11999999999' }),
    );
    const res = await push(o.access, uid, mutations);
    expect(res.status).toBe(400);
  });

  // ====================================================================
  // Pull — gate de leitura por entidade (espelha os GETs do módulo dono)
  // ====================================================================
  it('pull exige a permissão de leitura da entidade: mechanic sem cashier.read → 403; com os.read → 200', async () => {
    const o = await registerOwner();
    const mech = await inviteAccept(o, 'mechanic');

    // mechanic NÃO tem cashier.read (seed): o extrato do caixa é negado online
    // e no pull — sem o gate, o sync vazaria valores/sangrias ao cargo.
    const cash = await pull(mech.access, '?entity=cash_entry&limit=10');
    expect(cash.status).toBe(403);
    const sessions = await pull(mech.access, '?entity=cash_session&limit=10');
    expect(sessions.status).toBe(403);

    // mechanic TEM os.read → pull de OS funciona normalmente.
    const orders = await pull(mech.access, '?entity=service_order&limit=10');
    expect(orders.status).toBe(200);
    expect(orders.body.serverTime).toBeTruthy();
  });

  // ====================================================================
  // Isolamento de tenant — pull e push
  // ====================================================================
  it('isolamento: B não vê linhas de A no pull; push de B na linha de A nunca aplica', async () => {
    const a = await registerOwner();
    const b = await registerOwner();
    const bId = await myUserId(b.access);
    const aCustomer = randomUUID();
    expect((await createCustomer(a.access, { id: aCustomer, name: 'Cliente de A', phone: '11999999999' })).status).toBe(201);

    // pull de B não enxerga o cliente de A
    const bPull = await pull(b.access, '?entity=customer&limit=100');
    expect(bPull.status).toBe(200);
    expect(bPull.body.rows).toHaveLength(0);

    // push de B tentando atualizar a linha de A → nunca aplica (error/discarded)
    const res = await push(b.access, bId, [
      mut('customer', 'update', { id: aCustomer, name: 'Invadido' }),
    ]);
    expect(res.status).toBe(201);
    expect((res.body.results as Array<{ status: string }>)[0].status).not.toBe('applied');

    // a linha de A continua intacta
    expect((await getCustomer(a.access, aCustomer)).body.name).toBe('Cliente de A');
  });
  // ====================================================================
  // C1 — replay dos sub-itens da OS (o payload endereça a OS-pai por `orderId`)
  // ====================================================================
  it('replay de service_order.addItem/updateItem/deleteItem chega ao servidor (item e total corretos)', async () => {
    const o = await registerOwner();
    const uid = await myUserId(o.access);
    const orderId = randomUUID();
    const created = await request(srv())
      .post('/api/os/orders')
      .set(auth(o.access))
      .send({ id: orderId, newCustomerName: 'Cliente da OS', newCustomerPhone: '11999999999' });
    expect(created.status).toBe(201);

    // addItem: a OS-pai vai em `orderId` (chave estrutural). Antes, com `id`, o
    // campo homônimo do CreateItemDto apagava o roteamento e o item se perdia.
    const add = await push(o.access, uid, [
      mut('service_order', 'addItem', {
        orderId,
        kind: 'service',
        name: 'Troca de óleo',
        quantity: 2,
        unitPrice: 50,
      }),
    ]);
    expect(add.status).toBe(201);
    const addResult = (
      add.body.results as Array<{
        status: string;
        entityId?: string;
        message?: string;
      }>
    )[0];
    expect(addResult.message).toBeUndefined();
    expect(addResult.status).toBe('applied');
    const itemId = addResult.entityId as string;
    expect(itemId).toBeTruthy();

    let order = await request(srv())
      .get(`/api/os/orders/${orderId}`)
      .set(auth(o.access));
    expect(order.status).toBe(200);
    expect(order.body.items).toHaveLength(1);
    expect(order.body.items[0].name).toBe('Troca de óleo');
    expect(Number(order.body.total)).toBe(100);

    // updateItem
    const upd = await push(o.access, uid, [
      mut('service_order', 'updateItem', { id: orderId, itemId, quantity: 3 }),
    ]);
    expect((upd.body.results as Array<{ status: string }>)[0].status).toBe('applied');
    order = await request(srv())
      .get(`/api/os/orders/${orderId}`)
      .set(auth(o.access));
    expect(Number(order.body.total)).toBe(150);

    // deleteItem
    const del = await push(o.access, uid, [
      mut('service_order', 'deleteItem', { id: orderId, itemId }),
    ]);
    const delResult = (del.body.results as Array<{ status: string; message?: string }>)[0];
    expect(delResult.message).toBeUndefined();
    expect(delResult.status).toBe('applied');
    order = await request(srv())
      .get(`/api/os/orders/${orderId}`)
      .set(auth(o.access));
    expect(order.body.items).toHaveLength(0);
    expect(Number(order.body.total)).toBe(0);
  });

  it('replay de op sem corpo (EmptyPayloadDto): customer.archive aplica; campo extra ainda é recusado', async () => {
    const o = await registerOwner();
    const uid = await myUserId(o.access);
    const cId = randomUUID();
    expect((await createCustomer(o.access, { id: cId, name: 'Arquivar', phone: '11999999999' })).status).toBe(201);

    const res = await push(o.access, uid, [
      mut('customer', 'archive', { id: cId }),
    ]);
    const r = (res.body.results as Array<{ status: string; message?: string }>)[0];
    expect(r.message).toBeUndefined();
    expect(r.status).toBe('applied');
    expect((await getCustomer(o.access, cId)).body.status).toBe('archived');

    // whitelist S7 continua valendo mesmo sem campos declarados no DTO
    const bad = await push(o.access, uid, [
      mut('customer', 'archive', { id: cId, hack: 1 }),
    ]);
    expect((bad.body.results as Array<{ status: string }>)[0].status).toBe('error');
  });

  // ====================================================================
  // I2 — gating comercial (plano/assinatura) POR ENTIDADE no /sync
  // ====================================================================
  it('módulo fora do plano: pull da entidade → 403 e push da entidade → error (outros módulos seguem)', async () => {
    const o = await registerOwner();
    const uid = await myUserId(o.access);
    await setModuleEnabled(o.tenantId, 'inventory', false);

    const p = await pull(o.access, '?entity=inventory_item&limit=10');
    expect(p.status).toBe(403);

    const cId = randomUUID();
    const res = await push(o.access, uid, [
      mut('inventory_item', 'create', { id: randomUUID(), name: 'Filtro' }),
      mut('customer', 'create', { id: cId, name: 'Cliente OK', phone: '11999999999' }),
    ]);
    expect(res.status).toBe(201);
    const results = res.body.results as Array<{ status: string; message?: string }>;
    expect(results[0].status).toBe('error');
    expect(results[0].message).toContain('inventory');
    // O item de OUTRO módulo (habilitado) continua sendo aplicado — nada de 403
    // aniquilando o lote inteiro.
    expect(results[1].status).toBe('applied');
    expect((await getCustomer(o.access, cId)).status).toBe(200);
    expect((await pull(o.access, '?entity=customer&limit=10')).status).toBe(200);
  });

  it('assinatura past_due: pull continua liberado, push vira item error', async () => {
    const o = await registerOwner();
    const uid = await myUserId(o.access);
    await setSubscriptionStatus(o.tenantId, 'past_due');

    expect((await pull(o.access, '?entity=customer&limit=10')).status).toBe(200);

    const res = await push(o.access, uid, [
      mut('customer', 'create', { id: randomUUID(), name: 'Não deve entrar', phone: '11999999999' }),
    ]);
    const results = res.body.results as Array<{ status: string; message?: string }>;
    expect(results[0].status).toBe('error');
    expect(results[0].message).toContain('past_due');
  });

  it('assinatura canceled: pull → 403', async () => {
    const o = await registerOwner();
    await setSubscriptionStatus(o.tenantId, 'canceled');
    const p = await pull(o.access, '?entity=customer&limit=10');
    expect(p.status).toBe(403);
  });

  // ====================================================================
  // I3 — pull incremental de verdade: o cursor da página parcial é utilizável
  // ====================================================================
  it('pull incremental: com o cursor salvo nada é re-baixado; só a linha nova volta', async () => {
    const o = await registerOwner();
    const first = randomUUID();
    expect((await createCustomer(o.access, { id: first, name: 'Primeiro', phone: '11999999999' })).status).toBe(201);

    const p1 = await pull(o.access, '?entity=customer&limit=500');
    expect(p1.body.rows).toHaveLength(1);
    expect(p1.body.hasMore).toBe(false);
    const c = p1.body.nextCursor as { ts: string; id: string };
    expect(c).toBeTruthy();

    const q = (cur: { ts: string; id: string }) =>
      `?entity=customer&limit=500&sinceTs=${encodeURIComponent(cur.ts)}&sinceId=${cur.id}`;

    // 2ª rodada com o cursor salvo: NADA volta (antes, como o cursor nunca era
    // salvo, a tabela inteira era rebaixada a cada rodada).
    const p2 = await pull(o.access, q(c));
    expect(p2.body.rows).toHaveLength(0);
    expect(p2.body.nextCursor).toBeNull();
    expect(p2.body.hasMore).toBe(false);

    // só a linha NOVA volta na rodada seguinte
    const second = randomUUID();
    expect((await createCustomer(o.access, { id: second, name: 'Segundo', phone: '11999999999' })).status).toBe(201);
    const p3 = await pull(o.access, q(c));
    expect((p3.body.rows as Array<{ id: string }>).map((r) => r.id)).toEqual([second]);
    expect(p3.body.nextCursor).toBeTruthy();
  });
});
