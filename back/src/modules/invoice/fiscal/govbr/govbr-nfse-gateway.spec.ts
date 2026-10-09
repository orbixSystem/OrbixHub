import { BadRequestException, ServiceUnavailableException } from '@nestjs/common';
import { gunzipSync } from 'zlib';
import type { InvoiceCertificateService } from '../../invoice-certificate.service';
import type { FiscalIssueParams } from '../fiscal-gateway';
import { parseA1 } from './a1-certificate';
import { errorMessage, GovBrNfseGateway, opSimpNac } from './govbr-nfse-gateway';
import { gzipB64, NfseHttp, NfseHttpResponse, NfseTransportError } from './nfse-http';
import { makeTestPfx } from './test-a1';

const cert = parseA1(makeTestPfx({ cnpj: '12345678000199' }), 'senha123');
const CHAVE = '35503082123456780001990000000000000000000000000001'.slice(0, 50);

const json = (status: number, body: unknown): NfseHttpResponse => ({
  status,
  contentType: 'application/json',
  body: Buffer.from(JSON.stringify(body)),
});

const params = (over: Partial<FiscalIssueParams> = {}): FiscalIssueParams => ({
  tenantId: 't1',
  invoiceId: 'inv1',
  documentType: 'nfse',
  environment: 'homologacao',
  customer: { name: 'Fulano', document: '123.456.789-09' },
  lines: [
    { kind: 'service', name: 'Troca de óleo', quantity: 1, unitPrice: 80, total: 80 },
    { kind: 'service', name: 'Alinhamento', quantity: 2, unitPrice: 35, total: 70 },
  ],
  serviceAmount: 150,
  productAmount: 0,
  totalAmount: 150,
  issuer: {
    cnpj: '12345678000199',
    regimeTributario: 'simples',
    codigoMunicipio: '3550308',
    fone: null,
    email: null,
    dps: { serie: '1', numero: 7 },
    servico: { codigoNacional: '140101', codigoNbs: '120012200', aliquotaIss: null, percentualTributosSimples: null },
    reference: 'OS 123',
  },
  ...over,
});

const build = (responder: (method: string, url: string, body: unknown) => NfseHttpResponse | Error) => {
  const calls: Array<{ method: string; url: string; body: unknown }> = [];
  const http = {
    baseUrl: (svc: string) => (svc === 'sefin' ? 'https://sefin.test/SefinNacional' : 'https://adn.test'),
    request: jest.fn(async (method: string, url: string, _cert: unknown, body?: unknown) => {
      calls.push({ method, url, body });
      const r = responder(method, url, body);
      if (r instanceof Error) throw r;
      return r;
    }),
  } as unknown as NfseHttp;
  const certificates = { load: jest.fn().mockResolvedValue(cert) } as unknown as InvoiceCertificateService;
  return { gw: new GovBrNfseGateway(http, certificates), calls };
};

const sentDps = (body: unknown): string =>
  gunzipSync(Buffer.from((body as { dpsXmlGZipB64: string }).dpsXmlGZipB64, 'base64')).toString('utf8');

describe('GovBrNfseGateway.issue', () => {
  it('autorizada: POST /nfse com DPS assinada; devolve chave, número da NFS-e e XML', async () => {
    const nfseXml = '<NFSe><infNFSe><nNFSe>1234</nNFSe></infNFSe></NFSe>';
    const { gw, calls } = build(() =>
      json(201, { chaveAcesso: CHAVE, idDps: 'x', nfseXmlGZipB64: gzipB64(nfseXml) }),
    );

    const r = await gw.issue(params());

    expect(calls[0].method).toBe('POST');
    expect(calls[0].url).toBe('https://sefin.test/SefinNacional/nfse');
    const dps = sentDps(calls[0].body);
    expect(dps.startsWith('<?xml version="1.0" encoding="UTF-8"?><DPS')).toBe(true);
    expect(dps).toContain('<tpAmb>2</tpAmb>');
    expect(dps).toContain('<nDPS>7</nDPS>');
    expect(dps).toContain('<xDescServ>OS 123: Troca de óleo; Alinhamento (2x)</xDescServ>');
    expect(dps).toContain('<vServ>150.00</vServ>');
    expect(dps).toContain('<Signature xmlns="http://www.w3.org/2000/09/xmldsig#">');
    expect(r).toMatchObject({
      status: 'authorized',
      externalId: CHAVE,
      accessKey: CHAVE,
      number: '1234',
      series: '1',
      documentXml: nfseXml,
    });
  });

  it('rejeitada: junta os erros da Sefin numa mensagem legível', async () => {
    const { gw } = build(() =>
      json(400, { erros: [{ Codigo: 'E0312', Descricao: 'Código de tributação inválido', Complemento: 'cTribNac' }] }),
    );
    const r = await gw.issue(params());
    expect(r.status).toBe('rejected');
    expect(r.rejectionReason).toBe('E0312: Código de tributação inválido (cTribNac)');
    expect(r.externalId).toMatch(/^DPS\d{42}$/);
  });

  it('queda de conexão: consulta a DPS e recupera a nota se a Sefin gerou', async () => {
    const nfseXml = '<NFSe><nNFSe>99</nNFSe></NFSe>';
    const { gw, calls } = build((method, url) => {
      if (method === 'POST') return new NfseTransportError('socket hang up');
      if (url.includes('/dps/')) return json(200, { chaveAcesso: CHAVE });
      return json(200, { nfseXmlGZipB64: gzipB64(nfseXml) });
    });
    const r = await gw.issue(params());
    expect(calls.map((c) => c.method + ' ' + c.url.replace('https://sefin.test/SefinNacional', ''))).toEqual([
      'POST /nfse',
      expect.stringMatching(/^GET \/dps\/DPS\d{42}$/),
      `GET /nfse/${CHAVE}`,
    ]);
    expect(r).toMatchObject({ status: 'authorized', accessKey: CHAVE, number: '99' });
  });

  it('queda de conexão sem nota gerada: propaga a falha (o service marca erro)', async () => {
    const { gw } = build((method) => (method === 'POST' ? new NfseTransportError('timeout') : json(404, {})));
    await expect(gw.issue(params())).rejects.toBeInstanceOf(NfseTransportError);
  });

  it('Sefin fora do ar (5xx) e DPS inexistente → 503 para o usuário', async () => {
    const { gw } = build((method) => (method === 'POST' ? json(503, {}) : json(404, {})));
    await expect(gw.issue(params())).rejects.toBeInstanceOf(ServiceUnavailableException);
  });

  it('produção vai com tpAmb 1; nota de produto é recusada', async () => {
    const { gw, calls } = build(() => json(201, { chaveAcesso: CHAVE }));
    await gw.issue(params({ environment: 'producao' }));
    expect(sentDps(calls[0].body)).toContain('<tpAmb>1</tpAmb>');
    await expect(gw.issue(params({ documentType: 'nfce' }))).rejects.toBeInstanceOf(BadRequestException);
  });

  it('config faltando vira mensagem clara (sem chamar o fisco)', async () => {
    const { gw, calls } = build(() => json(201, {}));
    const p = params();
    p.issuer!.servico.codigoNbs = null;
    await expect(gw.issue(p)).rejects.toThrow('Falta configurar: código NBS do serviço.');
    expect(calls).toHaveLength(0);
  });
});

describe('GovBrNfseGateway.cancel', () => {
  it('envia o evento 101101 assinado para /nfse/{chave}/eventos', async () => {
    const { gw, calls } = build(() => json(201, { eventoXmlGZipB64: 'x' }));
    const r = await gw.cancel({
      tenantId: 't1',
      invoiceId: 'inv1',
      externalId: CHAVE,
      reason: 'Valor lançado errado na OS',
      environment: 'homologacao',
      issuerCnpj: '12345678000199',
    });
    expect(r).toEqual({ status: 'canceled', rejectionReason: null });
    expect(calls[0].url).toBe(`https://sefin.test/SefinNacional/nfse/${CHAVE}/eventos`);
    const xml = gunzipSync(
      Buffer.from((calls[0].body as { pedidoRegistroEventoXmlGZipB64: string }).pedidoRegistroEventoXmlGZipB64, 'base64'),
    ).toString('utf8');
    expect(xml).toContain(`<infPedReg Id="PRE${CHAVE}101101001">`);
    expect(xml).toContain('<xMotivo>Valor lançado errado na OS</xMotivo>');
  });

  it('motivo curto (leiaute exige 15+) é recusado antes de ir ao fisco', async () => {
    const { gw, calls } = build(() => json(201, {}));
    await expect(
      gw.cancel({ tenantId: 't1', invoiceId: 'i', externalId: CHAVE, reason: 'erro', issuerCnpj: '1' }),
    ).rejects.toThrow(/15 caracteres/);
    expect(calls).toHaveLength(0);
  });

  it('cancelamento recusado pela Sefin volta como rejected com o motivo', async () => {
    const { gw } = build(() => json(400, { erros: [{ codigo: 'E1235', descricao: 'Prazo de cancelamento expirado' }] }));
    const r = await gw.cancel({
      tenantId: 't1', invoiceId: 'i', externalId: CHAVE, reason: 'Serviço não foi prestado', issuerCnpj: '12345678000199',
    });
    expect(r).toEqual({ status: 'rejected', rejectionReason: 'E1235: Prazo de cancelamento expirado' });
  });
});

describe('helpers', () => {
  it('regime do núcleo → opSimpNac', () => {
    expect(opSimpNac('simples')).toBe('3');
    expect(opSimpNac('mei')).toBe('2');
    expect(opSimpNac('presumido')).toBe('1');
    expect(opSimpNac('real')).toBe('1');
    expect(() => opSimpNac(null)).toThrow(BadRequestException);
  });

  it('erro sem corpo reconhecível cai numa mensagem genérica com o HTTP', () => {
    expect(errorMessage({}, json(422, 'x'))).toBe('Rejeitada pela NFS-e Nacional (HTTP 422).');
  });
});
