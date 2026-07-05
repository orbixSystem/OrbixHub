import { Module } from '@nestjs/common';
import { BillingModule } from '../billing/billing.module';
import { SettingsModule } from '../settings/settings.module';
import { OsModule } from '../os/os.module';
import { ScheduleController } from './schedule.controller';
import { ScheduleService } from './schedule.service';
import { ScheduleRepository } from './schedule.repository';

/**
 * Módulo de Agenda & Horários — parte do produto `os`.
 *
 * Responsabilidades:
 * - CRUD de `business_hours` (horário de funcionamento do tenant, 7 dias/semana).
 * - Agendamento de itens de OS: atribuição de técnico + janela de tempo.
 * - Checagem de conflito de agenda por técnico.
 * - Vista de agenda (itens agendados num período).
 *
 * Regras:
 * - Gated por @RequiresModule('os') + ModuleAccessGuard.
 * - Acesso a `service_order_item` via OsService (service público — nunca direto).
 * - `business_hours` é propriedade deste módulo; usa RLS como todas as tabelas de tenant.
 */
@Module({
  imports: [BillingModule, SettingsModule, OsModule],
  controllers: [ScheduleController],
  providers: [ScheduleService, ScheduleRepository],
  exports: [ScheduleService],
})
export class ScheduleModule {}
