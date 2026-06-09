import { NotFoundException } from '@nestjs/common';
import { SubjectLookupService } from './subject-lookup.service';
import type { FipeClient, FipeBrand, FipeModel } from './fipe.client';

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
  ) {}
  async brands() {
    this.brandCalls++;
    return this._brands;
  }
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  async models(_brandCode: string) {
    return this._models;
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

  it('maps marcas with the FIPE code in meta', async () => {
    const svc = new SubjectLookupService(fakeRedis(), new FakeFipe());
    const out = await svc.lookup('fipe.marcas', {});
    expect(out).toContainEqual({
      value: 'Ford',
      label: 'Ford',
      meta: { codigo: '22' },
    });
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
    };
    const svc = new SubjectLookupService(fakeRedis(), broken);
    expect(await svc.lookup('fipe.marcas', {})).toEqual([]);
  });
});
