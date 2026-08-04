import { Module } from '@nestjs/common';
import { CustomersModule } from '../customers/customers.module';
import { InventoryModule } from '../inventory/inventory.module';
import { OsModule } from '../os/os.module';
import { MessagesModule } from '../messages/messages.module';
import { CashierModule } from '../cashier/cashier.module';
import { SaleModule } from '../sale/sale.module';
import { ExpensesModule } from '../expenses/expenses.module';
import { BillingModule } from '../billing/billing.module';
import { SyncController } from './sync.controller';
import { SyncService } from './sync.service';
import { SyncRepository } from './sync.repository';

/**
 * Módulo `sync` (offline-first) — pull incremental + push idempotente. Compõe os
 * services públicos dos módulos donos (customers, inventory, os, cashier, sale,
 * messages) via `imports` — "aponta, não invade": nunca toca as tabelas deles. `AuditService`
 * e `TenantContext` vêm dos módulos globais (Audit/Database).
 */
@Module({
  imports: [
    CustomersModule,
    InventoryModule,
    OsModule,
    CashierModule,
    // Venda de balcão: pull (`sale`/`sale_item`) + push (criar/cancelar) — o
    // SaleModule exporta o SaleService.
    SaleModule,
    // Só PULL de `conversation`/`message` (leitura offline do histórico) — o
    // MessagesModule exporta o MessagesService.
    MessagesModule,
    // Despesas: pull das 3 tabelas + push (criar/editar/baixar/estornar) — o
    // ExpensesModule exporta o ExpensesService.
    ExpensesModule,
    // Gating comercial por entidade (o /sync não usa @RequiresModule) — via o
    // service público do billing, nunca lendo `tenant_module` aqui.
    BillingModule,
  ],
  controllers: [SyncController],
  providers: [SyncService, SyncRepository],
})
export class SyncModule {}
