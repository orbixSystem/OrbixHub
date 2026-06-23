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
import {
  STORAGE_PROVIDER,
  StorageProvider,
} from '../src/common/storage/storage.provider';
import { MessagesService } from '../src/modules/messages/messages.service';

// Catálogo externo desligado (sem chamadas externas).
process.env.CATALOG_ENABLED = 'false';
process.env.CATALOG_PROVIDER = 'noop';

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
}

interface Owner {
  access: string;
  tenantId: string;
}

describe('Mensagens + Notificações (e2e)', () => {
  let app: INestApplication;
  let redis: Redis;
  let messages: MessagesService;

  const OWNER_PW = 'supersecret1';
  const uniq = () => Math.random().toString(36).slice(2, 8);

  beforeAll(async () => {
    const mailer = new CapturingMailer();
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
    messages = app.get(MessagesService);
  });

  beforeEach(async () => {
    await redis.flushall();
  });

  afterAll(async () => app?.close());

  const auth = (access: string) => ({ Authorization: `Bearer ${access}` });
  const srv = () => app.getHttpServer();

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
    };
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
  function listConversations(access: string) {
    return request(srv())
      .get('/api/messages/conversations')
      .set(auth(access));
  }
  function getThread(access: string, id: string) {
    return request(srv())
      .get(`/api/messages/conversations/${id}`)
      .set(auth(access));
  }
  function postStaffMessage(access: string, id: string, body: string) {
    return request(srv())
      .post(`/api/messages/conversations/${id}/messages`)
      .set(auth(access))
      .send({ body });
  }
  function listNotifications(access: string) {
    return request(srv()).get('/api/notifications').set(auth(access));
  }
  function markNotificationRead(access: string, id: string) {
    return request(srv())
      .post(`/api/notifications/${id}/read`)
      .set(auth(access));
  }
  function markAllNotificationsRead(access: string) {
    return request(srv()).post('/api/notifications/read-all').set(auth(access));
  }

  type ConvRow = {
    id: string;
    ref_type: string;
    ref_id: string;
    title: string | null;
    ref_label: string | null;
    staff_unread: number;
  };

  // ---- 1. OS auto-creates a conversation -------------------------------
  describe('conversa criada ao abrir a OS', () => {
    it('uma OS recém-criada aparece no inbox com title = nome do cliente', async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);
      const order = await createOrder(o.access, { customerId });
      expect(order.status).toBe(201);
      const orderId = order.body.id as string;
      const customerName = order.body.customer_name as string;

      const list = await listConversations(o.access);
      expect(list.status).toBe(200);
      const convs = list.body.items as ConvRow[];
      const conv = convs.find(
        (c) => c.ref_type === 'os' && c.ref_id === orderId,
      );
      expect(conv).toBeTruthy();
      expect(conv!.title).toBe(customerName);
      // ref_label = número da OS (distingue clientes homônimos no inbox).
      expect(conv!.ref_label).toBe(order.body.number as string);
      expect(conv!.staff_unread).toBe(0);
    });
  });

  // ---- 2. staff message in the thread ----------------------------------
  describe('mensagem do staff', () => {
    it('staff posta uma mensagem e ela aparece na thread (sender staff)', async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);
      const order = await createOrder(o.access, { customerId });
      const list = await listConversations(o.access);
      const convId = (list.body.items as ConvRow[])[0].id;

      const posted = await postStaffMessage(o.access, convId, 'Olá, tudo certo!');
      expect(posted.status).toBe(201);
      expect(posted.body.sender).toBe('staff');
      expect(posted.body.author_name).toBe('Equipe');
      expect(posted.body.body).toBe('Olá, tudo certo!');

      const thread = await getThread(o.access, convId);
      expect(thread.status).toBe(200);
      const msgs = thread.body.messages as Array<{
        sender: string;
        body: string;
      }>;
      expect(msgs.some((m) => m.sender === 'staff' && m.body === 'Olá, tudo certo!')).toBe(true);
      // staff postando não gera não-lida pro staff
      expect(thread.body.conversation.staff_unread).toBe(0);
    });
  });

  // ---- 3. customer message path (service-level — endpoint público é Fase 5) ----
  // Sem o endpoint público ainda, exercitamos postCustomerMessage direto no service:
  // valida (a) staff_unread incrementa, (b) a mensagem entra na thread como 'customer',
  // (c) uma notificação tenant-wide é criada. Reset de staff_unread ao abrir a thread.
  describe('mensagem do cliente → não-lida + notificação (via service)', () => {
    it('postCustomerMessage incrementa staff_unread e cria notificação; abrir a thread zera', async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);
      const order = await createOrder(o.access, { customerId });
      const orderId = order.body.id as string;

      const conv = await messages.findByRef(o.tenantId, 'os', orderId);
      expect(conv).toBeTruthy();

      // simula mensagem do cliente pelo link público
      const msg = await messages.postCustomerMessage(
        o.tenantId,
        conv!.id,
        'Quando fica pronto?',
        'Cliente Teste',
      );
      expect(msg.sender).toBe('customer');

      // inbox: staff_unread = 1
      const list = await listConversations(o.access);
      const row = (list.body.items as ConvRow[]).find((c) => c.id === conv!.id);
      expect(row!.staff_unread).toBe(1);

      // notificação criada (tenant-wide)
      const notifs = await listNotifications(o.access);
      expect(notifs.status).toBe(200);
      expect(notifs.body.unread).toBeGreaterThanOrEqual(1);
      const n = (notifs.body.items as Array<{
        type: string;
        title: string;
        ref_type: string;
        ref_id: string;
      }>).find((x) => x.type === 'message' && x.ref_id === conv!.id);
      expect(n).toBeTruthy();
      // O título carrega o nome de quem enviou (snapshot do autor da mensagem).
      expect(n!.title).toBe('Nova mensagem de Cliente Teste');
      expect(n!.ref_type).toBe('message');

      // staff abre a thread → staff_unread zera e a msg do cliente aparece
      const thread = await getThread(o.access, conv!.id);
      expect(thread.body.conversation.staff_unread).toBe(0);
      const msgs = thread.body.messages as Array<{ sender: string }>;
      expect(msgs.some((m) => m.sender === 'customer')).toBe(true);

      const after = await listConversations(o.access);
      const rowAfter = (after.body.items as ConvRow[]).find((c) => c.id === conv!.id);
      expect(rowAfter!.staff_unread).toBe(0);
    });
  });

  // ---- 4. notifications list + mark read -------------------------------
  describe('notificações: lista, marca lida, marca todas', () => {
    it('GET /notifications retorna items + unread; marcar lida e marcar todas funcionam', async () => {
      const o = await registerOwner();
      const customerId = await createCustomer(o.access);
      const order = await createOrder(o.access, { customerId });
      const conv = await messages.findByRef(
        o.tenantId,
        'os',
        order.body.id as string,
      );
      await messages.postCustomerMessage(o.tenantId, conv!.id, 'Oi');
      await messages.postCustomerMessage(o.tenantId, conv!.id, 'Tem novidade?');

      const list = await listNotifications(o.access);
      expect(list.body.unread).toBe(2);
      const items = list.body.items as Array<{ id: string }>;
      expect(items.length).toBe(2);

      // marca uma lida → unread cai pra 1
      const one = await markNotificationRead(o.access, items[0].id);
      expect(one.status).toBe(200);
      const after = await listNotifications(o.access);
      expect(after.body.unread).toBe(1);

      // marca todas → unread = 0
      const all = await markAllNotificationsRead(o.access);
      expect(all.status).toBe(200);
      const final = await listNotifications(o.access);
      expect(final.body.unread).toBe(0);
    });
  });

  // ---- 5. tenant isolation (RLS) ---------------------------------------
  describe('isolamento de tenant (RLS)', () => {
    it('tenant B não vê conversas nem notificações do tenant A', async () => {
      const a = await registerOwner();
      const b = await registerOwner();
      const customerId = await createCustomer(a.access);
      const order = await createOrder(a.access, { customerId });
      const convA = await messages.findByRef(
        a.tenantId,
        'os',
        order.body.id as string,
      );
      await messages.postCustomerMessage(a.tenantId, convA!.id, 'msg de A');

      // B não vê a conversa de A
      const bConvs = await listConversations(b.access);
      expect((bConvs.body.items as ConvRow[]).map((c) => c.id)).not.toContain(
        convA!.id,
      );
      // B não vê a thread de A (404)
      const bThread = await getThread(b.access, convA!.id);
      expect(bThread.status).toBe(404);
      // B não vê notificações de A
      const bNotifs = await listNotifications(b.access);
      expect(bNotifs.body.unread).toBe(0);
      expect((bNotifs.body.items as unknown[]).length).toBe(0);
    });
  });
});
