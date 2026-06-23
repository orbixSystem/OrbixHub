import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { TenantContext } from '../../common/database/tenant-context';
import { InventoryRepository } from './inventory.repository';
import {
  InventoryMetricsReport,
  InventoryMetricsReportPage,
  InventoryMetricsSummary,
  InventoryReportRow,
} from './dto/metrics.dto';

/** Item cru do relatório (subset selecionado no repo). */
interface RawReportItem {
  id: string;
  name: string;
  sku: string | null;
  current_stock: Prisma.Decimal | number;
  min_stock: Prisma.Decimal | number | null;
  cost_price: Prisma.Decimal | number | null;
  sale_price: Prisma.Decimal | number | null;
}

const toNum = (d: Prisma.Decimal | number | null | undefined): number =>
  d == null ? 0 : typeof d === 'number' ? d : d.toNumber();

const toNumOrNull = (
  d: Prisma.Decimal | number | null | undefined,
): number | null => (d == null ? null : toNum(d));

const round2 = (n: number): number => Math.round(n * 100) / 100;

const LOW_STOCK_SAMPLE = 5;

/**
 * Camada de métricas do Estoque — dona dos próprios agregados (só toca
 * `inventory_item`, via repo, sob `withTenantTx`/RLS). Sem histórico de
 * movimento (não há tabela `inventory_movement`). Leitura: sem audit, sem I/O
 * externo. `metricsReport` é público para o módulo `report` (Fase 2).
 */
@Injectable()
export class InventoryMetricsService {
  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: InventoryRepository,
  ) {}

  async metricsSummary(): Promise<InventoryMetricsSummary> {
    const [belowMin, stockValue, products, services, lowStockSample] =
      await this.tenant.withTenantTx(() =>
        Promise.all([
          this.repo.countBelowMin(),
          this.repo.stockValue(),
          this.repo.countActive('product'),
          this.repo.countActive('service'),
          this.repo.sampleBelowMin(LOW_STOCK_SAMPLE),
        ]),
      );

    return {
      belowMin,
      stockValue: round2(stockValue),
      products,
      services,
      lowStockSample: lowStockSample.map((i) => ({
        id: i.id,
        name: i.name,
        sku: i.sku,
        current_stock: toNum(i.current_stock),
        min_stock: toNumOrNull(i.min_stock),
      })),
    };
  }

  /** Mapeia um item cru para a linha do relatório (valor = saldo × custo). */
  private toReportRow(i: RawReportItem): InventoryReportRow {
    const current = toNum(i.current_stock);
    const cost = toNumOrNull(i.cost_price);
    const min = toNumOrNull(i.min_stock);
    return {
      id: i.id,
      name: i.name,
      sku: i.sku,
      current_stock: current,
      min_stock: min,
      cost_price: cost,
      sale_price: toNumOrNull(i.sale_price),
      stockValue: round2(current * (cost ?? 0)),
      belowMin: min != null && current < min,
    };
  }

  /** Relatório completo (export): TODAS as linhas + valor total em estoque. */
  async metricsReport(q?: string): Promise<InventoryMetricsReport> {
    const raw = await this.tenant.withTenantTx(() =>
      this.repo.listForReport(q),
    );
    const rows = raw.map((i) => this.toReportRow(i));
    const stockValue = rows.reduce((a, r) => a + r.stockValue, 0);
    return { rows, stockValue: round2(stockValue) };
  }

  /**
   * Uma página do relatório (tela). O `stockValue` é o valor GLOBAL (agregação
   * sob RLS no banco — não só a página), para o KPI ficar correto paginando.
   */
  async metricsReportPage(p: {
    page: number;
    pageSize: number;
    q?: string;
  }): Promise<InventoryMetricsReportPage> {
    const page = Math.max(1, Math.trunc(p.page) || 1);
    const pageSize = Math.min(200, Math.max(1, Math.trunc(p.pageSize) || 50));
    const { rows, total, stockValue } = await this.tenant.withTenantTx(
      async () => {
        const [pageData, value] = await Promise.all([
          this.repo.listForReportPage({
            skip: (page - 1) * pageSize,
            take: pageSize,
            q: p.q,
          }),
          this.repo.stockValue(),
        ]);
        return {
          rows: pageData.items,
          total: pageData.total,
          stockValue: value,
        };
      },
    );

    return {
      rows: rows.map((i) => this.toReportRow(i)),
      total,
      page,
      pageSize,
      stockValue: round2(stockValue),
    };
  }
}
