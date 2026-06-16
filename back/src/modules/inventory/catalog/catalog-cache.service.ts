import { Inject, Injectable } from '@nestjs/common';
import type Redis from 'ioredis';
import { REDIS } from '../../../common/redis/redis.module';
import { CatalogHit } from './catalog.provider';

/** Sentinela para "não está em cache" (distingue de hit nulo = cache negativo). */
export const CACHE_MISS = 'miss' as const;
export type CacheResult = CatalogHit | null | typeof CACHE_MISS;

/**
 * Cache best-effort de lookups por GTIN no Redis. Guarda hits positivos E
 * negativos (cache negativo evita martelar o provider externo em GTIN inexistente).
 * Falha de Redis nunca propaga — degrada para miss/no-op.
 */
@Injectable()
export class CatalogCacheService {
  private static readonly DEFAULT_TTL_SECONDS = 86_400; // 24h

  constructor(@Inject(REDIS) private readonly redis: Redis) {}

  private static key(gtin: string): string {
    return `catalog:gtin:${gtin}`;
  }

  /** Hit em cache, null (cache negativo) ou CACHE_MISS quando não cacheado. */
  async get(gtin: string): Promise<CacheResult> {
    try {
      const raw = await this.redis.get(CatalogCacheService.key(gtin));
      if (raw === null) return CACHE_MISS;
      return JSON.parse(raw) as CatalogHit | null;
    } catch {
      return CACHE_MISS; // cache é best-effort
    }
  }

  /** Cacheia resultado positivo (CatalogHit) OU negativo (null), JSON, TTL 24h. */
  async set(
    gtin: string,
    hit: CatalogHit | null,
    ttlSeconds = CatalogCacheService.DEFAULT_TTL_SECONDS,
  ): Promise<void> {
    try {
      await this.redis.set(
        CatalogCacheService.key(gtin),
        JSON.stringify(hit),
        'EX',
        ttlSeconds,
      );
    } catch {
      /* best-effort */
    }
  }
}
