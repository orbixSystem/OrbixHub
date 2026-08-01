import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../common/database/prisma.service';
import { PlateHit } from './plate.provider';

/**
 * Janela de frescor: dados de emplacamento mudam raramente (cor/município podem
 * mudar numa transferência) — 30 dias equilibra frescor × economia de cota.
 */
const FRESH_DAYS = 30;
const FRESH_MS = FRESH_DAYS * 24 * 60 * 60 * 1000;

/**
 * Cache durável e compartilhado de consultas por placa. Lê/escreve a tabela
 * GLOBAL `plate_cache` (dado público de referência, sem RLS) — por isso usa o
 * PrismaService base direto, NÃO uma tenant tx (padrão CatalogProductStore).
 * Uma placa resolvida uma vez é servida do nosso banco por 30 dias, sem gastar
 * a cota mensal da API. Falha de banco no `get` degrada para miss (null) —
 * problema de cache nunca quebra a consulta.
 */
@Injectable()
export class PlateCacheStore {
  constructor(private readonly prisma: PrismaService) {}

  /** Hit em cache se presente E buscado há ≤ 30 dias; senão null (miss/obsoleto). */
  async get(plate: string): Promise<PlateHit | null> {
    try {
      const row = await this.prisma.plate_cache.findUnique({ where: { plate } });
      if (!row) return null;
      const age = Date.now() - row.fetched_at.getTime();
      if (age > FRESH_MS) return null; // obsoleto → força nova consulta
      return row.payload as unknown as PlateHit;
    } catch {
      return null; // cache é best-effort; degrada para chamada ao provider
    }
  }

  /** Upsert por placa; renova fetched_at = now(). `source` é informativo. */
  async upsert(plate: string, hit: PlateHit, source: string): Promise<void> {
    const payload = hit as unknown as Prisma.InputJsonValue;
    await this.prisma.plate_cache.upsert({
      where: { plate },
      create: { plate, payload, source, fetched_at: new Date() },
      update: { payload, source, fetched_at: new Date() },
    });
  }
}
