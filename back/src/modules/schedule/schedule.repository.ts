import { Injectable } from '@nestjs/common';
import { TenantContext } from '../../common/database/tenant-context';

export interface UpsertDayData {
  is_open: boolean;
  open_time: string;
  close_time: string;
}

const DEFAULT_DAYS: UpsertDayData[] = [
  { is_open: false, open_time: '08:00', close_time: '18:00' }, // 0 = Dom
  { is_open: true,  open_time: '08:00', close_time: '18:00' }, // 1 = Seg
  { is_open: true,  open_time: '08:00', close_time: '18:00' }, // 2 = Ter
  { is_open: true,  open_time: '08:00', close_time: '18:00' }, // 3 = Qua
  { is_open: true,  open_time: '08:00', close_time: '18:00' }, // 4 = Qui
  { is_open: true,  open_time: '08:00', close_time: '18:00' }, // 5 = Sex
  { is_open: false, open_time: '08:00', close_time: '12:00' }, // 6 = Sáb
];

/**
 * Único ponto que toca `business_hours`. Sempre via `tenant.getClient()`
 * (cliente tx-scoped sob RLS). Tenant_id vem sempre do CLS/JWT.
 */
@Injectable()
export class ScheduleRepository {
  constructor(private readonly tenant: TenantContext) {}

  /** Lista os 7 dias do horário de funcionamento do tenant (cria padrões se ainda não existirem). */
  async getBusinessHours(tenantId: string) {
    const db = this.tenant.getClient();
    // Lazy init: garante que os 7 dias existam (idempotente via createMany skipDuplicates).
    await db.business_hours.createMany({
      data: DEFAULT_DAYS.map((d, i) => ({ tenant_id: tenantId, day_of_week: i, ...d })),
      skipDuplicates: true,
    });
    return db.business_hours.findMany({
      where: {},
      orderBy: { day_of_week: 'asc' },
    });
  }

  /** Atualiza (upsert) um dia do horário de funcionamento. */
  upsertDay(tenantId: string, dayOfWeek: number, data: UpsertDayData) {
    const db = this.tenant.getClient();
    return db.business_hours.upsert({
      where: { tenant_id_day_of_week: { tenant_id: tenantId, day_of_week: dayOfWeek } },
      create: { tenant_id: tenantId, day_of_week: dayOfWeek, ...data },
      update: { ...data, updated_at: new Date() },
    });
  }
}
