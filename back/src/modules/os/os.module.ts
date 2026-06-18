import { forwardRef, Module } from '@nestjs/common';
import { BillingModule } from '../billing/billing.module';
import { CustomersModule } from '../customers/customers.module';
import { InventoryModule } from '../inventory/inventory.module';
import { OsController } from './os.controller';
import { OsService } from './os.service';
import { OsRepository } from './os.repository';
import { OsSubjectHistoryProvider } from './os-subject-history.provider';

/**
 * Módulo Ordens de Serviço (OS) — núcleo (Fase 1): cabeçalho + itens, workflow de
 * status, totais e integração "aponta, não invade" com customers (snapshot
 * cliente/veículo) e inventory (snapshot de preço + baixa automática na conclusão).
 * Contratável (gated por @RequiresModule('os')). Importa BillingModule
 * (ModuleAccessGuard), CustomersModule e InventoryModule (services públicos).
 */
@Module({
  imports: [BillingModule, forwardRef(() => CustomersModule), InventoryModule],
  controllers: [OsController],
  providers: [OsService, OsRepository, OsSubjectHistoryProvider],
  // Exporta o provider de histórico para o CustomersModule plugá-lo no seam
  // SubjectHistoryProvider (forwardRef — dependência mútua).
  exports: [OsService, OsSubjectHistoryProvider],
})
export class OsModule {}
