import { NotFoundException } from '@nestjs/common';
import { SubjectLookupService } from './subject-lookup.service';
import { SubjectLookupRegistry, type LookupSource } from './subject-lookup.registry';

/**
 * Testa o que é GENÉRICO: cache, filtro, cascata e degradação. O mapeamento da
 * FIPE (marca/modelo/ano, "32000" → "0 km") saiu daqui junto com o código e é
 * testado em `verticals/veiculos/fipe-sources.spec.ts`. Este service não sabe
 * mais o que é FIPE — a fonte chega registrada.
 */

/** Redis mínimo em memória (get/set com EX ignorado). */
function fakeRedis() {
  const store = new Map<string, string>();
  return {
    store,
    get: async (k: string) => store.get(k) ?? null,
    set: async (k: string, v: string) => {
      store.set(k, v);
      return 'OK';
    },
  } as unknown as import('ioredis').Redis;
}

function makeSvc(sources: LookupSource[]) {
  const registry = new SubjectLookupRegistry();
  for (const s of sources) registry.registrar(s);
  return new SubjectLookupService(fakeRedis(), registry);
}

const contador = { n: 0 };
const fonteSimples = (): LookupSource => ({
  key: 'teste.itens',
  buscar: async () => {
    contador.n++;
    return [
      { value: 'Ford', label: 'Ford' },
      { value: 'Fiat', label: 'Fiat' },
    ];
  },
});

beforeEach(() => {
  contador.n = 0;
});

describe('SubjectLookupService', () => {
  it('recusa fonte não registrada', async () => {
    const svc = makeSvc([]);
    await expect(svc.lookup('nao.existe', {})).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('devolve as opções da fonte registrada', async () => {
    const svc = makeSvc([fonteSimples()]);
    expect((await svc.lookup('teste.itens', {})).map((o) => o.value)).toEqual([
      'Ford',
      'Fiat',
    ]);
  });

  it('filtra por q (contains, sem diferenciar maiúscula)', async () => {
    const svc = makeSvc([fonteSimples()]);
    const out = await svc.lookup('teste.itens', { q: 'fia' });
    expect(out.map((o) => o.value)).toEqual(['Fiat']);
  });

  it('a segunda chamada vem do cache (não bate na fonte de novo)', async () => {
    const svc = makeSvc([fonteSimples()]);
    await svc.lookup('teste.itens', {});
    await svc.lookup('teste.itens', { q: 'for' });
    expect(contador.n).toBe(1);
  });

  describe('cascata declarada pela fonte', () => {
    const comMarca: LookupSource = {
      key: 'teste.modelos',
      requer: ['marca'],
      buscar: async () => {
        contador.n++;
        return [{ value: 'Ka', label: 'Ka' }];
      },
    };
    const comMarcaEModelo: LookupSource = {
      key: 'teste.anos',
      requer: ['marca', 'modelo'],
      buscar: async () => [{ value: '2024', label: '2024' }],
    };

    it('sem o ancestral, devolve [] sem nem chamar a fonte', async () => {
      const svc = makeSvc([comMarca]);
      expect(await svc.lookup('teste.modelos', {})).toEqual([]);
      expect(contador.n).toBe(0); // não gasta chamada externa para descobrir
    });

    it('com o ancestral, busca normalmente', async () => {
      const svc = makeSvc([comMarca]);
      expect(await svc.lookup('teste.modelos', { marca: '22' })).toHaveLength(1);
    });

    it('exige TODOS os ancestrais declarados', async () => {
      const svc = makeSvc([comMarcaEModelo]);
      expect(await svc.lookup('teste.anos', { marca: '22' })).toEqual([]);
      expect(
        await svc.lookup('teste.anos', { marca: '22', modelo: '1' }),
      ).toHaveLength(1);
    });
  });

  it('degrada para [] quando a fonte lança — o campo segue como texto livre', async () => {
    const svc = makeSvc([
      {
        key: 'teste.quebrada',
        buscar: async () => {
          throw new Error('boom');
        },
      },
    ]);
    expect(await svc.lookup('teste.quebrada', {})).toEqual([]);
  });
});
