import { Module, OnModuleInit } from '@nestjs/common';
import { BillingModule } from '../billing/billing.module';
import { SettingsModule } from '../settings/settings.module';
import { SettingsSectionRegistry } from '../settings/settings.section-registry';
import { InventoryController } from './inventory.controller';
import { InventoryService } from './inventory.service';
import { InventoryMetricsService } from './inventory-metrics.service';
import { InventoryRepository } from './inventory.repository';
import { CatalogProductStore } from './catalog/catalog-product.store';
import { catalogProviderFactory } from './catalog/catalog.providers';
import { INVENTORY_CONFIG_KEY } from './inventory.config';

/**
 * Módulo Estoque & Produtos — catálogo de produtos (decimal) + fluxo código-first
 * (lookup com CatalogProvider + cache durável `catalog_product`). Genérico/multi-vertical.
 * Importa BillingModule (config em `tenant_module.settings` + ModuleAccessGuard) e
 * SettingsModule (registra a própria seção de config no host). O env tipado
 * (catalogProviderFactory) e o PrismaService (CatalogProductStore, tabela global sem
 * RLS) vêm dos módulos globais (ConfigModule/DatabaseModule). Exporta InventoryService
 * para a futura OS consumir ("aponta, não invade").
 */
@Module({
  imports: [BillingModule, SettingsModule],
  controllers: [InventoryController],
  providers: [
    InventoryService,
    InventoryMetricsService,
    InventoryRepository,
    CatalogProductStore,
    catalogProviderFactory,
  ],
  exports: [InventoryService, InventoryMetricsService],
})
export class InventoryModule implements OnModuleInit {
  constructor(private readonly registry: SettingsSectionRegistry) {}

  onModuleInit(): void {
    // Seção aparece em GET /settings só se o módulo `inventory` estiver habilitado.
    // `itemFields` é lista rica, gerida pelos endpoints próprios (GET/PATCH
    // /inventory/config) — mesmo split do customers/subjectFields, então a seção
    // host não tem campos escalares.
    this.registry.register({
      key: INVENTORY_CONFIG_KEY,
      title: 'Estoque & Produtos',
      moduleKey: 'inventory',
      fields: [],
    });
  }
}
