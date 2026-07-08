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

/** Parâmetros da página do relatório de clientes (scroll infinito): range + paginação. */
export interface CustomersReportPageParams extends CustomersMetricsParams {
  page: number;
  pageSize: number;
}

/**
 * Ponto da série do gráfico: novos clientes por dia (YYYY-MM-DD, calendário do
 * servidor) e por tipo (pf/pj/...). Agregada no banco — o gráfico da tela não
 * depende mais das linhas (que agora vêm paginadas).
 */
export interface CustomersSeriesPoint {
  day: string; // 'YYYY-MM-DD'
  type: string;
  count: number;
}

/**
 * Página do relatório de clientes (scroll infinito na tela): linhas da página +
 * `total`/`page`/`pageSize` + série agregada por dia/tipo (gráfico). Aqui
 * `newInRange` é o TOTAL de novos no período (== `total`), não o tamanho da página.
 */
export interface CustomersMetricsReportPage extends CustomersMetricsSummary {
  rows: CustomerReportRow[];
  total: number;
  page: number;
  pageSize: number;
  series: CustomersSeriesPoint[];
}
