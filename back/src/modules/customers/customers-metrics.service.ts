import { Injectable } from '@nestjs/common';
import { TenantContext } from '../../common/database/tenant-context';
import { CustomersRepository } from './customers.repository';
import {
  CustomersMetricsParams,
  CustomersMetricsReport,
  CustomersMetricsReportPage,
  CustomersMetricsSummary,
  CustomersReportPageParams,
  CustomerReportRow,
} from './dto/metrics.dto';

/**
 * Camada de métricas de Clientes — dona dos próprios agregados (só toca
 * `customer`, via repo, sob `withTenantTx`/RLS). Leitura: sem audit, sem I/O
 * externo. `metricsReportPage` (tela paginada) e `metricsReport` (export
 * completo) são públicos para o módulo `report` (Fase 2).
 */
@Injectable()
export class CustomersMetricsService {
  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: CustomersRepository,
  ) {}

  async metricsSummary(
    p: CustomersMetricsParams,
  ): Promise<CustomersMetricsSummary> {
    const [active, newInRange] = await this.tenant.withTenantTx(() =>
      Promise.all([
        this.repo.countActive(),
        this.repo.countNewInRange(p.from, p.to),
      ]),
    );
    return {
      range: { from: p.from.toISOString(), to: p.to.toISOString() },
      active,
      newInRange,
    };
  }

  async metricsReport(
    p: CustomersMetricsParams,
  ): Promise<CustomersMetricsReport> {
    const [active, raw] = await this.tenant.withTenantTx(() =>
      Promise.all([
        this.repo.countActive(),
        this.repo.listNewInRange(p.from, p.to),
      ]),
    );
    const rows: CustomerReportRow[] = raw.map((c) => ({
      id: c.id,
      name: c.name,
      type: c.type,
      created_at: c.created_at.toISOString(),
    }));
    return {
      range: { from: p.from.toISOString(), to: p.to.toISOString() },
      active,
      newInRange: rows.length,
      rows,
    };
  }

  /**
   * Relatório PAGINADO (scroll infinito na tela): linhas da página + total +
   * série por dia/tipo (gráfico independe da paginação). `newInRange` é o TOTAL
   * de novos no período — não o tamanho da página. Sob withTenantTx/RLS.
   */
  async metricsReportPage(
    p: CustomersReportPageParams,
  ): Promise<CustomersMetricsReportPage> {
    const page = p.page > 0 ? p.page : 1;
    const pageSize = p.pageSize > 0 ? p.pageSize : 50;
    const [active, pageResult, series] = await this.tenant.withTenantTx(() =>
      Promise.all([
        this.repo.countActive(),
        this.repo.listNewInRangePage(
          p.from,
          p.to,
          (page - 1) * pageSize,
          pageSize,
        ),
        this.repo.newInRangeSeries(p.from, p.to),
      ]),
    );
    const rows: CustomerReportRow[] = pageResult.rows.map((c) => ({
      id: c.id,
      name: c.name,
      type: c.type,
      created_at: c.created_at.toISOString(),
    }));
    return {
      range: { from: p.from.toISOString(), to: p.to.toISOString() },
      active,
      newInRange: pageResult.total,
      rows,
      total: pageResult.total,
      page,
      pageSize,
      series,
    };
  }
}
