import type { LookupOption, SubjectLookupService } from '../subject-lookup.service';
import { bestMatch, PlateFipeMatcher } from './plate-fipe-matcher.service';
import type { PlateHit } from './plate.provider';

const MARCAS: LookupOption[] = [
  { value: 'VW - VolksWagen', label: 'VW - VolksWagen', meta: { codigo: '59' } },
  { value: 'GM - Chevrolet', label: 'GM - Chevrolet', meta: { codigo: '23' } },
  { value: 'Fiat', label: 'Fiat', meta: { codigo: '21' } },
];

const MODELOS: LookupOption[] = [
  {
    value: 'CROSSFOX 1.6 Mi Total Flex 8V 5p',
    label: 'CROSSFOX 1.6 Mi Total Flex 8V 5p',
    meta: { codigo: '2368' },
  },
  {
    value: 'CROSSFOX 1.6 T.Flex 8V (Antigo)',
    label: 'CROSSFOX 1.6 T.Flex 8V (Antigo)',
    meta: { codigo: '2369' },
  },
  { value: 'GOL 1.0', label: 'GOL 1.0', meta: { codigo: '1000' } },
];

const ANOS: LookupOption[] = [
  { value: '2008', label: '2008' },
  { value: '2007', label: '2007' },
];

describe('bestMatch', () => {
  it('casa a marca crua do registro ("VW") com o nome canônico da FIPE', () => {
    expect(bestMatch(MARCAS, ['VW'])?.value).toBe('VW - VolksWagen');
    expect(bestMatch(MARCAS, ['GM'])?.value).toBe('GM - Chevrolet');
  });

  it('prefere a igualdade exata quando o texto FIPE veio na consulta', () => {
    expect(bestMatch(MARCAS, ['VW - VolksWagen', 'VW'])?.value).toBe(
      'VW - VolksWagen',
    );
  });

  it('ignora acento/caixa/pontuação ao comparar', () => {
    expect(bestMatch(MARCAS, ['fiat'])?.value).toBe('Fiat');
  });

  it('casa o modelo exato do texto FIPE em vez de outra variante', () => {
    const m = bestMatch(MODELOS, [
      'CROSSFOX 1.6 Mi Total Flex 8V 5p',
      'CROSSFOX',
    ]);
    expect(m?.meta?.codigo).toBe('2368');
  });

  it('com só o nome curto do registro, escolhe a variante mais genérica', () => {
    // Ambas começam com CROSSFOX; desempata pela mais curta.
    expect(bestMatch(MODELOS, ['CROSSFOX'])?.value).toBe(
      'CROSSFOX 1.6 T.Flex 8V (Antigo)',
    );
  });

  it('devolve undefined quando nada corresponde', () => {
    expect(bestMatch(MODELOS, ['UNO MILLE'])).toBeUndefined();
    expect(bestMatch(MODELOS, [undefined, ''])).toBeUndefined();
  });
});

/** Lookup fake: devolve a lista da fonte, aplicando o mesmo filtro `contains`. */
function fakeLookup(overrides: Partial<Record<string, LookupOption[]>> = {}) {
  const data: Record<string, LookupOption[]> = {
    'fipe.marcas': MARCAS,
    'fipe.modelos': MODELOS,
    'fipe.anos': ANOS,
    ...overrides,
  };
  const calls: Array<{ fonte: string; params: unknown }> = [];
  const lookup = {
    calls,
    lookup: jest.fn(
      (fonte: string, params: { marca?: string; modelo?: string; q?: string }) => {
        calls.push({ fonte, params });
        // Cascata igual à do service real: sem ancestral, nada a sugerir.
        if (fonte === 'fipe.modelos' && !params.marca) return Promise.resolve([]);
        if (fonte === 'fipe.anos' && (!params.marca || !params.modelo)) {
          return Promise.resolve([]);
        }
        const all = data[fonte] ?? [];
        const q = params.q?.toLowerCase();
        return Promise.resolve(
          q ? all.filter((o) => o.label.toLowerCase().includes(q)) : all,
        );
      },
    ),
  };
  return lookup;
}

const hitCompleto: PlateHit = {
  placa: 'INT8C36',
  marca: 'VW',
  modelo: 'CROSSFOX',
  anoModelo: '2007',
  fipe: {
    marca: 'VW - VolksWagen',
    modelo: 'CROSSFOX 1.6 Mi Total Flex 8V 5p',
    anoModelo: '2007',
  },
};

describe('PlateFipeMatcher', () => {
  it('resolve marca → modelo → ano com os códigos da cascata', async () => {
    const lookup = fakeLookup();
    const matcher = new PlateFipeMatcher(
      lookup as unknown as SubjectLookupService,
    );
    const match = await matcher.match(hitCompleto);

    expect(match?.marca).toEqual({ value: 'VW - VolksWagen', codigo: '59' });
    expect(match?.modelo).toEqual({
      value: 'CROSSFOX 1.6 Mi Total Flex 8V 5p',
      codigo: '2368',
    });
    expect(match?.ano?.value).toBe('2007');
    // Os modelos foram buscados JÁ com o código da marca (cascata respeitada).
    const modelos = lookup.calls.find((c) => c.fonte === 'fipe.modelos');
    expect(modelos?.params).toMatchObject({ marca: '59' });
  });

  it('sem marca correspondente, não inventa modelo/ano', async () => {
    const lookup = fakeLookup({ 'fipe.marcas': [] });
    const matcher = new PlateFipeMatcher(
      lookup as unknown as SubjectLookupService,
    );
    const match = await matcher.match(hitCompleto);
    expect(match).toBeUndefined();
    expect(lookup.calls.some((c) => c.fonte === 'fipe.modelos')).toBe(false);
  });

  it('casou a marca mas não o modelo → devolve só a marca', async () => {
    const lookup = fakeLookup({ 'fipe.modelos': [] });
    const matcher = new PlateFipeMatcher(
      lookup as unknown as SubjectLookupService,
    );
    const match = await matcher.match(hitCompleto);
    expect(match?.marca?.codigo).toBe('59');
    expect(match?.modelo).toBeUndefined();
    expect(match?.ano).toBeUndefined();
  });

  it('FIPE fora do ar → undefined (nunca derruba a consulta de placa)', async () => {
    const lookup = {
      lookup: jest.fn().mockRejectedValue(new Error('FIPE HTTP 503')),
    };
    const matcher = new PlateFipeMatcher(
      lookup as unknown as SubjectLookupService,
    );
    await expect(matcher.match(hitCompleto)).resolves.toBeUndefined();
  });

  it('hit sem dados de marca → nem consulta o catálogo', async () => {
    const lookup = fakeLookup();
    const matcher = new PlateFipeMatcher(
      lookup as unknown as SubjectLookupService,
    );
    await expect(matcher.match({ placa: 'ABC1D23' })).resolves.toBeUndefined();
    expect(lookup.lookup).not.toHaveBeenCalled();
  });
});
