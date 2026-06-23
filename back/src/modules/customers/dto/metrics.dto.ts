import { IsISO8601, IsOptional } from 'class-validator';

/**
 * Query da camada de métricas de clientes. `from`/`to` ISO opcionais (default:
 * últimos 30 dias, resolvido no controller). Whitelist via ValidationPipe.
 */
export class CustomersMetricsQueryDto {
  @IsOptional() @IsISO8601() from?: string;
  @IsOptional() @IsISO8601() to?: string;
}

/** Range resolvido (Date) — entrada dos métodos públicos. */
export interface CustomersMetricsParams {
  from: Date;
  to: Date;
}

/** KPIs glanceáveis de clientes para o Dashboard. */
export interface CustomersMetricsSummary {
  range: { from: string; to: string };
  active: number;
  newInRange: number;
}

/** Linha de cliente novo no range (relatório — Fase 2). */
export interface CustomerReportRow {
  id: string;
  name: string;
  type: string;
  created_at: string;
}

/** Relatório de clientes: novos no range + total ativo (Fase 2). */
export interface CustomersMetricsReport extends CustomersMetricsSummary {
  rows: CustomerReportRow[];
}
