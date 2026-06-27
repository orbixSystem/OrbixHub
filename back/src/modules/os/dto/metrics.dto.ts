import { IsIn, IsISO8601, IsOptional, IsUUID } from 'class-validator';
import { OS_STATUSES, type OsSort, type OsStatus } from './order.dto';

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

/** Parâmetros da página do relatório de OS (scroll infinito): range + filtros + paginação. */
export interface OsReportPageParams extends OsMetricsParams {
  page: number;
  pageSize: number;
  q?: string;
  sort?: OsSort;
}

/** Página do relatório de OS (linhas + total para o scroll infinito na tela). */
export interface OsReportPage {
  rows: OsReportRow[];
  total: number;
  page: number;
  pageSize: number;
}

/**
 * Parâmetros do relatório de OS COMPLETO (export) — mesmos filtros da página
 * (range + escopo + status + busca + ordenação), sem paginação.
 */
export interface OsReportAllParams extends OsMetricsParams {
  q?: string;
  sort?: OsSort;
}

// ---- Fase 2: lentes públicas sobre a OS (faturamento / equipe / top-itens) ----

/** Range simples (Date) — entrada das lentes de faturamento/equipe/top-itens. */
export interface OsRange {
  from: Date;
  to: Date;
}

/** Faturamento por dia (calendário do servidor) no range. */
export interface RevenueByDay {
  day: string; // 'YYYY-MM-DD'
  revenue: number;
  count: number;
}

/**
 * Série de faturamento: total + ticket médio + quebra por dia e por status, sobre
 * OS concluídas/entregues no range (data de conclusão = COALESCE(finished_at, closed_at)).
 */
export interface RevenueSeries {
  range: { from: string; to: string };
  total: number;
  avgTicket: number;
  byDay: RevenueByDay[];
  byStatus: Record<string, { count: number; revenue: number }>;
}

/** Linha do rendimento da equipe (agregada por responsável). */
export interface TeamPerformanceRow {
  assignedTo: string | null; // null = "Sem responsável"
  orders: number;
  completed: number;
  revenue: number;
  avgTicket: number;
  avgCycleMs: number | null;
}

/** Rendimento da equipe: linhas por responsável no range. */
export interface TeamPerformance {
  range: { from: string; to: string };
  rows: TeamPerformanceRow[];
}

/** Linha do top de produtos/serviços (agrega `service_order_item`). */
export interface TopItemRow {
  name: string;
  kind: string;
  inventoryItemId: string | null;
  qty: number;
  revenue: number;
  orders: number; // nº de OS distintas que usaram o item
}

/** Top de itens: linhas ordenadas por receita desc, limitadas. */
export interface TopItems {
  range: { from: string; to: string };
  kind: 'product' | 'service' | null;
  rows: TopItemRow[];
}

/** Query do top-itens (filtro de kind + limit) — Fase 2. */
export interface TopItemsParams extends OsRange {
  kind?: 'product' | 'service';
  limit?: number;
}
