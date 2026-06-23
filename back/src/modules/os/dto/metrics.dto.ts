import { IsIn, IsISO8601, IsOptional, IsUUID } from 'class-validator';
import { OS_STATUSES, type OsStatus } from './order.dto';

/**
 * Query da camada de métricas da OS. `from`/`to` são ISO 8601 (datas); quando
 * omitidos, o service aplica o default (últimos 30 dias). `assignedTo` escopa as
 * contagens a um mecânico (dashboard "minhas OS"). Whitelist via ValidationPipe.
 */
export class OsMetricsQueryDto {
  @IsOptional() @IsISO8601() from?: string;
  @IsOptional() @IsISO8601() to?: string;
  @IsOptional() @IsUUID() assignedTo?: string;
  /** Filtro adicional do relatório (Fase 2) — não usado pelo summary. */
  @IsOptional() @IsIn(OS_STATUSES) status?: OsStatus;
}

/** Resolved range (Date) + filtros normalizados — entrada dos métodos públicos. */
export interface OsMetricsParams {
  from: Date;
  to: Date;
  assignedTo?: string;
  status?: OsStatus;
}

/** KPIs glanceáveis para o Dashboard. */
export interface OsMetricsSummary {
  range: { from: string; to: string };
  byStatus: Record<string, number>;
  revenue: number;
  avgTicket: number;
  inExecution: number;
  overdue: number;
  avgCycleMs: number | null;
}

/** Linha detalhada do relatório (Fase 2). */
export interface OsReportRow {
  id: string;
  number: string;
  customer_name: string;
  status: string;
  assigned_to: string | null;
  total: number;
  opened_at: string;
  finished_at: string | null;
  cycleMs: number | null;
}

/** Relatório detalhado: linhas + agregados por status e por técnico (Fase 2). */
export interface OsMetricsReport extends OsMetricsSummary {
  rows: OsReportRow[];
  byAssignedTo: Record<string, { count: number; revenue: number }>;
}
