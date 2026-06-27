import { NotFoundException } from '@nestjs/common';
import { SubjectLookupService } from './subject-lookup.service';
import type {
  FipeClient,
  FipeBrand,
  FipeModel,
  FipeYear,
} from './fipe.client';

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

/** Redis mínimo em memória (get/set com EX ignorado). */
function fakeRedis() {
  const store = new Map<string, string>();
  // Cast to unknown then to the injected type so the fake satisfies DI without
  // pulling the full ioredis Redis type into the spec.
  return {
    store,
    get: async (k: string) => store.get(k) ?? null,
    set: async (k: string, v: string) => {
      store.set(k, v);
      return 'OK';
    },
  } as unknown as import('ioredis').Redis;
}

describe('SubjectLookupService', () => {
  it('rejects an unknown source', async () => {
    const svc = new SubjectLookupService(fakeRedis(), new FakeFipe());
    await expect(svc.lookup('fipe.cor', {})).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('maps marcas with the FIPE code and a logo url in meta', async () => {
    const svc = new SubjectLookupService(fakeRedis(), new FakeFipe());
    const out = await svc.lookup('fipe.marcas', {});
    const ford = out.find((o) => o.value === 'Ford');
    expect(ford?.meta?.codigo).toBe('22');
    expect(ford?.meta?.logoUrl).toContain('/ford.png');
  });

  it('maps modelos with the FIPE code in meta (feeds the anos cascade)', async () => {
    const svc = new SubjectLookupService(fakeRedis(), new FakeFipe());
    const out = await svc.lookup('fipe.modelos', { marca: '22' });
    expect(out.find((o) => o.value === 'Ka')?.meta?.codigo).toBe('1');
  });

  it('returns [] for anos without marca+modelo', async () => {
    const svc = new SubjectLookupService(fakeRedis(), new FakeFipe());
    expect(await svc.lookup('fipe.anos', { marca: '22' })).toEqual([]);
  });

  it('anos: só o ano, deduplicado entre combustíveis; 32000 vira "0 km"', async () => {
    const svc = new SubjectLookupService(fakeRedis(), new FakeFipe());
    const out = await svc.lookup('fipe.anos', { marca: '22', modelo: '1' });
    expect(out.map((o) => o.value)).toEqual(['0 km', '2024', '2023']);
  });

  it('filters by q (case-insensitive contains)', async () => {
    const svc = new SubjectLookupService(fakeRedis(), new FakeFipe());
    const out = await svc.lookup('fipe.marcas', { q: 'fia' });
    expect(out.map((o) => o.value)).toEqual(['Fiat']);
  });

  it('returns [] for modelos without a marca code', async () => {
    const svc = new SubjectLookupService(fakeRedis(), new FakeFipe());
    expect(await svc.lookup('fipe.modelos', {})).toEqual([]);
  });

  it('serves the second call from cache (no second FIPE hit)', async () => {
    const fipe = new FakeFipe();
    const svc = new SubjectLookupService(fakeRedis(), fipe);
    await svc.lookup('fipe.marcas', {});
    await svc.lookup('fipe.marcas', { q: 'for' });
    expect(fipe.brandCalls).toBe(1);
  });

  it('degrades to [] when the FIPE client throws', async () => {
    const broken: FipeClient = {
      brands: async () => {
        throw new Error('boom');
      },
      models: async () => {
        throw new Error('boom');
      },
      years: async () => {
        throw new Error('boom');
      },
    };
    const svc = new SubjectLookupService(fakeRedis(), broken);
    expect(await svc.lookup('fipe.marcas', {})).toEqual([]);
  });
});
