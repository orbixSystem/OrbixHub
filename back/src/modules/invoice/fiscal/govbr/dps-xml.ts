/**
 * Montagem do XML da DPS (Declaração de Prestação de Serviço) e do pedido de
 * registro de evento de cancelamento — leiaute NFS-e Nacional versão 1.01.
 *
 * Funções PURAS (sem I/O, sem assinatura): recebem dados já validados e devolvem
 * a string XML. A ORDEM dos elementos é a do XSD (xs:sequence) — fora de ordem a
 * Sefin rejeita o schema inteiro. Referência: DPS_v1.01.xsd / tiposComplexos_v1.01.xsd.
 */

export const NFSE_NAMESPACE = 'http://www.sped.fazenda.gov.br/nfse';
export const NFSE_LAYOUT_VERSION = '1.01';

export type TipoAmbiente = '1' | '2'; // 1 = produção, 2 = homologação (produção restrita)
/** 1 = não optante; 2 = MEI; 3 = ME/EPP optante do Simples Nacional. */
export type OpcaoSimplesNacional = '1' | '2' | '3';

export interface DpsData {
  tpAmb: TipoAmbiente;
  dhEmi: Date;
  verAplic: string;
  serie: string;
  nDPS: number;
  /** Data de competência (dia da prestação). */
  dCompet: Date;
  /** Código IBGE (7 dígitos) do município emissor. */
  cLocEmi: string;
  prestador: {
    cnpj: string;
    opSimpNac: OpcaoSimplesNacional;
    /** Só para ME/EPP (opSimpNac = 3). */
    regApTribSN?: '1' | '2' | '3';
    /** 0 = nenhum regime especial. */
    regEspTrib: string;
    fone?: string | null;
    email?: string | null;
  };
  /** Tomador identificado (CPF/CNPJ). Ausente = sem tomador identificado. */
  tomador?: { documento: string; nome: string } | null;
  servico: {
    /** Município IBGE onde o serviço foi prestado. */
    cLocPrestacao: string;
    /** Código de tributação nacional (6 dígitos: item+subitem LC 116 + desdobro). */
    cTribNac: string;
    /** Código NBS (9 dígitos). */
    cNBS: string;
    descricao: string;
  };
  valores: {
    vServ: number;
    /** Alíquota do ISSQN em %, quando o município exige informá-la. */
    pAliq?: number | null;
    /** % aproximado de tributos para optante do Simples (Lei 12.741). */
    pTotTribSN?: number | null;
  };
}

export interface CancelamentoData {
  tpAmb: TipoAmbiente;
  verAplic: string;
  dhEvento: Date;
  cnpjAutor: string;
  chNFSe: string;
  /** 1 = erro na emissão; 2 = serviço não prestado; 9 = outros. */
  cMotivo: '1' | '2' | '9';
  xMotivo: string;
}

/** "DPS" + município(7) + tipo de inscrição(1: 1=CPF, 2=CNPJ) + inscrição(14) + série(5) + número(15). */
export function dpsId(d: Pick<DpsData, 'cLocEmi' | 'serie' | 'nDPS'> & { cnpj: string }): string {
  return (
    'DPS' +
    d.cLocEmi.padStart(7, '0') +
    '2' +
    d.cnpj.padStart(14, '0') +
    d.serie.padStart(5, '0') +
    String(d.nDPS).padStart(15, '0')
  );
}

/** "PRE" + chave da NFS-e(50) + código do evento(6) + nº do pedido(3). */
export function pedRegEventoId(chNFSe: string, codigoEvento: string, nPedRegEvento = 1): string {
  return 'PRE' + chNFSe + codigoEvento + String(nPedRegEvento).padStart(3, '0');
}

export function buildDpsXml(d: DpsData): { xml: string; id: string } {
  const id = dpsId({ cLocEmi: d.cLocEmi, serie: d.serie, nDPS: d.nDPS, cnpj: d.prestador.cnpj });
  const p = d.prestador;

  // Emitente = prestador: nome e endereço do prestador NÃO vão na DPS — a Sefin
  // usa o Cadastro Nacional de Contribuintes (informar dá rejeição).
  const prest =
    tag('CNPJ', p.cnpj) +
    optTag('fone', onlyDigits(p.fone)) +
    optTag('email', p.email) +
    tag(
      'regTrib',
      tag('opSimpNac', p.opSimpNac) +
        (p.opSimpNac === '3' && p.regApTribSN ? tag('regApTribSN', p.regApTribSN) : '') +
        tag('regEspTrib', p.regEspTrib),
    );

  let toma = '';
  if (d.tomador) {
    const doc = onlyDigits(d.tomador.documento);
    const docTag = doc.length === 14 ? tag('CNPJ', doc) : tag('CPF', doc);
    toma = tag('toma', docTag + tag('xNome', clip(d.tomador.nome, 300)));
  }

  const serv = tag(
    'serv',
    tag('locPrest', tag('cLocPrestacao', d.servico.cLocPrestacao)) +
      tag(
        'cServ',
        tag('cTribNac', d.servico.cTribNac) +
          tag('xDescServ', clip(d.servico.descricao, 2000)) +
          tag('cNBS', d.servico.cNBS),
      ),
  );

  const totTrib =
    d.valores.pTotTribSN != null && p.opSimpNac === '3'
      ? tag('pTotTribSN', dec2(d.valores.pTotTribSN))
      : tag('indTotTrib', '0');
  const valores = tag(
    'valores',
    tag('vServPrest', tag('vServ', dec2(d.valores.vServ))) +
      tag(
        'trib',
        tag(
          'tribMun',
          tag('tribISSQN', '1') + // 1 = operação tributável
            tag('tpRetISSQN', '1') + // 1 = não retido
            (d.valores.pAliq != null ? tag('pAliq', dec2(d.valores.pAliq)) : ''),
        ) + tag('totTrib', totTrib),
      ),
  );

  const inf =
    tag('tpAmb', d.tpAmb) +
    tag('dhEmi', brasiliaDateTime(d.dhEmi)) +
    tag('verAplic', clip(d.verAplic, 20)) +
    tag('serie', d.serie) +
    tag('nDPS', String(d.nDPS)) +
    tag('dCompet', brasiliaDate(d.dCompet)) +
    tag('tpEmit', '1') + // 1 = prestador
    tag('cLocEmi', d.cLocEmi) +
    tag('prest', prest) +
    toma +
    serv +
    valores;

  const xml =
    `<DPS xmlns="${NFSE_NAMESPACE}" versao="${NFSE_LAYOUT_VERSION}">` +
    `<infDPS Id="${id}">${inf}</infDPS>` +
    `</DPS>`;
  return { xml, id };
}

export function buildCancelamentoXml(c: CancelamentoData): { xml: string; id: string } {
  const id = pedRegEventoId(c.chNFSe, '101101');
  const inf =
    tag('tpAmb', c.tpAmb) +
    tag('verAplic', clip(c.verAplic, 20)) +
    tag('dhEvento', brasiliaDateTime(c.dhEvento)) +
    tag('CNPJAutor', c.cnpjAutor) +
    tag('chNFSe', c.chNFSe) +
    tag('nPedRegEvento', '1') + // cancelamento acontece uma vez por nota
    tag(
      'e101101',
      tag('xDesc', 'Cancelamento de NFS-e') +
        tag('cMotivo', c.cMotivo) +
        tag('xMotivo', clip(c.xMotivo, 255)),
    );
  const xml =
    `<pedRegEvento xmlns="${NFSE_NAMESPACE}" versao="${NFSE_LAYOUT_VERSION}">` +
    `<infPedReg Id="${id}">${inf}</infPedReg>` +
    `</pedRegEvento>`;
  return { xml, id };
}

// ---------------------------------------------------------------------------
// helpers

function tag(name: string, content: string): string {
  return `<${name}>${content}</${name}>`;
}

/** Tag só quando há valor — campo opcional vazio é rejeitado pelo schema (minLength 1). */
function optTag(name: string, value: string | null | undefined): string {
  const v = value == null ? '' : normalize(value);
  return v ? tag(name, escapeXml(v)) : '';
}

function onlyDigits(s: string | null | undefined): string {
  return (s ?? '').replace(/\D/g, '');
}

/** Texto livre: sem caracteres de controle, espaços colapsados, escapado e cortado. */
function clip(s: string, max: number): string {
  return escapeXml(normalize(s).slice(0, max));
}

function normalize(s: string): string {
  // eslint-disable-next-line no-control-regex
  return s.replace(/[\u0000-\u001f\u007f]/g, ' ').replace(/\s+/g, ' ').trim();
}

export function escapeXml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

function dec2(n: number): string {
  return (Math.round(n * 100) / 100).toFixed(2);
}

// Brasil sem horário de verão desde 2019: Brasília = UTC-3 fixo. O leiaute exige
// o offset explícito (AAAA-MM-DDThh:mm:ss-03:00).
const BRT_OFFSET_MS = 3 * 60 * 60 * 1000;

function brasiliaParts(d: Date): string[] {
  return new Date(d.getTime() - BRT_OFFSET_MS).toISOString().split(/[T.]/);
}

export function brasiliaDateTime(d: Date): string {
  const [date, time] = brasiliaParts(d);
  return `${date}T${time}-03:00`;
}

export function brasiliaDate(d: Date): string {
  return brasiliaParts(d)[0];
}
