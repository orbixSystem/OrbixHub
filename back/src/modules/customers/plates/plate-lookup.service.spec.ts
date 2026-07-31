import {
  BadRequestException,
  HttpException,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import type { AuthUser } from '../../../common/auth/auth.types';
import type { Env } from '../../../common/config/env.schema';
import type { AuditService } from '../../../common/audit/audit.service';
import type { PlateCacheStore } from './plate-cache.store';
import type { PlateQuotaStore } from './plate-quota.store';
import { PlateLookupService } from './plate-lookup.service';
import {
  normalizePlate,
  PlateHit,
  PlateLookupOutcome,
  PlateProvider,
} from './plate.provider';

const user: AuthUser = {
  userId: 'u1',
  tenantId: 't1',
  role: 'owner',
  jti: 'j1',
};

const hit: PlateHit = { placa: 'ABC1D23', marca: 'VW', modelo: 'CROSSFOX' };

/** Provider fake com resultado programável e contador de chamadas. */
class FakeProvider extends PlateProvider {
  calls = 0;
  constructor(private readonly outcome: PlateLookupOutcome) {
    super();
  }
  lookup(): Promise<PlateLookupOutcome> {
    this.calls += 1;
    return Promise.resolve(this.outcome);
  }
}

function makeService(opts: {
  outcome?: PlateLookupOutcome;
  cached?: PlateHit | null;
  used?: number;
  limit?: number;
  enabled?: boolean;
}) {
  const used = opts.used ?? 0;
  const limit = opts.limit ?? 1000;
  const cache = {
    get: jest.fn().mockResolvedValue(opts.cached ?? null),
    upsert: jest.fn().mockResolvedValue(undefined),
  };
  const quota = {
    tryConsume: jest
      .fn()
      .mockResolvedValue(used + 1 <= limit ? used + 1 : null),
    refund: jest.fn().mockResolvedValue(undefined),
    used: jest.fn().mockResolvedValue(used),
  };
  const audit = { log: jest.fn().mockResolvedValue(undefined) };
  const provider = new FakeProvider(opts.outcome ?? { status: 'ok', hit });
  const env = {
    PLACAS_ENABLED: opts.enabled ?? true,
    PLACAS_TOKEN: opts.enabled === false ? undefined : 'tok',
    PLACAS_MONTHLY_LIMIT: limit,
  } as unknown as Env;
  const svc = new PlateLookupService(
    cache as unknown as PlateCacheStore,
    quota as unknown as PlateQuotaStore,
    audit as unknown as AuditService,
    provider,
    env,
  );
  return { svc, cache, quota, audit, provider };
}

describe('normalizePlate', () => {
  it('aceita antiga e Mercosul, normalizando maiúsculas/separadores', () => {
    expect(normalizePlate('abc-1234')).toBe('ABC1234');
    expect(normalizePlate('abc1d23')).toBe('ABC1D23');
  });
  it('rejeita formatos inválidos', () => {
    expect(normalizePlate('AB1234')).toBeNull();
    expect(normalizePlate('ABCD123')).toBeNull();
    expect(normalizePlate('usage')).toBeNull();
  });
});

describe('PlateLookupService.lookup', () => {
  it('placa inválida → 400 sem tocar cache, cota ou provider', async () => {
    const { svc, cache, quota, provider } = makeService({});
    await expect(svc.lookup(user, 'ZZZ')).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(cache.get).not.toHaveBeenCalled();
    expect(quota.tryConsume).not.toHaveBeenCalled();
    expect(provider.calls).toBe(0);
  });

  it('cache fresco → serve do banco SEM consumir cota nem chamar o provider', async () => {
    const { svc, quota, provider } = makeService({ cached: hit, used: 7 });
    const res = await svc.lookup(user, 'abc1d23');
    expect(res.cached).toBe(true);
    expect(res.marca).toBe('VW');
    expect(res.usage.used).toBe(7);
    expect(quota.tryConsume).not.toHaveBeenCalled();
    expect(provider.calls).toBe(0);
  });

  it('miss + sucesso → consome cota, grava cache, audita e devolve usage', async () => {
    const { svc, cache, quota, audit } = makeService({ used: 7 });
    const res = await svc.lookup(user, 'ABC1D23');
    expect(res.cached).toBe(false);
    expect(quota.tryConsume).toHaveBeenCalledWith(expect.any(String), 1000);
    expect(cache.upsert).toHaveBeenCalledWith('ABC1D23', hit, 'apiplacas');
    expect(audit.log).toHaveBeenCalledWith(
      't1',
      'u1',
      'plate_lookup',
      'ABC1D23',
      expect.objectContaining({ used: 8 }),
    );
  });

  it('cota mensal estourada → 429 e NÃO chama o provider', async () => {
    const { svc, provider, quota } = makeService({ used: 1000, limit: 1000 });
    await expect(svc.lookup(user, 'ABC1D23')).rejects.toMatchObject({
      status: 429,
    });
    expect(provider.calls).toBe(0);
    expect(quota.refund).not.toHaveBeenCalled();
  });

  it('provider indisponível → 503 e DEVOLVE a cota reservada', async () => {
    const { svc, quota } = makeService({ outcome: { status: 'unavailable' } });
    await expect(svc.lookup(user, 'ABC1D23')).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
    expect(quota.tryConsume).toHaveBeenCalled();
    expect(quota.refund).toHaveBeenCalled();
  });

  it('sem resultados (406) → 404 e MANTÉM o consumo (provedor cobrou)', async () => {
    const { svc, quota, cache } = makeService({
      outcome: { status: 'not_found' },
    });
    await expect(svc.lookup(user, 'ABC1D23')).rejects.toBeInstanceOf(
      NotFoundException,
    );
    expect(quota.refund).not.toHaveBeenCalled();
    expect(cache.upsert).not.toHaveBeenCalled();
  });

  it('limite do provedor (429 lá) → 429 aqui e devolve a cota local', async () => {
    const { svc, quota } = makeService({
      outcome: { status: 'provider_limit' },
    });
    await expect(svc.lookup(user, 'ABC1D23')).rejects.toBeInstanceOf(
      HttpException,
    );
    expect(quota.refund).toHaveBeenCalled();
  });

  it('não configurado (sem token) → 503 antes de reservar cota', async () => {
    const { svc, quota } = makeService({ enabled: false });
    await expect(svc.lookup(user, 'ABC1D23')).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
    expect(quota.tryConsume).not.toHaveBeenCalled();
  });
});

describe('PlateLookupService.usage', () => {
  it('reporta período, usado, limite e restante', async () => {
    const { svc } = makeService({ used: 250, limit: 1000 });
    const usage = await svc.usage();
    expect(usage.used).toBe(250);
    expect(usage.remaining).toBe(750);
    expect(usage.limit).toBe(1000);
    expect(usage.period).toMatch(/^\d{4}-\d{2}$/);
    expect(usage.enabled).toBe(true);
  });
});
