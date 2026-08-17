import { SubjectLookupRegistry } from '../../modules/customers/subject-lookup.registry';
import { SubjectLookupService } from '../../modules/customers/subject-lookup.service';
import { VerticalRegistry } from '../vertical.registry';
import { VeiculosVerticalModule } from './veiculos.module';
import type { FipeBrand, FipeClient, FipeModel, FipeYear } from './fipe.client';

/**
 * Mapeamento FIPE — testes que moraram em `customers/subject-lookup.service.spec.ts`
 * até 17/08/2026 e vieram junto com o código para a vertical.
 *
 * Testa o que a VERTICAL registra: as três fontes da cascata e como cada uma
 * traduz a resposta da FIPE para opções genéricas. O service que consome isso é
 * o genérico do `customers`, montado aqui de verdade — assim o teste prova a
 * integração pelo ponto de extensão, não só o mapeamento isolado.
 */

class FakeFipe implements FipeClient {
  public brandCalls = 0;
  constructor(
    private readonly _brands: FipeBrand[] = [
      { code: '22', name: 'Ford' },
      { code: '23', name: 'Fiat' },
    ],
    private readonly _models: FipeModel[] = [
      { code: '1', name: 'Ka' },
      { code: '2', name: 'Fiesta' },
    ],
    private readonly _years: FipeYear[] = [
      { code: '32000-1', name: '32000 Gasolina' },
      { code: '2024-1', name: '2024 Gasolina' },
      { code: '2024-2', name: '2024 Diesel' },
      { code: '2023-1', name: '2023 Gasolina' },
    ],
  ) {}
  async brands() {
    this.brandCalls++;
    return this._brands;
  }
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  async models(_brandCode: string) {
    return this._models;
  }
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  async years(_brandCode: string, _modelCode: string) {
    return this._years;
  }
}

function fakeRedis() {
  const store = new Map<string, string>();
  return {
    get: async (k: string) => store.get(k) ?? null,
    set: async (k: string, v: string) => {
      store.set(k, v);
      return 'OK';
    },
  } as unknown as import('ioredis').Redis;
}

function montar(fipe: FipeClient = new FakeFipe()) {
  const lookups = new SubjectLookupRegistry();
  const verticais = new VerticalRegistry();
  // O módulo da vertical é quem registra as fontes — chamando o onModuleInit
  // real, o teste cobre o registro e o mapeamento de uma vez.
  new VeiculosVerticalModule(lookups, verticais, fipe).onModuleInit();
  return {
    svc: new SubjectLookupService(fakeRedis(), lookups),
    lookups,
    verticais,
  };
}

describe('vertical veículos — registro no ponto de extensão', () => {
  it('registra as três fontes da cascata FIPE', () => {
    const { lookups } = montar();
    expect(lookups.chaves().sort()).toEqual([
      'fipe.anos',
      'fipe.marcas',
      'fipe.modelos',
    ]);
  });

  it('declara que implementa as capacidades de veículo', () => {
    // Sem este registro, as capacidades marcadas com `requerImplementacao`
    // ficam indisponíveis — é a trava que impede um nicho genérico de ligar a
    // consulta por placa.
    const { verticais } = montar();
    expect([...verticais.comImplementacao()].sort()).toEqual([
      'customers.atributosCascata',
      'customers.fichaTecnica',
      'customers.identifierLookup',
    ]);
  });
});

describe('mapeamento FIPE → opções genéricas', () => {
  it('marcas trazem o código FIPE e a url do logo em meta', async () => {
    const { svc } = montar();
    const ford = (await svc.lookup('fipe.marcas', {})).find((o) => o.value === 'Ford');
    expect(ford?.meta?.codigo).toBe('22');
    expect(ford?.meta?.logoUrl).toContain('/ford.png');
  });

  it('modelos trazem o código FIPE em meta (alimenta a cascata de anos)', async () => {
    const { svc } = montar();
    const out = await svc.lookup('fipe.modelos', { marca: '22' });
    expect(out.find((o) => o.value === 'Ka')?.meta?.codigo).toBe('1');
  });

  it('anos: só o ano, deduplicado entre combustíveis; 32000 vira "0 km"', async () => {
    const { svc } = montar();
    const out = await svc.lookup('fipe.anos', { marca: '22', modelo: '1' });
    expect(out.map((o) => o.value)).toEqual(['0 km', '2024', '2023']);
  });

  it('modelos sem marca devolve [] (cascata declarada em `requer`)', async () => {
    const { svc } = montar();
    expect(await svc.lookup('fipe.modelos', {})).toEqual([]);
  });

  it('anos sem marca+modelo devolve []', async () => {
    const { svc } = montar();
    expect(await svc.lookup('fipe.anos', { marca: '22' })).toEqual([]);
  });

  it('FIPE fora do ar degrada para [] — o cadastro nunca trava', async () => {
    const quebrada: FipeClient = {
      brands: async () => { throw new Error('boom'); },
      models: async () => { throw new Error('boom'); },
      years: async () => { throw new Error('boom'); },
    };
    const { svc } = montar(quebrada);
    expect(await svc.lookup('fipe.marcas', {})).toEqual([]);
  });
});
