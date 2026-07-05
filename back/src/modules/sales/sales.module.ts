import { Module } from '@nestjs/common';
import { BillingModule } from '../billing/billing.module';
import { CustomersModule } from '../customers/customers.module';
import { InventoryModule } from '../inventory/inventory.module';
import { SalesController } from './sales.controller';
import { SalesService } from './sales.service';
import { SalesRepository } from './sales.repository';

/**
 * Módulo Vendas (caixa) — venda avulsa de produto ao cliente, fora da OS.
 * Contratável (@RequiresModule('sales')). Importa BillingModule (ModuleAccessGuard),
 * InventoryModule (baixa de estoque) e CustomersModule (snapshot do cliente) —
 * services públicos, "aponta, não invade".
 */
@Module({
  imports: [BillingModule, InventoryModule, CustomersModule],
  controllers: [SalesController],
  providers: [SalesService, SalesRepository],
  exports: [SalesService],
})
export class SalesModule {}
