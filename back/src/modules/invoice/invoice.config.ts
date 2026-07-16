/** Chave da seção de config do módulo (host incremental de Configurações). */
export const INVOICE_CONFIG_KEY = 'invoice';

export type FiscalEnvironment = 'homologacao' | 'producao';

/** Config NÃO-sensível do tenant (em tenant_module.settings['invoice']['invoice']).
 *  O .pfx e o CSC vão para o provedor; aqui guardamos só metadados/preferências. */
export interface InvoiceConfig {
  ambiente: FiscalEnvironment;
  serieNfse: string;
  serieNfce: string;
  serieNfe: string;
  idCsc: string; // identificador do CSC (o segredo CSC em si vai para o provedor)
  empresaRegistrada: boolean; // empresa cadastrada na Nuvem Fiscal?
  certificado: { validoAte: string | null }; // data ISO de validade do A1 (metadado)
}

export const DEFAULT_INVOICE_CONFIG: InvoiceConfig = {
  ambiente: 'homologacao',
  serieNfse: '1',
  serieNfce: '1',
  serieNfe: '1',
  idCsc: '',
  empresaRegistrada: false,
  certificado: { validoAte: null },
};

const KEYS: (keyof InvoiceConfig)[] = [
  'ambiente',
  'serieNfse',
  'serieNfce',
  'serieNfe',
  'idCsc',
  'empresaRegistrada',
  'certificado',
];

export function mergeInvoiceConfig(
  current?: Partial<InvoiceConfig>,
  patch?: Partial<InvoiceConfig>,
): InvoiceConfig {
  const out: InvoiceConfig = { ...DEFAULT_INVOICE_CONFIG };
  for (const k of KEYS) {
    if (current && current[k] !== undefined) ((out as unknown) as Record<string, unknown>)[k] = current[k];
    if (patch && patch[k] !== undefined) ((out as unknown) as Record<string, unknown>)[k] = patch[k];
  }
  return out;
}
