import { DEFAULT_INVOICE_CONFIG, mergeInvoiceConfig } from './invoice.config';

describe('mergeInvoiceConfig', () => {
  it('retorna defaults quando nada é passado', () => {
    expect(mergeInvoiceConfig()).toEqual(DEFAULT_INVOICE_CONFIG);
    expect(DEFAULT_INVOICE_CONFIG.ambiente).toBe('homologacao');
    expect(DEFAULT_INVOICE_CONFIG.empresaRegistrada).toBe(false);
  });

  it('sobrepõe apenas os campos do patch', () => {
    const merged = mergeInvoiceConfig(
      { serieNfse: '1', ambiente: 'homologacao' },
      { ambiente: 'producao' },
    );
    expect(merged.ambiente).toBe('producao');
    expect(merged.serieNfse).toBe('1');
  });

  it('ignora chaves desconhecidas do patch', () => {
    const merged = mergeInvoiceConfig({}, { lixo: 1 } as never);
    expect(((merged as unknown) as Record<string, unknown>).lixo).toBeUndefined();
  });
});
