import {
  BadRequestException,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { InvoiceCertificateService } from '../../invoice-certificate.service';
import type {
  FiscalCancelParams,
  FiscalCancelResult,
  FiscalEnvironment,
  FiscalGateway,
  FiscalIssueParams,
  FiscalIssueResult,
  FiscalIssuer,
} from '../fiscal-gateway';
import type { A1Certificate } from './a1-certificate';
import {
  buildCancelamentoXml,
  buildDpsXml,
  OpcaoSimplesNacional,
  TipoAmbiente,
} from './dps-xml';
import { gunzipB64, gzipB64, NfseHttp, NfseHttpResponse, NfseTransportError } from './nfse-http';
import { signFiscalXml } from './xml-signer';

const VER_APLIC = 'OrbixHub-1.0';
/** Margem contra relógio adiantado: a Sefin rejeita DPS com data/hora no futuro. */
const CLOCK_SKEW_MS = 60_000;

/**
 * Emissão DIRETA na NFS-e Nacional (Sefin Nacional / gov.br) — sem provedor
 * intermediário, sem custo por nota. Fluxo: monta a DPS → assina com o A1 do
 * tenant → gzip+base64 → POST /nfse (mTLS com o mesmo A1). A resposta é
 * SÍNCRONA: autorizada (chave de acesso + XML da NFS-e) ou rejeitada (lista de
 * erros). Não há webhook neste fluxo.
 *
 * Só emite NFS-e (serviço). NFC-e/NF-e (produto) vão para a Sefaz de cada UF —
 * fora do escopo deste gateway.
 */
@Injectable()
export class GovBrNfseGateway implements FiscalGateway {
  private readonly logger = new Logger(GovBrNfseGateway.name);

  constructor(
    private readonly http: NfseHttp,
    private readonly certificates: InvoiceCertificateService,
  ) {}

  async issue(params: FiscalIssueParams): Promise<FiscalIssueResult> {
    if (params.documentType !== 'nfse') {
      throw new BadRequestException('Por enquanto só emitimos NFS-e (nota de serviço).');
    }
    const issuer = params.issuer;
    if (!issuer) throw new Error('GovBrNfseGateway.issue sem dados do emitente');
    const cert = await this.certificates.load();
    const cnpj = requireValue(issuer.cnpj, 'CNPJ da empresa');

    const now = new Date(Date.now() - CLOCK_SKEW_MS);
    const { xml, id } = buildDpsXml({
      tpAmb: tpAmb(params.environment),
      dhEmi: now,
      verAplic: VER_APLIC,
      serie: issuer.dps.serie,
      nDPS: issuer.dps.numero,
      dCompet: now,
      cLocEmi: requireValue(issuer.codigoMunicipio, 'código IBGE do município'),
      prestador: {
        cnpj,
        opSimpNac: opSimpNac(issuer.regimeTributario),
        regApTribSN: '1',
        regEspTrib: '0',
        fone: issuer.fone,
        email: issuer.email,
      },
      tomador: tomador(params.customer),
      servico: {
        cLocPrestacao: requireValue(issuer.codigoMunicipio, 'código IBGE do município'),
        cTribNac: requireValue(issuer.servico.codigoNacional, 'código de tributação nacional do serviço'),
        cNBS: requireValue(issuer.servico.codigoNbs, 'código NBS do serviço'),
        descricao: describe(issuer, params),
      },
      valores: {
        vServ: params.serviceAmount,
        pAliq: issuer.servico.aliquotaIss,
        pTotTribSN: issuer.servico.percentualTributosSimples,
      },
    });
    const signed = '<?xml version="1.0" encoding="UTF-8"?>' + signFiscalXml(xml, 'infDPS', cert);
    const base = this.http.baseUrl('sefin', params.environment);

    let res: NfseHttpResponse;
    try {
      res = await this.http.request('POST', `${base}/nfse`, cert, { dpsXmlGZipB64: gzipB64(signed) });
    } catch (e) {
      if (!(e instanceof NfseTransportError)) throw e;
      // A conexão caiu DEPOIS de enviar? A Sefin pode ter gerado a nota — perguntar
      // pelo Id da DPS antes de dar como falha (senão o retry emite em duplicidade).
      this.logger.warn(`Falha de transporte emitindo DPS ${id}: ${e.message} — consultando a DPS`);
      const recovered = await this.recoverByDps(base, id, issuer, cert);
      if (recovered) return recovered;
      throw e;
    }

    const body = parseJson(res);
    const chave = pick(body, 'chaveAcesso');
    const nfseB64 = pick(body, 'nfseXmlGZipB64');
    if (res.status >= 200 && res.status < 300 && chave) {
      return authorized(chave, issuer, nfseB64 ? gunzipB64(nfseB64) : null);
    }
    if (res.status >= 500) {
      const recovered = await this.recoverByDps(base, id, issuer, cert);
      if (recovered) return recovered;
      this.logger.error(`Sefin ${res.status} na DPS ${id}: ${res.body.toString('utf8').slice(0, 500)}`);
      throw new ServiceUnavailableException('O sistema da NFS-e Nacional está indisponível. Tente novamente.');
    }
    return {
      externalId: id,
      status: 'rejected',
      number: null,
      series: issuer.dps.serie,
      accessKey: null,
      pdfUrl: null,
      xmlUrl: null,
      rejectionReason: errorMessage(body, res),
      documentXml: null,
    };
  }

  async cancel(params: FiscalCancelParams): Promise<FiscalCancelResult> {
    const reason = params.reason.trim();
    if (reason.length < 15) {
      throw new BadRequestException('Descreva o motivo do cancelamento com pelo menos 15 caracteres.');
    }
    const environment = params.environment ?? 'homologacao';
    const cert = await this.certificates.load();
    const { xml } = buildCancelamentoXml({
      tpAmb: tpAmb(environment),
      verAplic: VER_APLIC,
      dhEvento: new Date(Date.now() - CLOCK_SKEW_MS),
      cnpjAutor: requireValue(params.issuerCnpj ?? null, 'CNPJ da empresa'),
      chNFSe: params.externalId,
      cMotivo: '9',
      xMotivo: reason,
    });
    const signed = '<?xml version="1.0" encoding="UTF-8"?>' + signFiscalXml(xml, 'infPedReg', cert);
    const base = this.http.baseUrl('sefin', environment);
    const res = await this.http.request('POST', `${base}/nfse/${params.externalId}/eventos`, cert, {
      pedidoRegistroEventoXmlGZipB64: gzipB64(signed),
    });
    if (res.status >= 200 && res.status < 300) return { status: 'canceled', rejectionReason: null };
    if (res.status >= 500) {
      throw new ServiceUnavailableException('O sistema da NFS-e Nacional está indisponível. Tente novamente.');
    }
    return { status: 'rejected', rejectionReason: errorMessage(parseJson(res), res) };
  }

  /** Não há webhook na NFS-e Nacional (resposta síncrona) — qualquer chamada é recusada. */
  verifySignature(): boolean {
    return false;
  }

  async downloadPdf(params: { environment: FiscalEnvironment; accessKey: string }): Promise<Buffer> {
    const cert = await this.certificates.load();
    const base = this.http.baseUrl('adn', params.environment);
    const res = await this.http.request('GET', `${base}/danfse/${params.accessKey}`, cert);
    if (res.status === 200 && res.body.length > 0) return res.body;
    this.logger.error(`DANFSe ${params.accessKey} → ${res.status}`);
    throw new ServiceUnavailableException('Não foi possível obter o PDF da nota agora. Tente novamente.');
  }

  /** Consulta GET /dps/{id}: se a nota existe, busca o XML e devolve como autorizada. */
  private async recoverByDps(
    base: string,
    dpsId: string,
    issuer: FiscalIssuer,
    cert: A1Certificate,
  ): Promise<FiscalIssueResult | null> {
    try {
      const dps = await this.http.request('GET', `${base}/dps/${dpsId}`, cert);
      const chave = dps.status === 200 ? pick(parseJson(dps), 'chaveAcesso') : null;
      if (!chave) return null;
      const nfse = await this.http.request('GET', `${base}/nfse/${chave}`, cert);
      const b64 = nfse.status === 200 ? pick(parseJson(nfse), 'nfseXmlGZipB64') : null;
      this.logger.log(`DPS ${dpsId} recuperada após falha de transporte → NFS-e ${chave}`);
      return authorized(chave, issuer, b64 ? gunzipB64(b64) : null);
    } catch (e) {
      this.logger.warn(`Consulta de recuperação da DPS ${dpsId} falhou: ${String(e)}`);
      return null;
    }
  }
}

// ---------------------------------------------------------------------------

function authorized(chave: string, issuer: FiscalIssuer, nfseXml: string | null): FiscalIssueResult {
  return {
    externalId: chave,
    status: 'authorized',
    number: nfseXml ? (/<nNFSe>(\d+)<\/nNFSe>/.exec(nfseXml)?.[1] ?? null) : null,
    series: issuer.dps.serie,
    accessKey: chave,
    // O PDF (DANFSe) e o XML exigem o certificado para baixar — servidos pelo
    // backend (GET /invoices/:id/pdf|xml), não por URL pública.
    pdfUrl: null,
    xmlUrl: null,
    rejectionReason: null,
    documentXml: nfseXml,
  };
}

function tpAmb(env: FiscalEnvironment): TipoAmbiente {
  return env === 'producao' ? '1' : '2';
}

/** Regime do núcleo → situação no Simples Nacional do leiaute. */
export function opSimpNac(regime: string | null): OpcaoSimplesNacional {
  if (regime === 'simples') return '3';
  if (regime === 'mei') return '2';
  if (regime === 'presumido' || regime === 'real') return '1';
  throw new BadRequestException('Informe o regime tributário da empresa em Configurações › Empresa.');
}

function tomador(c: { name: string | null; document: string | null }): { documento: string; nome: string } | null {
  const doc = (c.document ?? '').replace(/\D/g, '');
  if (doc.length !== 11 && doc.length !== 14) return null; // sem documento válido = tomador não identificado
  return { documento: doc, nome: c.name?.trim() || 'Consumidor' };
}

function describe(issuer: FiscalIssuer, p: FiscalIssueParams): string {
  const items = p.lines
    .filter((l) => l.kind === 'service')
    .map((l) => (l.quantity > 1 ? `${l.name} (${formatQty(l.quantity)}x)` : l.name));
  return `${issuer.reference}: ${items.join('; ')}`;
}

function formatQty(q: number): string {
  return Number.isInteger(q) ? String(q) : q.toFixed(2).replace('.', ',');
}

function requireValue(v: string | null, label: string): string {
  if (!v) throw new BadRequestException(`Falta configurar: ${label}.`);
  return v;
}

function parseJson(res: NfseHttpResponse): Record<string, unknown> {
  try {
    const v: unknown = JSON.parse(res.body.toString('utf8'));
    return v && typeof v === 'object' ? (v as Record<string, unknown>) : {};
  } catch {
    return {};
  }
}

/** Lê um campo ignorando caixa (a API mistura `chaveAcesso`/`ChaveAcesso`). */
function pick(obj: Record<string, unknown>, key: string): string | null {
  const k = Object.keys(obj).find((x) => x.toLowerCase() === key.toLowerCase());
  const v = k ? obj[k] : undefined;
  return typeof v === 'string' && v ? v : null;
}

/** "E0312: descrição (complemento)" — junta todos os erros que a Sefin devolveu. */
export function errorMessage(body: Record<string, unknown>, res: NfseHttpResponse): string {
  const key = Object.keys(body).find((k) => k.toLowerCase() === 'erros' || k.toLowerCase() === 'erro');
  const raw = key ? body[key] : undefined;
  let list: Array<Record<string, unknown>> = [];
  if (Array.isArray(raw)) list = raw as Array<Record<string, unknown>>;
  else if (raw && typeof raw === 'object') list = [raw as Record<string, unknown>];
  const parts = list
    .map((e) => {
      const code = pick(e, 'codigo');
      const desc = pick(e, 'descricao') ?? pick(e, 'mensagem');
      const extra = pick(e, 'complemento');
      return [code ? `${code}:` : '', desc ?? '', extra ? `(${extra})` : ''].filter(Boolean).join(' ');
    })
    .filter(Boolean);
  if (parts.length) return parts.join(' | ').slice(0, 1000);
  return `Rejeitada pela NFS-e Nacional (HTTP ${res.status}).`;
}
