import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { TenantContext } from '../../common/database/tenant-context';
import { InventoryRepository } from './inventory.repository';
import {
  InventoryMetricsReport,
  InventoryMetricsSummary,
  InventoryReportRow,
} from './dto/metrics.dto';

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

  async metricsReport(): Promise<InventoryMetricsReport> {
    const raw = await this.tenant.withTenantTx(() => this.repo.listForReport());

    let stockValue = 0;
    const rows: InventoryReportRow[] = raw.map((i) => {
      const current = toNum(i.current_stock);
      const cost = toNumOrNull(i.cost_price);
      const min = toNumOrNull(i.min_stock);
      const value = round2(current * (cost ?? 0));
      stockValue += value;
      return {
        id: i.id,
        name: i.name,
        sku: i.sku,
        current_stock: current,
        min_stock: min,
        cost_price: cost,
        sale_price: toNumOrNull(i.sale_price),
        stockValue: value,
        belowMin: min != null && current < min,
      };
    });

    return { rows, stockValue: round2(stockValue) };
  }
}
