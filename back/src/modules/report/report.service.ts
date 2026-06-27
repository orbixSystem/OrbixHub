import { Injectable, NotFoundException } from '@nestjs/common';
import { BillingService } from '../billing/billing.service';
import { OsMetricsService } from '../os/os-metrics.service';
import { InventoryMetricsService } from '../inventory/inventory-metrics.service';
import { CustomersMetricsService } from '../customers/customers-metrics.service';
import { EmployeesService } from '../iam/employees.service';
import type {
  RevenueSeries,
  TeamPerformance,
  TopItems,
  OsReportAllParams,
  OsReportPage,
  OsReportPageParams,
} from '../os/dto/metrics.dto';
import type { InventoryMetricsReportPage } from '../inventory/dto/metrics.dto';
import {
  buildInventoryCsv,
  buildInventoryPdf,
  type ExportCompany,
} from './export/inventory-export';
import { buildOsCsv, buildOsPdf } from './export/os-export';
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
    private readonly employees: EmployeesService,
  ) {}

  /**
   * Mapa {userId → nome} dos membros ativos (mesma fonte do dropdown "Técnico" e
   * do front), para resolver o `assigned_to` (uuid) no export de OS. "aponta, não
   * invade": via service público do IAM, nunca a tabela. Membro inativo/removido
   * fica fora do mapa → o export rotula "—" (igual ao front).
   */
  private async memberNameMap(): Promise<Map<string, string>> {
    const members = await this.employees.listAssignableMembers();
    const map = new Map<string, string>();
    for (const m of members) if (m.fullName) map.set(m.userId, m.fullName);
    return map;
  }

  /** Rótulo "dd/mm/aaaa – dd/mm/aaaa" do período (cabeçalho do PDF). */
  private periodLabel(from: Date, to: Date): string {
    const fmt = (d: Date): string =>
      d.toLocaleDateString('pt-BR', { timeZone: 'America/Sao_Paulo' });
    return `${fmt(from)} – ${fmt(to)}`;
  }

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

  /** OS operacional PAGINADA (scroll infinito na tela): linhas da página + total. */
  async osReport(
    tenantId: string,
    p: OsReportPageParams,
  ): Promise<OsReportPage> {
    await this.assertModuleEnabled(tenantId, 'os');
    return this.os.metricsReportPage(p);
  }

  /** CSV do relatório COMPLETO de OS (respeita os filtros ativos). Buffer pronto. */
  async osCsv(tenantId: string, p: OsReportAllParams): Promise<Buffer> {
    await this.assertModuleEnabled(tenantId, 'os');
    const [rows, names] = await Promise.all([
      this.os.metricsReportAll(p),
      this.memberNameMap(),
    ]);
    return buildOsCsv(rows, names);
  }

  /** PDF do relatório COMPLETO de OS (respeita os filtros ativos). Buffer pronto. */
  async osPdf(
    tenantId: string,
    p: OsReportAllParams,
    company?: ExportCompany,
  ): Promise<Buffer> {
    await this.assertModuleEnabled(tenantId, 'os');
    const [rows, names] = await Promise.all([
      this.os.metricsReportAll(p),
      this.memberNameMap(),
    ]);
    return buildOsPdf(rows, names, {
      company,
      periodLabel: this.periodLabel(p.from, p.to),
    });
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

  /** Posição de estoque PAGINADA (tela). stockValue é o total global. */
  async inventoryPage(
    tenantId: string,
    p: { page: number; pageSize: number; q?: string },
  ): Promise<InventoryMetricsReportPage> {
    await this.assertModuleEnabled(tenantId, 'inventory');
    return this.inventory.metricsReportPage(p);
  }

  /** CSV do relatório completo de estoque (Buffer pronto p/ download). */
  async inventoryCsv(tenantId: string, q?: string): Promise<Buffer> {
    await this.assertModuleEnabled(tenantId, 'inventory');
    const report = await this.inventory.metricsReport(q);
    return buildInventoryCsv(report);
  }

  /** PDF do relatório completo de estoque (Buffer pronto p/ download). */
  async inventoryPdf(
    tenantId: string,
    company?: ExportCompany,
    q?: string,
  ): Promise<Buffer> {
    await this.assertModuleEnabled(tenantId, 'inventory');
    const report = await this.inventory.metricsReport(q);
    return buildInventoryPdf(report, company);
  }

  async customersReport(
    tenantId: string,
    p: CustomersMetricsParams,
  ): Promise<CustomersMetricsReport> {
    await this.assertModuleEnabled(tenantId, 'customers');
    return this.customers.metricsReport(p);
  }
}
