import type { Provider } from '@nestjs/common';
import { ENV } from '../../../common/config/config.module';
import type { Env } from '../../../common/config/env.schema';
import { CATALOG_PROVIDER, CatalogProvider } from './catalog.provider';
import { CosmosCatalogProvider } from './cosmos-catalog.provider';
import { NoopCatalogProvider } from './noop-catalog.provider';

/**
 * Factory de DI keyed em CATALOG_PROVIDER — mesmo padrão do PAYMENT_GATEWAY do
 * Billing. O futuro InventoryModule só inclui isto em `providers`. Mantido aqui
 * (peça reutilizável) sem fazer wiring de controller/service ainda.
 */
export const catalogProviderFactory: Provider = {
  provide: CATALOG_PROVIDER,
  inject: [ENV],
  useFactory: (env: Env): CatalogProvider =>
    env.CATALOG_PROVIDER === 'cosmos'
      ? new CosmosCatalogProvider(env)
      : new NoopCatalogProvider(),
};
