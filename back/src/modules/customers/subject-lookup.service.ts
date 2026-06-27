import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import type Redis from 'ioredis';
import { REDIS } from '../../common/redis/redis.module';
import { FIPE_CLIENT, brandLogoUrl, type FipeClient } from './fipe.client';

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
  private static readonly SOURCES = new Set([
    'fipe.marcas',
    'fipe.modelos',
    'fipe.anos',
  ]);
  private static readonly LIMIT = 50;

  constructor(
    @Inject(REDIS) private readonly redis: Redis,
    @Inject(FIPE_CLIENT) private readonly fipe: FipeClient,
  ) {}

  async lookup(
    fonte: string,
    params: { marca?: string; modelo?: string; q?: string },
  ): Promise<LookupOption[]> {
    if (!SubjectLookupService.SOURCES.has(fonte)) {
      throw new NotFoundException('Fonte de autocomplete desconhecida.');
    }
    const all = await this.load(fonte, params.marca, params.modelo);
    return this.filter(all, params.q);
  }

  private async load(
    fonte: string,
    marca: string | undefined,
    modelo: string | undefined,
  ): Promise<LookupOption[]> {
    // Cascata: modelos exigem a marca; anos exigem marca + modelo. Sem os
    // códigos do ancestral, não há o que sugerir.
    if (fonte === 'fipe.modelos' && !marca) return [];
    if (fonte === 'fipe.anos' && (!marca || !modelo)) return [];

    // Cache GLOBAL (sem prefixo de tenant): FIPE é dado público de referência,
    // não dado de tenant. Não reutilize este esquema para dados tenant-scoped.
    const key = `lookup:${fonte}:${marca ?? '-'}:${modelo ?? '-'}`;
    const cached = await this.readCache(key);
    if (cached) return cached;

    let options: LookupOption[];
    try {
      options = await this.fetchSource(fonte, marca, modelo);
    } catch {
      return []; // degradação graciosa: nunca trava o cadastro
    }

    await this.writeCache(key, options);
    return options;
  }

  /** Mapeia cada fonte FIPE para opções genéricas (casca de carro isolada). */
  private async fetchSource(
    fonte: string,
    marca: string | undefined,
    modelo: string | undefined,
  ): Promise<LookupOption[]> {
    if (fonte === 'fipe.marcas') {
      return (await this.fipe.brands()).map((b) => ({
        value: b.name,
        label: b.name,
        meta: { codigo: b.code, logoUrl: brandLogoUrl(b.name) },
      }));
    }
    if (fonte === 'fipe.modelos') {
      return (await this.fipe.models(marca as string)).map((m) => ({
        value: m.name,
        label: m.name,
        meta: { codigo: m.code },
      }));
    }
    // fipe.anos: o nome da FIPE vem "2024 Gasolina" / "32000 Gasolina" (zero km).
    // Mostramos só o ano, deduplicado entre combustíveis; 32000 vira "0 km".
    const seen = new Set<string>();
    const out: LookupOption[] = [];
    for (const y of await this.fipe.years(marca as string, modelo as string)) {
      const head = y.name.split(' ')[0];
      const label = head === '32000' ? '0 km' : head;
      if (seen.has(label)) continue;
      seen.add(label);
      out.push({ value: label, label });
    }
    return out;
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
