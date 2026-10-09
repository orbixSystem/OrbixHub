import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import Redis from 'ioredis';
import { gunzipSync } from 'zlib';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';
import { REDIS } from '../src/common/redis/redis.module';
import { MailerService, VerificationEmail } from '../src/common/mailer/mailer.service';
import { gzipB64, NfseHttp, NfseHttpResponse } from '../src/modules/invoice/fiscal/govbr/nfse-http';
import { makeTestPfx } from '../src/modules/invoice/fiscal/govbr/test-a1';
import { randomCnpj } from './helpers/cnpj';

/**
 * NFS-e Nacional (FISCAL_PROVIDER=govbr) de ponta a ponta contra o banco real:
 * cofre de certificado (RLS + cifra), prontidão, numeração da DPS, emissão,
 * download e cancelamento. Só a REDE é falsa — o NfseHttp é trocado por uma
 * "Sefin" em memória que registra o que recebeu.
 */

// Env lido quando o AppModule compila — setado antes, restaurado no fim.
const savedEnv = { ...process.env };
process.env.FISCAL_PROVIDER = 'govbr';
process.env.FISCAL_CERT_KEY = Buffer.alloc(32, 9).toString('base64');
process.env.CATALOG_ENABLED = 'false';
process.env.CATALOG_PROVIDER = 'noop';
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { AppModule } = require('../src/app.module') as typeof import('../src/app.module');

class CapturingMailer extends MailerService {
  public readonly sent: VerificationEmail[] = [];
  async send(email: VerificationEmail): Promise<void> {
    this.sent.push(email);
  }
  async sendMessage(): Promise<void> {}
}

/** "Sefin" em memória: autoriza toda DPS, numera em sequência, aceita eventos. */
class FakeSefin {
  readonly dps: string[] = [];
  readonly events: string[] = [];
  private seq = 1000;

  baseUrl(service: 'sefin' | 'adn', environment: string): string {
    return `https://${service}.${environment}.test`;
  }

  async request(method: string, url: string, _cert: unknown, body?: unknown): Promise<NfseHttpResponse> {
    const json = (status: number, b: unknown): NfseHttpResponse => ({
      status,
      contentType: 'application/json',
      body: Buffer.from(JSON.stringify(b)),
    });
    if (method === 'POST' && url.endsWith('/nfse')) {
      const xml = gunzipSync(Buffer.from((body as { dpsXmlGZipB64: string }).dpsXmlGZipB64, 'base64')).toString();
      this.dps.push(xml);
      const n = ++this.seq;
      // Chave única de verdade: o banco do e2e persiste entre execuções e
      // `invoice.external_id` é único global.
      const chave = Array.from({ length: 50 }, () => Math.floor(Math.random() * 10)).join('');
      return json(201, {
        chaveAcesso: chave,
        nfseXmlGZipB64: gzipB64(`<NFSe><infNFSe><nNFSe>${n}</nNFSe></infNFSe></NFSe>`),
      });
    }
    if (method === 'POST' && url.endsWith('/eventos')) {
      const b = body as { pedidoRegistroEventoXmlGZipB64: string };
      this.events.push(gunzipSync(Buffer.from(b.pedidoRegistroEventoXmlGZipB64, 'base64')).toString());
      return json(201, {});
    }
    if (method === 'GET' && url.includes('/danfse/')) {
      return { status: 200, contentType: 'application/pdf', body: Buffer.from('%PDF-1.4 fake') };
    }
    return json(404, {});
  }
}

interface Owner {
  access: string;
  cnpj: string;
}

describe('Invoice — NFS-e Nacional / govbr (e2e)', () => {
  let app: INestApplication;
  let redis: Redis;
  const sefin = new FakeSefin();
  const uniq = () => Math.random().toString(36).slice(2, 8);
  const srv = () => app.getHttpServer();
  const auth = (access: string) => ({ Authorization: `Bearer ${access}` });

  beforeAll(async () => {
    const mod = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(MailerService)
      .useValue(new CapturingMailer())
      .overrideProvider(NfseHttp)
      .useValue(sefin)
      .compile();
    app = mod.createNestApplication();
    app.setGlobalPrefix('api');
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
    app.useGlobalFilters(new AllExceptionsFilter());
    await app.init();
    redis = app.get<Redis>(REDIS);
  });

  beforeEach(async () => {
    await redis.flushall();
  });

  afterAll(async () => {
    await app?.close();
    process.env = savedEnv;
  });

  // ---- helpers ----------------------------------------------------------
  async function registerOwner(): Promise<Owner> {
    const cnpj = randomCnpj();
    const reg = await request(srv())
      .post('/api/auth/register')
      .send({
        tenantName: `Oficina ${uniq()}`,
        cnpj,
        legalName: 'Oficina Teste LTDA',
        slug: `t-${uniq()}`,
        fullName: 'Owner',
        email: `${uniq()}@ex.com`,
        password: 'supersecret1',
      });
    expect(reg.status).toBe(201);
    return { access: reg.body.accessToken as string, cnpj };
  }

  const getConfig = (o: Owner) => request(srv()).get('/api/invoices/config').set(auth(o.access));

  function uploadCert(o: Owner, pfx: Buffer, password = 'senha123') {
    return request(srv())
      .post('/api/invoices/config/certificate')
      .set(auth(o.access))
      .field('password', password)
      .attach('file', pfx, 'empresa.pfx');
  }

  /** Empresa + config + certificado: tudo que a NFS-e exige. */
  async function makeReady(o: Owner): Promise<void> {
    const company = await request(srv())
      .patch('/api/settings/company')
      .set(auth(o.access))
      .send({ regimeTributario: 'simples', codigoIbge: '3550308', email: 'oficina@ex.com' });
    expect(company.status).toBe(200);
    const cfg = await request(srv())
      .patch('/api/invoices/config')
      .set(auth(o.access))
      .send({ codigoServicoNacional: '140101', codigoNbs: '120012200' });
    expect(cfg.status).toBe(200);
    const up = await uploadCert(o, makeTestPfx({ cnpj: o.cnpj }));
    expect(up.status).toBe(200);
  }

  async function orderWithItems(o: Owner, items: Array<Record<string, unknown>>): Promise<string> {
    const cust = await request(srv())
      .post('/api/customers')
      .set(auth(o.access))
      .send({ name: `Cliente ${uniq()}`, phone: '11999999999' });
    expect(cust.status).toBe(201);
    const order = await request(srv()).post('/api/os/orders').set(auth(o.access)).send({ customerId: cust.body.id });
    expect(order.status).toBe(201);
    for (const it of items) {
      const r = await request(srv()).post(`/api/os/orders/${order.body.id}/items`).set(auth(o.access)).send(it);
      expect(r.status).toBe(201);
    }
    return order.body.id as string;
  }

  const issue = (o: Owner, orderId: string) =>
    request(srv()).post('/api/invoices').set(auth(o.access)).send({ orderId });

  // ---- 1. prontidão ------------------------------------------------------
  it('config informa provedor govbr e lista o que falta para emitir', async () => {
    const o = await registerOwner();
    const res = await getConfig(o);
    expect(res.status).toBe(200);
    expect(res.body.provider).toBe('govbr');
    expect(res.body.pendencias).toEqual(
      expect.arrayContaining([
        'regime tributário (Configurações › Empresa)',
        'código IBGE do município — busque o CEP em Configurações › Empresa',
        'código de tributação nacional do serviço',
        'código NBS do serviço',
        'certificado digital A1 da empresa',
      ]),
    );
    // o CNPJ do cadastro já basta
    expect(res.body.pendencias).not.toContain('CNPJ da empresa (Configurações › Empresa)');
  });

  it('com pendência, emitir é recusado com a lista (e o fisco não é chamado)', async () => {
    const o = await registerOwner();
    const orderId = await orderWithItems(o, [{ kind: 'service', name: 'Mão de obra', quantity: 1, unitPrice: 100 }]);
    const before = sefin.dps.length;
    const res = await issue(o, orderId);
    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/^Antes de emitir, complete: .*certificado digital A1/);
    expect(sefin.dps.length).toBe(before);
  });

  // ---- 2. cofre do certificado -------------------------------------------
  describe('certificado', () => {
    it('recusa certificado de outro CNPJ, senha errada e arquivo inválido', async () => {
      const o = await registerOwner();
      const outro = await uploadCert(o, makeTestPfx({ cnpj: '11222333000181' }));
      expect(outro.status).toBe(400);
      expect(outro.body.message).toMatch(/certificado é do CNPJ 11\.222\.333\/0001-81/);

      const senha = await uploadCert(o, makeTestPfx({ cnpj: o.cnpj }), 'errada');
      expect(senha.status).toBe(400);
      expect(senha.body.message).toMatch(/Confira o arquivo .pfx e a senha/);

      const vencido = await uploadCert(
        o,
        makeTestPfx({ cnpj: o.cnpj, notBefore: new Date('2020-01-01'), notAfter: new Date('2021-01-01') }),
      );
      expect(vencido.status).toBe(400);
      expect(vencido.body.message).toMatch(/vencido/);
    });

    it('guarda o certificado do tenant A sem vazar para o tenant B', async () => {
      const a = await registerOwner();
      const b = await registerOwner();
      const up = await uploadCert(a, makeTestPfx({ cnpj: a.cnpj }));
      expect(up.status).toBe(200);
      expect(up.body.certificado.validoAte).toBeTruthy();
      expect(up.body.pendencias).not.toContain('certificado digital A1 da empresa');

      const cfgB = await getConfig(b);
      expect(cfgB.body.certificado.validoAte).toBeNull();
      expect(cfgB.body.pendencias).toContain('certificado digital A1 da empresa');
    });

    it('cadastro em provedor não existe no fluxo govbr', async () => {
      const o = await registerOwner();
      const res = await request(srv()).post('/api/invoices/config/register-empresa').set(auth(o.access)).send({});
      expect(res.status).toBe(400);
    });
  });

  // ---- 3. emissão ponta a ponta -----------------------------------------
  it('emite NFS-e só dos serviços, numera a DPS em sequência, baixa XML/PDF e cancela', async () => {
    const o = await registerOwner();
    await makeReady(o);
    expect((await getConfig(o)).body.pendencias).toEqual([]);

    const orderId = await orderWithItems(o, [
      { kind: 'service', name: 'Troca de óleo', quantity: 1, unitPrice: 80 },
      { kind: 'product', name: 'Filtro de óleo', quantity: 1, unitPrice: 40 },
    ]);
    const res = await issue(o, orderId);
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({ status: 'authorized', environment: 'homologacao', dps_series: '1', dps_number: 1 });
    expect(res.body).not.toHaveProperty('nfse_xml');
    expect(res.body.total_amount).toBe('80');
    expect(res.body.lines.map((l: { kind: string }) => l.kind)).toEqual(['service']);

    const sent = sefin.dps[sefin.dps.length - 1];
    expect(sent).toContain(`<CNPJ>${o.cnpj}</CNPJ>`);
    expect(sent).toContain('<tpAmb>2</tpAmb>');
    expect(sent).toContain('<nDPS>1</nDPS>');
    expect(sent).toContain('<vServ>80.00</vServ>');
    expect(sent).not.toContain('Filtro');
    expect(sent).toContain('<Signature xmlns="http://www.w3.org/2000/09/xmldsig#">');

    // segunda nota do mesmo tenant → próximo número
    const order2 = await orderWithItems(o, [{ kind: 'service', name: 'Alinhamento', quantity: 1, unitPrice: 50 }]);
    const res2 = await issue(o, order2);
    expect(res2.status).toBe(201);
    expect(res2.body.dps_number).toBe(2);

    const xml = await request(srv()).get(`/api/invoices/${res.body.id}/xml`).set(auth(o.access));
    expect(xml.status).toBe(200);
    expect(xml.headers['content-type']).toMatch(/xml/);
    expect(xml.text).toContain('<nNFSe>');

    const pdf = await request(srv()).get(`/api/invoices/${res.body.id}/pdf`).set(auth(o.access)).buffer(true);
    expect(pdf.status).toBe(200);
    expect(pdf.headers['content-type']).toBe('application/pdf');

    const curto = await request(srv())
      .post(`/api/invoices/${res.body.id}/cancel`)
      .set(auth(o.access))
      .send({ reason: 'erro' });
    expect(curto.status).toBe(400);

    const cancel = await request(srv())
      .post(`/api/invoices/${res.body.id}/cancel`)
      .set(auth(o.access))
      .send({ reason: 'Valor do serviço lançado errado' });
    expect(cancel.status).toBe(200);
    expect(cancel.body.status).toBe('canceled');
    expect(sefin.events[sefin.events.length - 1]).toContain(`<CNPJAutor>${o.cnpj}</CNPJAutor>`);
  });

  it('numeração da DPS é por tenant (outro tenant começa do 1)', async () => {
    const a = await registerOwner();
    const b = await registerOwner();
    await makeReady(a);
    await makeReady(b);
    const ra = await issue(a, await orderWithItems(a, [{ kind: 'service', name: 'S', quantity: 1, unitPrice: 10 }]));
    const rb = await issue(b, await orderWithItems(b, [{ kind: 'service', name: 'S', quantity: 1, unitPrice: 10 }]));
    expect(ra.body.dps_number).toBe(1);
    expect(rb.body.dps_number).toBe(1);
    // B não enxerga a nota de A
    const other = await request(srv()).get(`/api/invoices/${ra.body.id}/xml`).set(auth(b.access));
    expect(other.status).toBe(404);
  });
});
