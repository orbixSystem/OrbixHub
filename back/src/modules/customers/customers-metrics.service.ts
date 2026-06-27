import { Injectable } from '@nestjs/common';
import { TenantContext } from '../../common/database/tenant-context';
import { CustomersRepository } from './customers.repository';
import {
  CustomersMetricsParams,
  CustomersMetricsReport,
  CustomersMetricsSummary,
  CustomerReportRow,
} from './dto/metrics.dto';

/**
 * Camada de métricas de Clientes — dona dos próprios agregados (só toca
 * `customer`, via repo, sob `withTenantTx`/RLS). Leitura: sem audit, sem I/O
 * externo. `metricsReport` é público para o módulo `report` (Fase 2).
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
}
