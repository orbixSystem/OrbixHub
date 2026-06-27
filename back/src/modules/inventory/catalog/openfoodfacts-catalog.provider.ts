import { Injectable, Logger } from '@nestjs/common';
import { CatalogHit, CatalogProvider } from './catalog.provider';

/** Base pública do Open Food Facts. Não é segredo, não exige token. */
export const OPENFOODFACTS_BASE_URL = 'https://world.openfoodfacts.org';

/** OFF pede um User-Agent identificável em todas as chamadas. */
const OFF_USER_AGENT = 'OrbixHub - https://orbixhub';

/** Timeout da chamada externa (ms). */
const OFF_TIMEOUT_MS = 8000;

/** Subset relevante da resposta do Open Food Facts (mapeamento best-effort). */
interface OffProductResponse {
  status?: number;
  product?: {
    product_name?: string;
    generic_name?: string;
    brands?: string;
    categories?: string;
  } | null;
}

/**
 * Impl via `fetch` (Node 24), no mesmo estilo do provider Cosmos.
 * Chamada HTTP plana — NUNCA dentro de transação de banco. Degrada graciosamente:
 * não encontrado / 429 / erro de rede / parse → null (nunca lança).
 * API pública e grátis: não exige token. O kill-switch global (CATALOG_ENABLED) e a
 * validação do GTIN são aplicados pelo service ANTES de chamar o provider.
 */
@Injectable()
export class OpenFoodFactsCatalogProvider extends CatalogProvider {
  private readonly logger = new Logger(OpenFoodFactsCatalogProvider.name);

  constructor(private readonly baseUrl: string = OPENFOODFACTS_BASE_URL) {
    super();
  }

  async lookupByGtin(gtin: string): Promise<CatalogHit | null> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), OFF_TIMEOUT_MS);

    try {
      const res = await fetch(
        `${this.baseUrl}/api/v0/product/${encodeURIComponent(gtin)}.json`,
        {
          headers: {
            'User-Agent': OFF_USER_AGENT,
            Accept: 'application/json',
          },
          signal: controller.signal,
        },
      );

      if (res.status === 429) {
        this.logger.warn(`OFF rate-limit (429) para GTIN ${gtin}; degradando para none`);
        return null;
      }
      if (!res.ok) {
        this.logger.warn(`OFF HTTP ${res.status} para GTIN ${gtin}; degradando para none`);
        return null;
      }

      const body = (await res.json()) as OffProductResponse;
      if (body.status !== 1 || !body.product) return null; // não encontrado

      const product = body.product;
      const name = (product.product_name || product.generic_name || '').trim();
      if (!name) return null; // sem nome útil = não-encontrado

      const category =
        (product.categories || '')
          .split(',')
          .map((s) => s.trim())
          .filter(Boolean)[0] || undefined;

      return {
        name,
        brand: product.brands?.trim() || undefined,
        category,
        ncm: undefined,
      };
    } catch (err) {
      this.logger.warn(`OFF falhou para GTIN ${gtin}: ${String(err)}; degradando para none`);
      return null;
    } finally {
      clearTimeout(timeout);
    }
  }
}
