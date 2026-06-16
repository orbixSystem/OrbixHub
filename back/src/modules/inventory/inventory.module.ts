import { Module, OnModuleInit } from '@nestjs/common';
import { BillingModule } from '../billing/billing.module';
import { SettingsModule } from '../settings/settings.module';
import { SettingsSectionRegistry } from '../settings/settings.section-registry';
import { InventoryController } from './inventory.controller';
import { InventoryService } from './inventory.service';
import { InventoryRepository } from './inventory.repository';
import { INVENTORY_CONFIG_KEY } from './inventory.config';

/**
 * Módulo Estoque & Serviços — catálogo de itens (produto/serviço) + movimentações.
 * Genérico/multi-vertical. Importa BillingModule (config em tenant_module.settings +
 * ModuleAccessGuard) e SettingsModule (registra a própria seção de config no host).
 * Exporta InventoryService para a futura OS consumir ("aponta, não invade").
 */
@Module({
  imports: [BillingModule, SettingsModule],
  controllers: [InventoryController],
  providers: [InventoryService, InventoryRepository],
  exports: [InventoryService],
})
export class InventoryModule implements OnModuleInit {
  constructor(private readonly registry: SettingsSectionRegistry) {}

  onModuleInit(): void {
    this.registry.register({
      key: INVENTORY_CONFIG_KEY,
      title: 'Estoque & Serviços',
      moduleKey: 'inventory',
      fields: [
        { key: 'defaultUnit', label: 'Unidade padrão', type: 'text' },
        { key: 'trackStockDefault', label: 'Rastrear estoque por padrão?', type: 'bool' },
        { key: 'defaultMarginPercent', label: 'Margem padrão (%)', type: 'text' },
      ],
    });
  }
}
