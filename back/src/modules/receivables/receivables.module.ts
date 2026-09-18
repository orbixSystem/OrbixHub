import { Module } from '@nestjs/common';
import { BillingModule } from '../billing/billing.module';
import { OsModule } from '../os/os.module';
import { SaleModule } from '../sale/sale.module';
import { CashierModule } from '../cashier/cashier.module';
import { CustomersModule } from '../customers/customers.module';
import { ReceivablesController } from './receivables.controller';
import { ReceivablesService } from './receivables.service';

/**
 * Módulo "A receber" (contas a receber) — ORQUESTRADOR puro: nenhuma tabela
 * própria, nenhuma migration, nenhuma permissão nova.
 *
 * Compõe os services públicos de OS e Vendas (que já derivam o pagamento do
 * caixa em batch) e agrupa a dívida por cliente. Do ponto de vista comercial é
 * parte do Caixa, então é gated por `@RequiresModule('cashier')` + `cashier.read`.
 *
 * `CashierModule` e `CustomersModule` entram como PORTAS estreitas (regra 1):
 * a próxima parcela em aberto de cada título, em lote, e o telefone dos
 * devedores cadastrados. Sem ciclo: OS/Sale → Cashier e este módulo → todos
 * eles; ninguém aponta de volta para cá. Mesmo desenho do módulo `sync`.
 */
@Module({
  imports: [
    BillingModule,
    OsModule,
    SaleModule,
    CashierModule,
    CustomersModule,
  ],
  controllers: [ReceivablesController],
  providers: [ReceivablesService],
  exports: [ReceivablesService],
})
export class ReceivablesModule {}
