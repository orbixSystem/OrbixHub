/** Token de DI para a abstração (permite trocar Noop/Cosmos/fake em teste). */
export const CATALOG_PROVIDER = Symbol('CATALOG_PROVIDER');

export interface CatalogHit {
  name: string;
  brand?: string;
  ncm?: string;
  category?: string;
}

export abstract class CatalogProvider {
  /** Resolve um GTIN no catálogo externo. null = não encontrado/desligado. */
  abstract lookupByGtin(gtin: string): Promise<CatalogHit | null>;
}
