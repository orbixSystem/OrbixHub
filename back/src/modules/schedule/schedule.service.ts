import { BadRequestException, Injectable } from '@nestjs/common';
import { TenantContext } from '../../common/database/tenant-context';
import { AuditService } from '../../common/audit/audit.service';
import { SettingsSectionRegistry } from '../settings/settings.section-registry';
import { OsService } from '../os/os.service';
import { ScheduleRepository } from './schedule.repository';
import type { AgendaQueryDto, ScheduleItemDto, UpdateBusinessHoursDto } from './dto/schedule.dto';
import type { AuthUser } from '../../common/auth/auth.types';

const DAY_LABELS = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];

@Injectable()
export class ScheduleService {
  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: ScheduleRepository,
    private readonly os: OsService,
    private readonly audit: AuditService,
    private readonly registry: SettingsSectionRegistry,
  ) {}

  // Seção de Configurações REMOVIDA (era "Agenda & Horários de funcionamento").
  // Os horários continuam editáveis na TELA de horários, que é onde se mexe neles
  // de verdade — a seção só espelhava o resumo, e cartão que ninguém abre é ruído.
  // Para trazer de volta, re-registre a seção aqui (o repo já expõe o necessário).

  async getBusinessHours(user: AuthUser) {
    const rows = await this.tenant.withTenantTx(() =>
      this.repo.getBusinessHours(user.tenantId),
    );
    return rows.map((r) => ({
      id: r.id,
      dayOfWeek: r.day_of_week,
      dayLabel: DAY_LABELS[r.day_of_week],
      isOpen: r.is_open,
      openTime: r.open_time,
      closeTime: r.close_time,
    }));
  }

  async updateBusinessHours(user: AuthUser, day: number, dto: UpdateBusinessHoursDto) {
    if (day < 0 || day > 6) throw new BadRequestException('Dia inválido (0=Dom … 6=Sáb).');
    const row = await this.tenant.withTenantTx(() =>
      this.repo.upsertDay(user.tenantId, day, {
        is_open: dto.isOpen,
        open_time: dto.openTime,
        close_time: dto.closeTime,
      }),
    );
    await this.audit.log(user.tenantId, user.userId, 'schedule_hours_update', String(day), {
      isOpen: dto.isOpen,
      openTime: dto.openTime,
      closeTime: dto.closeTime,
    });
    return {
      id: row.id,
      dayOfWeek: row.day_of_week,
      dayLabel: DAY_LABELS[row.day_of_week],
      isOpen: row.is_open,
      openTime: row.open_time,
      closeTime: row.close_time,
    };
  }

  async getAgenda(user: AuthUser, query: AgendaQueryDto) {
    const from = new Date(query.from);
    const to = new Date(query.to);
    if (isNaN(from.getTime()) || isNaN(to.getTime()))
      throw new BadRequestException('Datas inválidas.');
    if (from >= to) throw new BadRequestException('"from" deve ser anterior a "to".');

    const items = await this.os.getAgendaItems(user, {
      from,
      to,
      assignedTo: query.assignedTo,
    });
    return { items };
  }

  async scheduleItem(
    user: AuthUser,
    orderId: string,
    itemId: string,
    dto: ScheduleItemDto,
  ) {
    const item = await this.os.scheduleItem(user, orderId, itemId, {
      assignedTo: dto.assignedTo,
      scheduledStart: dto.scheduledStart,
      estimatedDuration: dto.estimatedDuration,
    });
    await this.audit.log(user.tenantId, user.userId, 'schedule_item_assign', itemId, {
      orderId,
      assignedTo: dto.assignedTo,
      scheduledStart: dto.scheduledStart,
      estimatedDuration: dto.estimatedDuration,
    });
    return item;
  }

  async unscheduleItem(user: AuthUser, orderId: string, itemId: string) {
    const item = await this.os.unscheduleItem(user, orderId, itemId);
    await this.audit.log(user.tenantId, user.userId, 'schedule_item_unassign', itemId, { orderId });
    return item;
  }
}
