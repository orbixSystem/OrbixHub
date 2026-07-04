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
}

export interface FiscalCancelParams {
  tenantId: string;
  invoiceId: string;
  externalId: string;
  reason: string;
}

export interface FiscalCancelResult {
  status: 'canceled' | 'rejected';
  rejectionReason: string | null;
}

/**
 * Contrato agnóstico ao provedor fiscal — nenhum tipo específico de gateway vaza
 * além desta fronteira (mesmo padrão do PaymentGateway). Impl real futura =
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
}
