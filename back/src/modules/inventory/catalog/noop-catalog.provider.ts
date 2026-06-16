import { Injectable } from '@nestjs/common';
import { CatalogHit, CatalogProvider } from './catalog.provider';

/** Default — sempre vazio. Usado na fase de validação / quando CATALOG_ENABLED=false. */
@Injectable()
export class NoopCatalogProvider extends CatalogProvider {
  lookupByGtin(_gtin: string): Promise<CatalogHit | null> {
    return Promise.resolve(null);
  }
}
