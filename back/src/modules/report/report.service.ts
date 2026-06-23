import { Injectable, NotFoundException } from '@nestjs/common';
import { BillingService } from '../billing/billing.service';
import { OsMetricsService } from '../os/os-metrics.service';
import { InventoryMetricsService } from '../inventory/inventory-metrics.service';
import { CustomersMetricsService } from '../customers/customers-metrics.service';
import type {
  OsMetricsParams,
  RevenueSeries,
  TeamPerformance,
  TopItems,
  OsMetricsReport,
} from '../os/dto/metrics.dto';
import type { InventoryMetricsReport } from '../inventory/dto/metrics.dto';
import type {
  CustomersMetricsParams,
  CustomersMetricsReport,
} from '../customers/dto/metrics.dto';

interface Range {
  from: Date;
  to: Date;
}

/**
 * Serviço do módulo `report` — COMPÕE relatórios chamando apenas os métodos
 * públicos das camadas de métrica de cada módulo (`OsMetricsService`,
 * `InventoryMetricsService`, `CustomersMetricsService`). Regra "aponta, não
 * invade": NUNCA injeta repository/PrismaService nem toca tabela alheia. Cada
 * relatório só é servido se o módulo-fonte estiver habilitado no tenant
 * (via `BillingService.getEnabledModules`); senão → 404 (recurso indisponível).
 * Leitura: sem audit, sem I/O externo.
 */
@Injectable()
export class ReportService {
  constructor(
    private readonly billing: BillingService,
    private readonly os: OsMetricsService,
    private readonly inventory: InventoryMetricsService,
    private readonly customers: CustomersMetricsService,
  ) {}

  /** Garante que o módulo-fonte do relatório está habilitado para o tenant. */
  private async assertModuleEnabled(
    tenantId: string,
    moduleKey: string,
  ): Promise<void> {
    const enabled = await this.billing.getEnabledModules(tenantId);
    if (!enabled.includes(moduleKey)) {
      throw new NotFoundException(
        `Relatório indisponível: módulo '${moduleKey}' não habilitado`,
      );
    }
  }

  async osReport(
    tenantId: string,
    p: OsMetricsParams,
  ): Promise<OsMetricsReport> {
    await this.assertModuleEnabled(tenantId, 'os');
    return this.os.metricsReport(p);
  }

  async revenue(tenantId: string, range: Range): Promise<RevenueSeries> {
    await this.assertModuleEnabled(tenantId, 'os');
    return this.os.revenueSeries(range);
  }

  async team(tenantId: string, range: Range): Promise<TeamPerformance> {
    await this.assertModuleEnabled(tenantId, 'os');
    return this.os.teamPerformance(range);
  }

  async topItems(
    tenantId: string,
    p: Range & { kind?: 'product' | 'service'; limit?: number },
  ): Promise<TopItems> {
    await this.assertModuleEnabled(tenantId, 'os');
    return this.os.topItems(p);
  }

  async inventory_(tenantId: string): Promise<InventoryMetricsReport> {
    await this.assertModuleEnabled(tenantId, 'inventory');
    return this.inventory.metricsReport();
  }

  async customersReport(
    tenantId: string,
    p: CustomersMetricsParams,
  ): Promise<CustomersMetricsReport> {
    await this.assertModuleEnabled(tenantId, 'customers');
    return this.customers.metricsReport(p);
  }
}
