import { Module } from '@nestjs/common';
import { BillingModule } from '../billing/billing.module';
import { CustomersModule } from '../customers/customers.module';
import { InventoryModule } from '../inventory/inventory.module';
import { CashierModule } from '../cashier/cashier.module';
import { InvoiceModule } from '../invoice/invoice.module';
import { SaleController } from './sale.controller';
import { SaleService } from './sale.service';
import { SaleRepository } from './sale.repository';

/**
 * Módulo Venda de balcão (`sale`) — entidade própria (NÃO é OS), plugada no
 * caixa/estoque/fiscal já prontos via services públicos ("aponta, não invade"):
 * Inventory (baixa/estorno de estoque), Cashier (status de pagamento derivado),
 * Invoice (emissão de nota; Fiscal é dono do status), Customers (snapshot do
 * cliente — opcional). Contratável (gated por @RequiresModule('sale')).
 *
 * NÃO há referência mútua sale↔caixa: o caixa recebe o total do dono da venda
 * (caller-passes-total), nunca chama de volta a `sale` — por isso sem forwardRef.
 * `SaleService` é exportado para o relatório (módulo `report`) compor a receita
 * (receita = OS + sale) via `getSaleValue`/`revenueSummary`.
 */
@Module({
  imports: [
    BillingModule,
    CustomersModule,
    InventoryModule,
    CashierModule,
    InvoiceModule,
  ],
  controllers: [SaleController],
  providers: [SaleService, SaleRepository],
  exports: [SaleService],
})
export class SaleModule {}
