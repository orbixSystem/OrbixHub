import { BadRequestException, Injectable, OnModuleInit } from '@nestjs/common';
import { TenantContext } from '../../common/database/tenant-context';
import { AuditService } from '../../common/audit/audit.service';
import { SettingsSectionRegistry } from '../settings/settings.section-registry';
import { OsService } from '../os/os.service';
import { ScheduleRepository } from './schedule.repository';
import type { AgendaQueryDto, ScheduleItemDto, UpdateBusinessHoursDto } from './dto/schedule.dto';
import type { AuthUser } from '../../common/auth/auth.types';

const DAY_LABELS = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];

@Injectable()
export class ScheduleService implements OnModuleInit {
  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: ScheduleRepository,
    private readonly os: OsService,
    private readonly audit: AuditService,
    private readonly registry: SettingsSectionRegistry,
  ) {}

  onModuleInit() {
    this.registry.register({
      key: 'schedule',
      title: 'Agenda & Horários de funcionamento',
      moduleKey: 'os',
      fields: [
        { key: 'diasAbertos', label: 'Dias de funcionamento', type: 'text' },
        { key: 'horario', label: 'Horário padrão', type: 'text' },
      ],
      getValues: async (tenantId: string) => {
        const rows = await this.tenant.runWithTenant(tenantId, () =>
          this.repo.getBusinessHours(tenantId),
        );
        const open = rows.filter((r) => r.is_open);
        const diasAbertos = open.length === 0
          ? 'Nenhum dia configurado'
          : open.map((r) => DAY_LABELS[r.day_of_week].slice(0, 3)).join(', ');

        // Horário representativo: intervalo mais comum entre os dias abertos
        const horarios = open
          .filter((r) => r.open_time && r.close_time)
          .map((r) => `${r.open_time} às ${r.close_time}`);
        const unique = [...new Set(horarios)];
        const horario = unique.length === 0 ? '—' : unique.length === 1 ? unique[0] : unique.join(' / ');

        return { diasAbertos, horario };
      },
    });
  }

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
