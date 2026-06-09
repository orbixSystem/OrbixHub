import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import type Redis from 'ioredis';
import { REDIS } from '../../common/redis/redis.module';
import { FIPE_CLIENT, type FipeClient } from './fipe.client';

/** Opção devolvida ao front: `value` (texto salvo), `label` (exibido), `meta`. */
export interface LookupOption {
  value: string;
  label: string;
  meta?: Record<string, unknown>;
}

/**
 * Fontes de autocomplete para campos de subject. Mecanismo GENÉRICO: o módulo
 * só conhece chaves de fonte; a FIPE (casca de carro) entra via FipeClient.
 * Cache em Redis (24h); chamada externa NUNCA dentro de transação de banco;
 * degradação graciosa (FIPE fora → []), o campo segue como texto livre.
 */
@Injectable()
export class SubjectLookupService {
  private static readonly TTL_SECONDS = 60 * 60 * 24;
  private static readonly SOURCES = new Set(['fipe.marcas', 'fipe.modelos']);
  private static readonly LIMIT = 50;

  constructor(
    @Inject(REDIS) private readonly redis: Redis,
    @Inject(FIPE_CLIENT) private readonly fipe: FipeClient,
  ) {}

  async lookup(
    fonte: string,
    params: { marca?: string; q?: string },
  ): Promise<LookupOption[]> {
    if (!SubjectLookupService.SOURCES.has(fonte)) {
      throw new NotFoundException('Fonte de autocomplete desconhecida.');
    }
    const all = await this.load(fonte, params.marca);
    return this.filter(all, params.q);
  }

  private async load(
    fonte: string,
    marca: string | undefined,
  ): Promise<LookupOption[]> {
    // modelos dependem do código da marca; sem ele, nada a sugerir.
    if (fonte === 'fipe.modelos' && !marca) return [];

    // Cache GLOBAL (sem prefixo de tenant): FIPE é dado público de referência,
    // não dado de tenant. Não reutilize este esquema para dados tenant-scoped.
    const key = `lookup:${fonte}:${marca ?? '-'}`;
    const cached = await this.readCache(key);
    if (cached) return cached;

    let options: LookupOption[];
    try {
      options =
        fonte === 'fipe.marcas'
          ? (await this.fipe.brands()).map((b) => ({
              value: b.name,
              label: b.name,
              meta: { codigo: b.code },
            }))
          : (await this.fipe.models(marca as string)).map((m) => ({
              value: m.name,
              label: m.name,
            }));
    } catch {
      return []; // degradação graciosa: nunca trava o cadastro
    }

    await this.writeCache(key, options);
    return options;
  }

  private filter(
    options: LookupOption[],
    q: string | undefined,
  ): LookupOption[] {
    if (!q?.trim()) return options.slice(0, SubjectLookupService.LIMIT);
    const term = q.trim().toLowerCase();
    return options
      .filter((o) => o.label.toLowerCase().includes(term))
      .slice(0, SubjectLookupService.LIMIT);
  }

  private async readCache(key: string): Promise<LookupOption[] | null> {
    try {
      const raw = await this.redis.get(key);
      return raw ? (JSON.parse(raw) as LookupOption[]) : null;
    } catch {
      return null; // cache é best-effort
    }
  }

  private async writeCache(key: string, value: LookupOption[]): Promise<void> {
    try {
      await this.redis.set(
        key,
        JSON.stringify(value),
        'EX',
        SubjectLookupService.TTL_SECONDS,
      );
    } catch {
      /* best-effort */
    }
  }
}
