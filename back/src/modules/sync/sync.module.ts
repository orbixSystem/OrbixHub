import { Module } from '@nestjs/common';
import { CustomersModule } from '../customers/customers.module';
import { InventoryModule } from '../inventory/inventory.module';
import { OsModule } from '../os/os.module';
import { CashierModule } from '../cashier/cashier.module';
import { SyncController } from './sync.controller';
import { SyncService } from './sync.service';
import { SyncRepository } from './sync.repository';

/**
 * Módulo `sync` (offline-first) — pull incremental + push idempotente. Compõe os
 * services públicos dos 4 módulos donos (customers, inventory, os, cashier) via
 * `imports` — "aponta, não invade": nunca toca as tabelas deles. `AuditService`
 * e `TenantContext` vêm dos módulos globais (Audit/Database).
 */
@Module({
  imports: [CustomersModule, InventoryModule, OsModule, CashierModule],
  controllers: [SyncController],
  providers: [SyncService, SyncRepository],
})
export class SyncModule {}
