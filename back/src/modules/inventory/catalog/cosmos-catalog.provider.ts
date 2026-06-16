import { Inject, Injectable, Logger } from '@nestjs/common';
import { ENV } from '../../../common/config/config.module';
import type { Env } from '../../../common/config/env.schema';
import { CatalogHit, CatalogProvider } from './catalog.provider';

/** Base pública do Cosmos (Bluesoft). Não é segredo. */
export const COSMOS_BASE_URL = 'https://api.cosmos.bluesoft.com.br';

/** Subset relevante da resposta do Cosmos GTIN (mapeamento best-effort). */
interface CosmosGtinResponse {
  description?: string;
  brand?: { name?: string } | null;
  ncm?: { code?: string } | null;
  gpc?: { description?: string } | null;
}

/**
 * Impl real-ish via `fetch` (Node 24), no mesmo estilo do FIPE client.
 * Chamada HTTP plana — NUNCA dentro de transação de banco. Degrada graciosamente:
 * desligado / sem token / 429 / erro de rede → null (nunca lança).
 */
@Injectable()
export class CosmosCatalogProvider extends CatalogProvider {
  private readonly logger = new Logger(CosmosCatalogProvider.name);

  constructor(
    @Inject(ENV) private readonly env: Env,
    private readonly baseUrl: string = COSMOS_BASE_URL,
  ) {
    super();
  }

  async lookupByGtin(gtin: string): Promise<CatalogHit | null> {
    // Kill-switch / segredo ausente → não chama fora.
    if (!this.env.CATALOG_ENABLED || !this.env.COSMOS_TOKEN) return null;

    try {
      const res = await fetch(`${this.baseUrl}/gtins/${encodeURIComponent(gtin)}`, {
        headers: {
          'X-Cosmos-Token': this.env.COSMOS_TOKEN,
          Accept: 'application/json',
        },
      });

      if (res.status === 404) return null; // não encontrado
      if (res.status === 429) {
        this.logger.warn(`Cosmos rate-limit (429) para GTIN ${gtin}; degradando para none`);
        return null;
      }
      if (!res.ok) {
        this.logger.warn(`Cosmos HTTP ${res.status} para GTIN ${gtin}; degradando para none`);
        return null;
      }

      const body = (await res.json()) as CosmosGtinResponse;
      const name = body.description?.trim();
      if (!name) return null; // sem nome útil = não-encontrado

      return {
        name,
        brand: body.brand?.name?.trim() || undefined,
        ncm: body.ncm?.code?.trim() || undefined,
        category: body.gpc?.description?.trim() || undefined,
      };
    } catch (err) {
      this.logger.warn(`Cosmos falhou para GTIN ${gtin}: ${String(err)}; degradando para none`);
      return null;
    }
  }
}
