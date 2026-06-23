import { forwardRef, Module } from '@nestjs/common';
import { BillingModule } from '../billing/billing.module';
import { CustomersModule } from '../customers/customers.module';
import { InventoryModule } from '../inventory/inventory.module';
import { MessagesModule } from '../messages/messages.module';
import { IamModule } from '../iam/iam.module';
import { OsController } from './os.controller';
import { OsPublicController } from './os-public.controller';
import { OsService } from './os.service';
import { OsMetricsService } from './os-metrics.service';
import { OsPublicService } from './os-public.service';
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
  imports: [
    BillingModule,
    forwardRef(() => CustomersModule),
    InventoryModule,
    MessagesModule,
    IamModule,
  ],
  controllers: [OsController, OsPublicController],
  providers: [
    OsService,
    OsMetricsService,
    OsPublicService,
    OsRepository,
    OsSubjectHistoryProvider,
  ],
  // Exporta o provider de histórico para o CustomersModule plugá-lo no seam
  // SubjectHistoryProvider (forwardRef — dependência mútua). OsPublicService é
  // exportado para o RealtimeModule resolver a sala de um token público.
  exports: [OsService, OsMetricsService, OsSubjectHistoryProvider, OsPublicService],
})
export class OsModule {}
