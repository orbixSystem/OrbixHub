import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../../common/database/prisma.service';
import { CatalogHit } from './catalog.provider';

/** Janela de frescor: um hit servido do nosso banco vale por 60 dias. */
const FRESH_DAYS = 60;
const FRESH_MS = FRESH_DAYS * 24 * 60 * 60 * 1000;

/**
 * Cache durável e compartilhado de catálogo por GTIN. Lê/escreve a tabela GLOBAL
 * `catalog_product` (dado público de referência, sem RLS) — por isso usa o
 * PrismaService base direto, NÃO uma tenant tx. Substitui o antigo cache Redis:
 * um GTIN resolvido uma vez é servido do nosso banco até ficar obsoleto (60 dias),
 * sem martelar a API externa. Falhas de banco no `get` degradam para miss (null)
 * — problema de cache nunca quebra o lookup.
 */
@Injectable()
export class CatalogProductStore {
  constructor(private readonly prisma: PrismaService) {}

  /** Hit em cache se presente E buscado há ≤ 60 dias; senão null (miss/obsoleto). */
  async get(gtin: string): Promise<CatalogHit | null> {
    try {
      const row = await this.prisma.catalog_product.findUnique({
        where: { gtin },
      });
      if (!row) return null;
      const age = Date.now() - row.fetched_at.getTime();
      if (age > FRESH_MS) return null; // obsoleto → força nova consulta ao provider
      return CatalogProductStore.toHit(row);
    } catch {
      return null; // cache é best-effort; degrada para chamada ao provider
    }
  }

  /** Upsert por gtin; renova fetched_at = now(). `source` é informativo. */
  async upsert(gtin: string, hit: CatalogHit, source: string): Promise<void> {
    const now = new Date();
    const data = {
      name: hit.name,
      brand: hit.brand ?? null,
      ncm: hit.ncm ?? null,
      category: hit.category ?? null,
      source,
      fetched_at: now,
    };
    await this.prisma.catalog_product.upsert({
      where: { gtin },
      create: { gtin, ...data },
      update: data,
    });
  }

  private static toHit(row: {
    name: string;
    brand: string | null;
    ncm: string | null;
    category: string | null;
  }): CatalogHit {
    return {
      name: row.name,
      ...(row.brand ? { brand: row.brand } : {}),
      ...(row.ncm ? { ncm: row.ncm } : {}),
      ...(row.category ? { category: row.category } : {}),
    };
  }
}
