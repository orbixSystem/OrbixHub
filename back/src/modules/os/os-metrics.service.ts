import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { TenantContext } from '../../common/database/tenant-context';
import { OsRepository } from './os.repository';
import {
  OsMetricsParams,
  OsMetricsReport,
  OsMetricsSummary,
  OsRange,
  OsReportRow,
  RevenueSeries,
  TeamPerformance,
  TopItems,
  TopItemsParams,
} from './dto/metrics.dto';

const toNum = (d: Prisma.Decimal | number | null | undefined): number =>
  d == null ? 0 : typeof d === 'number' ? d : d.toNumber();

const round2 = (n: number): number => Math.round(n * 100) / 100;

const cycleMs = (
  started: Date | null,
  finished: Date | null,
): number | null =>
  started && finished ? finished.getTime() - started.getTime() : null;

/**
 * Camada de métricas da OS — DONA dos próprios agregados (regra "aponta, não
 * invade": só toca `service_order`, via repo, sob `withTenantTx`/RLS). Leitura:
 * sem audit, sem I/O externo. `metricsSummary` alimenta o Dashboard (núcleo);
 * `metricsReport` é público para o módulo `report` chamar in-process (Fase 2).
 */
@Injectable()
export class OsMetricsService {
  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: OsRepository,
  ) {}

  /** KPIs glanceáveis no range [from, to] (opcionalmente por técnico). */
  async metricsSummary(p: OsMetricsParams): Promise<OsMetricsSummary> {
    const range = { from: p.from, to: p.to, assignedTo: p.assignedTo };
    const [byStatusRows, revenueAgg, inExecution, overdue, avgCycleMs] =
      await this.tenant.withTenantTx(() =>
        Promise.all([
          this.repo.groupByStatus(range),
          this.repo.revenueAgg(range),
          this.repo.countInExecution(range),
          this.repo.countOverdue(range),
          this.repo.avgCycleMs(range),
        ]),
      );

    const byStatus: Record<string, number> = {};
    for (const r of byStatusRows) byStatus[r.status] = r._count._all;

    const revenue = round2(toNum(revenueAgg._sum.total));
    const concluded = revenueAgg._count._all;
    const avgTicket = concluded > 0 ? round2(revenue / concluded) : 0;

    return {
      range: { from: p.from.toISOString(), to: p.to.toISOString() },
      byStatus,
      revenue,
      avgTicket,
      inExecution,
      overdue,
      avgCycleMs,
    };
  }

  /**
   * Relatório detalhado: linhas + agregados por status e por técnico. Público —
   * o módulo `report` (Fase 2) chama isto in-process (nunca a tabela).
   */
  async metricsReport(p: OsMetricsParams): Promise<OsMetricsReport> {
    const summary = await this.metricsSummary(p);
    const range = { from: p.from, to: p.to, assignedTo: p.assignedTo };
    const raw = await this.tenant.withTenantTx(() =>
      this.repo.listForReport({ ...range, status: p.status }),
    );

    const rows: OsReportRow[] = raw.map((o) => ({
      id: o.id,
      number: o.number,
      customer_name: o.customer_name,
      status: o.status,
      assigned_to: o.assigned_to,
      total: toNum(o.total),
      opened_at: o.opened_at.toISOString(),
      finished_at: o.finished_at ? o.finished_at.toISOString() : null,
      cycleMs: cycleMs(o.started_at, o.finished_at),
    }));

    const byAssignedTo: Record<string, { count: number; revenue: number }> = {};
    for (const r of rows) {
      const key = r.assigned_to ?? 'unassigned';
      const acc = byAssignedTo[key] ?? { count: 0, revenue: 0 };
      acc.count += 1;
      if (r.status === 'concluida' || r.status === 'entregue')
        acc.revenue = round2(acc.revenue + r.total);
      byAssignedTo[key] = acc;
    }

    return { ...summary, rows, byAssignedTo };
  }

  // ---- Fase 2: lentes públicas para o módulo `report` (chamadas in-process) ----

  /**
   * Série de faturamento no range: total (Σ total de concluída+entregue), ticket
   * médio, quebra por dia (data de conclusão = COALESCE(finished_at, closed_at),
   * dia-calendário do servidor) e por status. Sob withTenantTx/RLS; sem I/O.
   */
  async revenueSeries(p: OsRange): Promise<RevenueSeries> {
    const range = { from: p.from, to: p.to };
    const [byDayRows, byStatusRows] = await this.tenant.withTenantTx(() =>
      Promise.all([
        this.repo.revenueByDay(range),
        this.repo.revenueByStatus(range),
      ]),
    );

    const byDay = byDayRows.map((r) => ({
      day: r.day,
      revenue: round2(toNum(r.revenue)),
      count: Number(r.count),
    }));

    const byStatus: Record<string, { count: number; revenue: number }> = {};
    let total = 0;
    let count = 0;
    for (const r of byStatusRows) {
      const revenue = round2(toNum(r.revenue));
      const c = Number(r.count);
      byStatus[r.status] = { count: c, revenue };
      total = round2(total + revenue);
      count += c;
    }
    const avgTicket = count > 0 ? round2(total / count) : 0;

    return {
      range: { from: p.from.toISOString(), to: p.to.toISOString() },
      total,
      avgTicket,
      byDay,
      byStatus,
    };
  }

  /**
   * Rendimento por responsável no range (OS abertas no range): nº de OS,
   * concluídas, faturamento das concluídas, ticket médio e ciclo médio (ms).
   * Responsável nulo → linha `assignedTo: null` (front rotula "Sem responsável").
   */
  async teamPerformance(p: OsRange): Promise<TeamPerformance> {
    const raw = await this.tenant.withTenantTx(() =>
      this.repo.teamPerformance({ from: p.from, to: p.to }),
    );
    const rows = raw.map((r) => {
      const completed = Number(r.completed);
      const revenue = round2(toNum(r.revenue));
      return {
        assignedTo: r.assigned_to,
        orders: Number(r.orders),
        completed,
        revenue,
        avgTicket: completed > 0 ? round2(revenue / completed) : 0,
        avgCycleMs: r.avg_cycle_ms == null ? null : Number(r.avg_cycle_ms),
      };
    });
    return {
      range: { from: p.from.toISOString(), to: p.to.toISOString() },
      rows,
    };
  }

  /**
   * Top de produtos/serviços usados nas OS abertas no range, agregando
   * `service_order_item`. Ordena por receita desc, limita a `limit` (default 20).
   * `kind` filtra produto/serviço quando dado. Sob withTenantTx/RLS; sem I/O.
   */
  async topItems(p: TopItemsParams): Promise<TopItems> {
    const limit = p.limit && p.limit > 0 ? p.limit : 20;
    const raw = await this.tenant.withTenantTx(() =>
      this.repo.topItems({ from: p.from, to: p.to, kind: p.kind, limit }),
    );
    const rows = raw.map((r) => ({
      name: r.name,
      kind: r.kind,
      inventoryItemId: r.inventory_item_id,
      qty: round2(toNum(r.qty)),
      revenue: round2(toNum(r.revenue)),
      orders: Number(r.orders),
    }));
    return {
      range: { from: p.from.toISOString(), to: p.to.toISOString() },
      kind: p.kind ?? null,
      rows,
    };
  }
}
