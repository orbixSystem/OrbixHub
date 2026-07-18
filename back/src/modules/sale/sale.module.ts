import { Module } from '@nestjs/common';
import { BillingModule } from '../billing/billing.module';
import { CustomersModule } from '../customers/customers.module';
import { InventoryModule } from '../inventory/inventory.module';
import { CashierModule } from '../cashier/cashier.module';
import { SaleController } from './sale.controller';
import { SaleService } from './sale.service';
import { SaleRepository } from './sale.repository';

/**
 * Módulo Venda de balcão (`sale`) — entidade própria (NÃO é OS), plugada no
 * caixa/estoque já prontos via services públicos ("aponta, não invade"):
 * Inventory (baixa/estorno de estoque), Cashier (status de pagamento derivado),
 * Customers (snapshot do cliente — opcional). Contratável (@RequiresModule('sale')).
 *
 * NÃO há referência mútua sale↔caixa nem sale↔invoice: o caixa recebe o total do
 * dono da venda (caller-passes-total); a NOTA é emitida pelo módulo `invoice`
 * (POST /invoices { saleId }), que lê a venda via `getSaleWithItems` e espelha o
 * snapshot via `setFiscalSnapshot` — dependência one-way invoice→sale, sem
 * forwardRef. `SaleService` é exportado para `report` e `invoice`.
 */
@Module({
  imports: [
    BillingModule,
    CustomersModule,
    InventoryModule,
    CashierModule,
  ],
  controllers: [SaleController],
  providers: [SaleService, SaleRepository],
  exports: [SaleService],
})
export class SaleModule {}
