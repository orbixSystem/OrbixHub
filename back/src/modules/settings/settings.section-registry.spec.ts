import { COMPANY_SECTION } from './settings.section-registry';

describe('COMPANY_SECTION', () => {
  const keys = COMPANY_SECTION.fields.map((f) => f.key);

  it('mantém os campos de identidade já existentes', () => {
    for (const k of ['companyName', 'legalName', 'taxId', 'phone', 'email', 'logoUrl', 'primaryColor']) {
      expect(keys).toContain(k);
    }
  });

  it('inclui os campos fiscais para NF-e', () => {
    for (const k of ['inscricaoEstadual', 'inscricaoMunicipal', 'regimeTributario', 'cnae', 'cep', 'logradouro', 'numero', 'bairro', 'municipio', 'uf']) {
      expect(keys).toContain(k);
    }
  });

  it('regimeTributario é select com opções e uf tem 27 UFs', () => {
    const regime = COMPANY_SECTION.fields.find((f) => f.key === 'regimeTributario')!;
    expect(regime.type).toBe('select');
    expect(regime.options?.map((o) => o.value)).toEqual(
      expect.arrayContaining(['simples', 'mei', 'presumido', 'real']),
    );
    const uf = COMPANY_SECTION.fields.find((f) => f.key === 'uf')!;
    expect(uf.type).toBe('select');
    expect(uf.options).toHaveLength(27);
  });

  it('themePreset é select e inclui lavanda (default) + variações', () => {
    const t = COMPANY_SECTION.fields.find((f) => f.key === 'themePreset')!;
    expect(t.type).toBe('select');
    expect(t.options?.[0]?.value).toBe('lavanda');
    expect(t.options?.map((o) => o.value)).toEqual(
      expect.arrayContaining(['lavanda', 'azul', 'petroleo', 'verde', 'tangerina', 'rosa', 'vermelho', 'ardosia']),
    );
  });
});
