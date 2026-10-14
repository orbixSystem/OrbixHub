export const FISCAL_GATEWAY = Symbol('FISCAL_GATEWAY');

export type FiscalDocumentType = 'nfse' | 'nfce' | 'nfe';
export type FiscalEnvironment = 'homologacao' | 'producao';
export type FiscalLineKind = 'product' | 'service';

/** Uma linha da nota (snapshot de item da OS — serviço OU produto). */
export interface FiscalIssueLine {
  kind: FiscalLineKind;
  name: string;
  quantity: number;
  unitPrice: number;
  total: number;
}

/**
 * Quem emite e com que classificação — montado pelo InvoiceService a partir da
 * identidade fiscal do núcleo + config do módulo. Gateways que falam direto com
 * o fisco (govbr) precisam disto; o Noop ignora.
 */
export interface FiscalIssuer {
  cnpj: string | null;
  /** simples | mei | presumido | real (tenant.settings.regimeTributario). */
  regimeTributario: string | null;
  /** Código IBGE (7 dígitos) do município do emitente. */
  codigoMunicipio: string | null;
  fone: string | null;
  email: string | null;
  /** Série/número da DPS reservados para esta nota. */
  dps: { serie: string; numero: number };
  servico: {
    /** cTribNac — 6 dígitos (item+subitem da LC 116 + desdobro nacional). */
    codigoNacional: string | null;
    /** cNBS — 9 dígitos. */
    codigoNbs: string | null;
    aliquotaIss: number | null;
    percentualTributosSimples: number | null;
  };
  /** Rótulo da origem ("OS 123", "venda 45") — vai na descrição do serviço. */
  reference: string;
}

export interface FiscalIssueParams {
  tenantId: string;
  invoiceId: string;
  documentType: FiscalDocumentType;
  environment: FiscalEnvironment;
  customer: { name: string | null; document: string | null };
  lines: FiscalIssueLine[];
  serviceAmount: number;
  productAmount: number;
  totalAmount: number;
  issuer?: FiscalIssuer;
}

/**
 * Resultado da emissão. `status` pode ser síncrono (`authorized`/`rejected` —
 * caso do Noop) ou assíncrono (`processing` — o gateway real confirma depois via
 * webhook). Campos fiscais só chegam preenchidos quando autorizado.
 */
export interface FiscalIssueResult {
  externalId: string;
  status: 'processing' | 'authorized' | 'rejected';
  number: string | null;
  series: string | null;
  accessKey: string | null;
  pdfUrl: string | null;
  xmlUrl: string | null;
  rejectionReason: string | null;
  /** XML autorizado, quando o gateway o devolve na hora (NFS-e Nacional). */
  documentXml?: string | null;
}

export interface FiscalCancelParams {
  tenantId: string;
  invoiceId: string;
  externalId: string;
  reason: string;
  /** Ambiente em que a nota foi emitida (o evento vai para o mesmo). */
  environment?: FiscalEnvironment;
  /** CNPJ do autor do evento (o emitente). */
  issuerCnpj?: string | null;
}

export interface FiscalCancelResult {
  status: 'canceled' | 'rejected';
  rejectionReason: string | null;
}

/**
 * Contrato agnóstico ao provedor fiscal — nenhum tipo específico de gateway vaza
 * além desta fronteira (mesmo padrão do PaymentGateway). Impl real =
 * `GovBrNfseGateway` (API NFS-e Nacional gov.br); `NoopFiscalGateway` em dev.
 */
export interface FiscalGateway {
  /** Emite a nota. DEVE ser chamado FORA de qualquer transação de banco. */
  issue(params: FiscalIssueParams): Promise<FiscalIssueResult>;
  /** Cancela uma nota autorizada. DEVE ser chamado FORA de qualquer transação. */
  cancel(params: FiscalCancelParams): Promise<FiscalCancelResult>;
  /**
   * Verifica a assinatura do webhook sobre o corpo cru EXATO.
   * Retorna true sse a assinatura é autêntica. Nunca lança.
   */
  verifySignature(rawBody: Buffer | string, signature: string | undefined): boolean;
  /**
   * PDF oficial (DANFSe) de uma nota autorizada, para gateways cujo PDF não é
   * uma URL pública. Ausente = o gateway entrega `pdfUrl` no resultado.
   */
  downloadPdf?(params: {
    tenantId: string;
    environment: FiscalEnvironment;
    accessKey: string;
  }): Promise<Buffer>;
}
