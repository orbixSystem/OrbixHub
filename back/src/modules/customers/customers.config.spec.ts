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
    expect(merged.subjectLabel.singular).toBe('Veículo');
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
  // marca/modelo sem o atributo. O merge reaplica fonte/dependeDe dos defaults
  // por `chave`, para o autocomplete voltar a funcionar sem migration de dados.
  it('reapplies fonte/dependeDe from defaults to old saved fields by chave', () => {
    const savedOld = {
      subjectFields: [
        { chave: 'identifier', rotulo: 'Placa', tipo: 'text' as const, obrigatorio: true },
        { chave: 'marca', rotulo: 'Marca', tipo: 'text' as const, obrigatorio: false },
        { chave: 'modelo', rotulo: 'Modelo', tipo: 'text' as const, obrigatorio: false },
      ],
    };
    const merged = mergeCustomersConfig(savedOld);
    const marca = merged.subjectFields.find((f) => f.chave === 'marca');
    const modelo = merged.subjectFields.find((f) => f.chave === 'modelo');
    expect(marca?.fonte).toBe('fipe.marcas');
    expect(modelo?.fonte).toBe('fipe.modelos');
    expect(modelo?.dependeDe).toBe('marca');
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
