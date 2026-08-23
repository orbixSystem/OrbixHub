import {
  featureDisponivel,
  featureLigada,
  featuresLigadas,
  resolverCampos,
  resolverVocab,
  type ContextoFeature,
} from './vertical.resolve';
import { EQUIPAMENTOS } from './packs/equipamentos.pack';
import { VEICULOS } from './packs/veiculos.pack';
import { DEFAULT_CUSTOMERS_CONFIG } from '../modules/customers/customers.config';
import type { DefinicaoFeature } from './vertical.types';

const PACOTES = [EQUIPAMENTOS, VEICULOS];

const def = (over: Partial<DefinicaoFeature> = {}): DefinicaoFeature => ({
  key: 'customers.identifierLookup',
  moduleKey: 'customers',
  nome: 'Consulta por identificador',
  descricao: 'x',
  defaultEnabled: false,
  ...over,
});

const ctx = (over: Partial<ContextoFeature> = {}): ContextoFeature => ({
  modulosHabilitados: ['customers', 'os'],
  comImplementacao: new Map<string, Set<string>>(),
  toggles: new Map<string, boolean>(),
  verticalKey: 'veiculos',
  ...over,
});

describe('resolverVocab', () => {
  it('vertical sobrepõe o padrão só nas chaves que ela declara', () => {
    const v = resolverVocab(PACOTES, 'veiculos');
    expect(v['objeto.singular']).toBe('Veículo');
    expect(v['os.status.entregue']).toBe('Veículo entregue');
    // Não declarada em veiculos: tem de vir do pacote padrão, não sumir.
    expect(v['os.status.cancelada']).toBe('OS cancelada');
    expect(v['os.status.em_execucao']).toBe('Em execução');
  });

  it('vertical nula cai no pacote padrão', () => {
    const v = resolverVocab(PACOTES, null);
    expect(v['objeto.singular']).toBe('Equipamento');
    expect(v['os.status.entregue']).toBe('Serviço entregue');
  });

  it('vertical desconhecida cai no padrão em vez de explodir', () => {
    // Dado velho no banco ou pasta renomeada não pode deixar tenant sem app.
    const v = resolverVocab(PACOTES, 'nicho-que-nao-existe');
    expect(v['objeto.singular']).toBe('Equipamento');
  });

  it('override do tenant ganha da vertical', () => {
    const v = resolverVocab(PACOTES, 'veiculos', { 'objeto.singular': 'Moto' });
    expect(v['objeto.singular']).toBe('Moto');
    // O que ele não sobrescreveu continua vindo da vertical.
    expect(v['objeto.identificador']).toBe('Placa');
  });

  it('override ignora chave desconhecida, valor não-texto e string vazia', () => {
    const v = resolverVocab(PACOTES, 'veiculos', {
      'chave.inventada': 'nada',
      'objeto.plural': 42,
      'objeto.identificador': '   ',
    } as Record<string, unknown>);
    expect(v['chave.inventada']).toBeUndefined();
    expect(v['objeto.plural']).toBe('Veículos');
    expect(v['objeto.identificador']).toBe('Placa');
  });
});

describe('resolverCampos', () => {
  it('substitui a lista inteira, não faz merge por chave', () => {
    const campos = resolverCampos(PACOTES, 'veiculos');
    expect(campos.map((c) => c.chave)).toEqual([
      'identifier', 'marca', 'modelo', 'ano', 'cor', 'km',
    ]);
    // 'descricao' é do pacote padrão e NÃO pode vazar para a oficina.
    expect(campos.some((c) => c.chave === 'descricao')).toBe(false);
  });

  it('vertical nula usa os campos do padrão', () => {
    expect(resolverCampos(PACOTES, null).map((c) => c.chave)).toEqual([
      'identifier', 'descricao',
    ]);
  });
});

describe('critério de aceite da migração — a oficina não pode ver diferença', () => {
  /**
   * GOLDEN do formulário de oficina: é exatamente o que o
   * `DEFAULT_CUSTOMERS_CONFIG` continha antes de 17/08/2026, quando os campos
   * de veículo ainda moravam dentro do módulo genérico. Os 6 tenants de
   * produção são todos oficina e rodavam esse default; se este teste quebrar,
   * a migração deixou de ser invisível para eles e alguém vai perceber na tela.
   *
   * Escrito à mão de propósito: comparar com a constante não provaria nada
   * depois que ela virou genérica.
   */
  it('o formulário da oficina continua idêntico ao de antes da migração', () => {
    expect(resolverCampos(PACOTES, 'veiculos')).toEqual([
      { chave: 'identifier', rotulo: 'Placa', tipo: 'text', obrigatorio: true },
      { chave: 'marca', rotulo: 'Marca', tipo: 'text', obrigatorio: false, fonte: 'fipe.marcas' },
      { chave: 'modelo', rotulo: 'Modelo', tipo: 'text', obrigatorio: false, fonte: 'fipe.modelos', dependeDe: 'marca' },
      { chave: 'ano', rotulo: 'Ano', tipo: 'number', obrigatorio: false, fonte: 'fipe.anos', dependeDe: 'modelo' },
      { chave: 'cor', rotulo: 'Cor', tipo: 'text', obrigatorio: false },
      { chave: 'km', rotulo: 'KM', tipo: 'number', obrigatorio: false },
    ]);
  });

  it('o rótulo do objeto na oficina continua sendo Veículo/Veículos', () => {
    const v = resolverVocab(PACOTES, 'veiculos');
    expect(v['objeto.singular']).toBe('Veículo');
    expect(v['objeto.plural']).toBe('Veículos');
  });

  it('a base genérica não tem mais nenhum termo de oficina', () => {
    // O contrário do teste acima: prova que a casca saiu do módulo genérico.
    expect(DEFAULT_CUSTOMERS_CONFIG.subjectFields).toEqual([]);
    expect(DEFAULT_CUSTOMERS_CONFIG.subjectLabel.singular).toBe('Objeto');
  });
});

describe('featureDisponivel', () => {
  it('módulo dono desabilitado torna a capacidade indisponível', () => {
    expect(featureDisponivel(def(), ctx({ modulosHabilitados: ['os'] }))).toBe(false);
  });

  it('exige implementação e não há nenhuma registrada: indisponível', () => {
    expect(featureDisponivel(def({ requerImplementacao: true }), ctx())).toBe(false);
  });

  it('exige implementação e a vertical DO TENANT registrou: disponível', () => {
    const c = ctx({
      comImplementacao: new Map([['customers.identifierLookup', new Set(['veiculos'])]]),
    });
    expect(featureDisponivel(def({ requerImplementacao: true }), c)).toBe(true);
  });

  it('implementada por OUTRA vertical não vale para este tenant', () => {
    // Regressão: bastava a pasta `veiculos/` existir no processo para a
    // clínica ver — e poder ligar — a consulta por placa.
    const c = ctx({
      verticalKey: 'equipamentos',
      comImplementacao: new Map([['customers.identifierLookup', new Set(['veiculos'])]]),
    });
    expect(featureDisponivel(def({ requerImplementacao: true }), c)).toBe(false);
  });

  it('tenant sem nicho não alcança capacidade que exige implementação', () => {
    const c = ctx({
      verticalKey: null,
      comImplementacao: new Map([['customers.identifierLookup', new Set(['veiculos'])]]),
    });
    expect(featureDisponivel(def({ requerImplementacao: true }), c)).toBe(false);
  });
});

describe('featureLigada', () => {
  it('sem toggle, herda o featuresLigadas do pacote da vertical', () => {
    expect(featureLigada(def(), ctx(), PACOTES)).toBe(true);
  });

  it('sem toggle e fora do pacote, cai no defaultEnabled', () => {
    const c = ctx({ verticalKey: 'equipamentos' });
    expect(featureLigada(def({ defaultEnabled: false }), c, PACOTES)).toBe(false);
    expect(featureLigada(def({ defaultEnabled: true }), c, PACOTES)).toBe(true);
  });

  it('toggle explícito do tenant ganha do pacote — nos dois sentidos', () => {
    const desliga = ctx({ toggles: new Map([['customers.identifierLookup', false]]) });
    expect(featureLigada(def(), desliga, PACOTES)).toBe(false);

    const liga = ctx({
      verticalKey: 'equipamentos',
      toggles: new Map([['customers.identifierLookup', true]]),
    });
    expect(featureLigada(def(), liga, PACOTES)).toBe(true);
  });

  it('indisponível ignora o toggle: ligar o que não tem implementação não adianta', () => {
    const c = ctx({ toggles: new Map([['customers.identifierLookup', true]]) });
    expect(featureLigada(def({ requerImplementacao: true }), c, PACOTES)).toBe(false);
  });
});

describe('featuresLigadas', () => {
  const defs = [
    def({ key: 'customers.identifierLookup', moduleKey: 'customers' }),
    def({ key: 'customers.fichaTecnica', moduleKey: 'customers' }),
    def({ key: 'os.trackingLink', moduleKey: 'os', defaultEnabled: true }),
  ];

  it('oficina: liga as três', () => {
    expect(featuresLigadas(defs, ctx(), PACOTES)).toEqual([
      'customers.fichaTecnica',
      'customers.identifierLookup',
      'os.trackingLink',
    ]);
  });

  it('genérico: só o que serve qualquer nicho', () => {
    const c = ctx({ verticalKey: 'equipamentos' });
    expect(featuresLigadas(defs, c, PACOTES)).toEqual(['os.trackingLink']);
  });

  it('módulo desabilitado leva junto as capacidades dele', () => {
    const c = ctx({ modulosHabilitados: ['os'] });
    expect(featuresLigadas(defs, c, PACOTES)).toEqual(['os.trackingLink']);
  });
});
