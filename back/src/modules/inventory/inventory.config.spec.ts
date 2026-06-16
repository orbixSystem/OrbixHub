import {
  mergeInventoryConfig,
  DEFAULT_INVENTORY_CONFIG,
  validateAttributes,
  ItemFieldConfig,
} from './inventory.config';

describe('mergeInventoryConfig', () => {
  it('returns defaults (itemFields []) when nothing saved', () => {
    expect(mergeInventoryConfig(undefined)).toEqual(DEFAULT_INVENTORY_CONFIG);
    expect(mergeInventoryConfig(undefined).itemFields).toEqual([]);
  });

  it('lets patch.itemFields override current', () => {
    const current = {
      itemFields: [
        { key: 'a', label: 'A', type: 'text', required: false } as ItemFieldConfig,
      ],
    };
    const patch = {
      itemFields: [
        { key: 'b', label: 'B', type: 'number', required: true } as ItemFieldConfig,
      ],
    };
    const merged = mergeInventoryConfig(current, patch);
    expect(merged.itemFields).toEqual(patch.itemFields);
  });

  it('keeps current.itemFields when patch omits it', () => {
    const current = {
      itemFields: [
        { key: 'a', label: 'A', type: 'text', required: false } as ItemFieldConfig,
      ],
    };
    expect(mergeInventoryConfig(current, {}).itemFields).toEqual(current.itemFields);
  });
});

describe('validateAttributes', () => {
  it('returns [] for empty attributes and no fields', () => {
    expect(validateAttributes({}, [])).toEqual([]);
    expect(validateAttributes(null, [])).toEqual([]);
    expect(validateAttributes(undefined, [])).toEqual([]);
  });

  it('rejects an unknown key (mentioning it)', () => {
    const errors = validateAttributes({ foo: 'bar' }, []);
    expect(errors).toHaveLength(1);
    expect(errors[0]).toContain('foo');
  });

  describe('text field', () => {
    const fields: ItemFieldConfig[] = [
      { key: 'nome', label: 'Nome', type: 'text', required: false },
    ];
    it('errors on non-string', () => {
      expect(validateAttributes({ nome: 123 }, fields)).toHaveLength(1);
    });
    it('accepts a string', () => {
      expect(validateAttributes({ nome: 'abc' }, fields)).toEqual([]);
    });
  });

  describe('number field', () => {
    const fields: ItemFieldConfig[] = [
      { key: 'peso', label: 'Peso', type: 'number', required: false },
    ];
    it('errors on string', () => {
      expect(validateAttributes({ peso: '10' }, fields)).toHaveLength(1);
    });
    it('errors on non-finite', () => {
      expect(validateAttributes({ peso: Infinity }, fields)).toHaveLength(1);
    });
    it('accepts a number', () => {
      expect(validateAttributes({ peso: 10 }, fields)).toEqual([]);
    });
  });

  describe('tags field', () => {
    const fields: ItemFieldConfig[] = [
      { key: 'tags', label: 'Tags', type: 'tags', required: false },
    ];
    it('errors on non-array', () => {
      expect(validateAttributes({ tags: 'a' }, fields)).toHaveLength(1);
    });
    it('errors on array with non-string', () => {
      expect(validateAttributes({ tags: ['a', 1] }, fields)).toHaveLength(1);
    });
    it('accepts a list of strings', () => {
      expect(validateAttributes({ tags: ['a', 'b'] }, fields)).toEqual([]);
    });
  });

  describe('select field', () => {
    const fields: ItemFieldConfig[] = [
      {
        key: 'cor',
        label: 'Cor',
        type: 'select',
        required: false,
        options: ['vermelho', 'azul'],
      },
    ];
    it('errors on value outside options', () => {
      expect(validateAttributes({ cor: 'verde' }, fields)).toHaveLength(1);
    });
    it('accepts a value inside options', () => {
      expect(validateAttributes({ cor: 'azul' }, fields)).toEqual([]);
    });
  });

  describe('required field', () => {
    const fields: ItemFieldConfig[] = [
      { key: 'nome', label: 'Nome', type: 'text', required: true },
    ];
    const tagsFields: ItemFieldConfig[] = [
      { key: 'tags', label: 'Tags', type: 'tags', required: true },
    ];
    it('errors when absent', () => {
      expect(validateAttributes({}, fields)).toHaveLength(1);
    });
    it('errors when empty string', () => {
      expect(validateAttributes({ nome: '' }, fields)).toHaveLength(1);
    });
    it('errors when empty array', () => {
      expect(validateAttributes({ tags: [] }, tagsFields)).toHaveLength(1);
    });
    it('accepts when present', () => {
      expect(validateAttributes({ nome: 'abc' }, fields)).toEqual([]);
    });
  });
});
