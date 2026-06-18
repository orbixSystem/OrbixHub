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
import {
  STORAGE_PROVIDER,
  StorageProvider,
} from '../src/common/storage/storage.provider';

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

describe('OS — Acompanhamento público (e2e)', () => {
  let app: INestApplication;
  let redis: Redis;

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
  function addNote(access: string, id: string, body: Record<string, unknown>) {
    return request(srv())
      .post(`/api/os/orders/${id}/notes`)
      .set(auth(access))
      .send(body);
  }
  // Sem header de Authorization — fluxo público.
  function getTrack(token: string) {
    return request(srv()).get(`/api/public/track/${token}`);
  }
  function getPublicMessages(token: string) {
    return request(srv()).get(`/api/public/track/${token}/messages`);
  }
  function postPublicMessage(token: string, body: Record<string, unknown>) {
    return request(srv()).post(`/api/public/track/${token}/messages`).send(body);
  }
  function listConversations(access: string) {
    return request(srv()).get('/api/messages/conversations').set(auth(access));
  }
  function listNotifications(access: string) {
    return request(srv()).get('/api/notifications').set(auth(access));
  }

  async function newOrder(o: Owner): Promise<{ id: string; token: string }> {
    const customerId = await createCustomer(o.access);
    const created = await createOrder(o.access, {
      customerId,
      complaint: 'Barulho na frente',
    });
    expect(created.status).toBe(201);
    expect(created.body.public_token).toBeTruthy();
    return {
      id: created.body.id as string,
      token: created.body.public_token as string,
    };
  }

  type TimelineRow = {
    kind: string;
    message: string | null;
    statusSnapshot: string | null;
    createdAt: string;
  };

  // ---- 1. public track payload (no auth) -------------------------------
  describe('GET /public/track/:token (sem auth)', () => {
    it('retorna status/number/timeline com o evento created (visible_public)', async () => {
      const o = await registerOwner();
      const { token } = await newOrder(o);

      const res = await getTrack(token);
      expect(res.status).toBe(200);
      expect(res.body.number).toMatch(/^OS-\d{4}$/);
      expect(res.body.status).toBe('aberta');
      expect(res.body.statusLabel).toBeTruthy();
      expect(Array.isArray(res.body.timeline)).toBe(true);
      const timeline = res.body.timeline as TimelineRow[];
      expect(timeline.some((e) => e.kind === 'created')).toBe(true);

      // payload público NÃO expõe preços/diagnóstico/itens/total/cliente
      expect(res.body.items).toBeUndefined();
      expect(res.body.total).toBeUndefined();
      expect(res.body.diagnosis).toBeUndefined();
      expect(res.body.complaint).toBeUndefined();
      expect(res.body.customer_name).toBeUndefined();
    });

    it('nota interna (visiblePublic=false) NÃO aparece; nota pública aparece', async () => {
      const o = await registerOwner();
      const { id, token } = await newOrder(o);

      const internal = await addNote(o.access, id, {
        message: 'Nota interna secreta',
      });
      expect(internal.status).toBe(201);
      const visible = await addNote(o.access, id, {
        message: 'Atualização para o cliente',
        visiblePublic: true,
      });
      expect(visible.status).toBe(201);

      const res = await getTrack(token);
      expect(res.status).toBe(200);
      const messages = (res.body.timeline as TimelineRow[]).map((e) => e.message);
      expect(messages).toContain('Atualização para o cliente');
      expect(messages).not.toContain('Nota interna secreta');
    });

    it('token inválido → 404', async () => {
      const res = await getTrack('00000000-0000-0000-0000-000000000000');
      expect(res.status).toBe(404);
    });
  });

  // ---- 2. public chat (customer side, no auth) -------------------------
  describe('chat público do cliente', () => {
    it('POST mensagem do cliente → aparece como customer; incrementa staff_unread + notificação', async () => {
      const o = await registerOwner();
      const { token } = await newOrder(o);

      const posted = await postPublicMessage(token, {
        body: 'Oi, alguma novidade?',
      });
      expect([200, 201]).toContain(posted.status);
      expect(posted.body.sender).toBe('customer');

      // GET público mostra a mensagem como sender 'customer'
      const msgs = await getPublicMessages(token);
      expect(msgs.status).toBe(200);
      const list = msgs.body as Array<{ sender: string; body: string }>;
      expect(
        list.some(
          (m) => m.sender === 'customer' && m.body === 'Oi, alguma novidade?',
        ),
      ).toBe(true);

      // staff vê staff_unread incrementado no inbox
      const convs = await listConversations(o.access);
      expect(convs.status).toBe(200);
      const conv = (convs.body as Array<{
        ref_type: string;
        staff_unread: number;
      }>).find((c) => c.ref_type === 'os');
      expect(conv).toBeTruthy();
      expect(conv!.staff_unread).toBeGreaterThanOrEqual(1);

      // e existe uma notificação tenant-wide
      const notifs = await listNotifications(o.access);
      expect(notifs.status).toBe(200);
      expect(notifs.body.unread).toBeGreaterThanOrEqual(1);
      const n = (notifs.body.items as Array<{ type: string }>).find(
        (x) => x.type === 'message',
      );
      expect(n).toBeTruthy();
    });

    it('POST body vazio → 400', async () => {
      const o = await registerOwner();
      const { token } = await newOrder(o);
      const res = await postPublicMessage(token, { body: '' });
      expect(res.status).toBe(400);
    });

    it('POST com token inválido → 404', async () => {
      const res = await postPublicMessage(
        '00000000-0000-0000-0000-000000000000',
        { body: 'oi' },
      );
      expect(res.status).toBe(404);
    });
  });
});
