import { forwardRef, Module } from '@nestjs/common';
import { BillingModule } from '../billing/billing.module';
import { CashierModule } from '../cashier/cashier.module';
import { CustomersModule } from '../customers/customers.module';
import { InventoryModule } from '../inventory/inventory.module';
import { MessagesModule } from '../messages/messages.module';
import { IamModule } from '../iam/iam.module';
import { TenancyModule } from '../tenancy/tenancy.module';
import { OsController } from './os.controller';
import { OsPublicController } from './os-public.controller';
import { OsService } from './os.service';
import { OsMetricsService } from './os-metrics.service';
import { OsPublicService } from './os-public.service';
import { OsTrackingService } from './os-tracking.service';
import { OsRepository } from './os.repository';
import { OsSubjectHistoryProvider } from './os-subject-history.provider';
import { OrderLockRegistry } from './order-lock.registry';

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
    CashierModule,
    forwardRef(() => CustomersModule),
    InventoryModule,
    MessagesModule,
    IamModule,
    // Nome/e-mail da oficina para o e-mail do link de acompanhamento
    // (TenancyService.getCompanyView — sem tocar a tabela `tenant`).
    TenancyModule,
  ],
  controllers: [OsController, OsPublicController],
  providers: [
    OsService,
    OsMetricsService,
    OsPublicService,
    OsTrackingService,
    OsRepository,
    OsSubjectHistoryProvider,
    OrderLockRegistry,
  ],
  // Exporta o provider de histórico para o CustomersModule plugá-lo no seam
  // SubjectHistoryProvider (forwardRef — dependência mútua). OsPublicService é
  // exportado para o RealtimeModule resolver a sala de um token público.
  // OrderLockRegistry sai para que os módulos donos de documentos amarrados a
  // uma OS (hoje `invoice`) registrem o impedimento deles em reabrir/excluir.
  exports: [
    OsService,
    OsMetricsService,
    OsSubjectHistoryProvider,
    OsPublicService,
    OrderLockRegistry,
  ],
})
export class OsModule {}
