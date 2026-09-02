import {
  DEFAULT_CUSTOMERS_CONFIG,
  mergeCustomersConfig,
} from './customers.config';

describe('mergeCustomersConfig', () => {
  it('returns generic defaults when nothing is saved', () => {
    expect(mergeCustomersConfig(undefined)).toEqual(DEFAULT_CUSTOMERS_CONFIG);
  });

  it('overlays a partial patch over the current config', () => {
    const merged = mergeCustomersConfig(
      { documentRequired: false },
      { documentRequired: true },
    );
    expect(merged.documentRequired).toBe(true);
    // untouched keys keep their defaults
    expect(merged.usaSubjects).toBe(true);
    // Base GENÉRICA: o rótulo de oficina saiu daqui e virou pacote da vertical.
    expect(merged.subjectLabel.singular).toBe('Objeto');
  });

  it('merges the label object shallowly', () => {
    const merged = mergeCustomersConfig(undefined, {
      subjectLabel: { singular: 'Pet', plural: 'Pets' },
    });
    expect(merged.subjectLabel).toEqual({ singular: 'Pet', plural: 'Pets' });
  });

  it('replaces subjectFields wholesale when provided', () => {
    const fields = [
      { chave: 'nome', rotulo: 'Nome', tipo: 'text' as const, obrigatorio: true },
    ];
    const merged = mergeCustomersConfig(undefined, { subjectFields: fields });
    expect(merged.subjectFields).toEqual(fields);
  });

  it('preserves a previously saved value when the patch omits it', () => {
    const merged = mergeCustomersConfig({ usaSubjects: false }, {});
    expect(merged.usaSubjects).toBe(false);
  });

  // Snapshots de config salvos ANTES da introdução de `fonte` congelaram
  // marca/modelo sem o atributo. O merge reaplica fonte/dependeDe por `chave` —
  // agora a partir da BASE recebida (o pacote da vertical), não de uma constante
  // fixa. É como `getConfig` chama: base = pacote, patch = o que o tenant salvou.
  it('reapplies fonte/dependeDe from the base pack to old saved fields by chave', () => {
    const pacote = {
      subjectFields: [
        { chave: 'identifier', rotulo: 'Placa', tipo: 'text' as const, obrigatorio: true },
        { chave: 'marca', rotulo: 'Marca', tipo: 'text' as const, obrigatorio: false, fonte: 'fipe.marcas' },
        { chave: 'modelo', rotulo: 'Modelo', tipo: 'text' as const, obrigatorio: false, fonte: 'fipe.modelos', dependeDe: 'marca' },
      ],
    };
    const savedOld = {
      subjectFields: [
        { chave: 'identifier', rotulo: 'Placa', tipo: 'text' as const, obrigatorio: true },
        { chave: 'marca', rotulo: 'Marca', tipo: 'text' as const, obrigatorio: false },
        { chave: 'modelo', rotulo: 'Modelo', tipo: 'text' as const, obrigatorio: false },
      ],
    };
    const merged = mergeCustomersConfig(pacote, savedOld);
    const marca = merged.subjectFields.find((f) => f.chave === 'marca');
    const modelo = merged.subjectFields.find((f) => f.chave === 'modelo');
    expect(marca?.fonte).toBe('fipe.marcas');
    expect(modelo?.fonte).toBe('fipe.modelos');
    expect(modelo?.dependeDe).toBe('marca');
  });

  // Mesmo mecanismo, agora para `formato`: os tenants de oficina têm config
  // SALVA (snapshot congelado) sem o atributo, e é o merge que devolve a
  // máscara/validação de placa. Sem isto, fechar o vazamento no front tiraria a
  // placa da oficina junto.
  it('reapplies formato from the base pack to old saved fields by chave', () => {
    const pacote = {
      subjectFields: [
        {
          chave: 'identifier',
          rotulo: 'Placa',
          tipo: 'text' as const,
          obrigatorio: true,
          formato: 'placa' as const,
        },
      ],
    };
    const savedOld = {
      subjectFields: [
        { chave: 'identifier', rotulo: 'Placa', tipo: 'text' as const, obrigatorio: true },
      ],
    };
    const merged = mergeCustomersConfig(pacote, savedOld);
    expect(merged.subjectFields[0].formato).toBe('placa');
  });

  // O contrário: nicho genérico não declara formato, então o identificador do
  // tenant de equipamentos continua texto livre depois do merge.
  it('does not invent a formato when the base pack declares none', () => {
    const pacote = {
      subjectFields: [
        {
          chave: 'identifier',
          rotulo: 'Identificação',
          tipo: 'text' as const,
          obrigatorio: false,
        },
      ],
    };
    const merged = mergeCustomersConfig(pacote, {
      subjectFields: [
        { chave: 'identifier', rotulo: 'Nome', tipo: 'text' as const, obrigatorio: false },
      ],
    });
    expect(merged.subjectFields[0].formato).toBeUndefined();
  });

  it('does not invent a fonte for custom fields without a default by chave', () => {
    const merged = mergeCustomersConfig({
      subjectFields: [
        { chave: 'montadora', rotulo: 'Montadora', tipo: 'text' as const, obrigatorio: false },
      ],
    });
    expect(merged.subjectFields[0].fonte).toBeUndefined();
  });
});
