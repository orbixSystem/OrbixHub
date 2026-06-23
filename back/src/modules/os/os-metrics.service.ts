import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { TenantContext } from '../../common/database/tenant-context';
import { OsRepository } from './os.repository';
import {
  OsMetricsParams,
  OsMetricsReport,
  OsMetricsSummary,
  OsReportRow,
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
}
