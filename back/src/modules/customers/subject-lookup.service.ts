import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import type Redis from 'ioredis';
import { REDIS } from '../../common/redis/redis.module';
import { SubjectLookupRegistry, type LookupOption } from './subject-lookup.registry';

export type { LookupOption } from './subject-lookup.registry';

/**
 * Autocomplete de campos de subject. GENÉRICO: este service sabe cachear,
 * filtrar e degradar — não sabe o que é FIPE nem o que é um carro. As fontes
 * chegam pelo `SubjectLookupRegistry`, preenchido pela vertical.
 *
 * Cache em Redis (24h); chamada externa NUNCA dentro de transação de banco;
 * degradação graciosa (fonte fora → []), o campo segue como texto livre.
 */
@Injectable()
export class SubjectLookupService {
  private static readonly TTL_SECONDS = 60 * 60 * 24;
  private static readonly LIMIT = 50;

  constructor(
    @Inject(REDIS) private readonly redis: Redis,
    private readonly registry: SubjectLookupRegistry,
  ) {}

  async lookup(
    fonte: string,
    params: { marca?: string; modelo?: string; q?: string },
  ): Promise<LookupOption[]> {
    const source = this.registry.achar(fonte);
    if (!source) {
      throw new NotFoundException('Fonte de autocomplete desconhecida.');
    }
    const all = await this.load(source.key, source, params.marca, params.modelo);
    return this.filter(all, params.q);
  }

  private async load(
    key: string,
    source: ReturnType<SubjectLookupRegistry['achar']> & object,
    marca: string | undefined,
    modelo: string | undefined,
  ): Promise<LookupOption[]> {
    // Cascata: a fonte declara de quem depende. Sem o ancestral preenchido não
    // há o que sugerir — e não vale gastar chamada externa para descobrir isso.
    for (const req of source.requer ?? []) {
      if (req === 'marca' && !marca) return [];
      if (req === 'modelo' && !modelo) return [];
    }

    // Cache GLOBAL (sem prefixo de tenant): fonte de autocomplete é dado público
    // de referência, não dado de tenant. Não reutilize este esquema para dados
    // tenant-scoped.
    const cacheKey = `lookup:${key}:${marca ?? '-'}:${modelo ?? '-'}`;
    const cached = await this.readCache(cacheKey);
    if (cached) return cached;

    let options: LookupOption[];
    try {
      options = await source.buscar({ marca, modelo });
    } catch {
      return []; // degradação graciosa: nunca trava o cadastro
    }

    await this.writeCache(cacheKey, options);
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
