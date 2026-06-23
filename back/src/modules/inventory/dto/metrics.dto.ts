/** Item curto abaixo do mínimo (amostra do dashboard). */
export interface LowStockItem {
  id: string;
  name: string;
  sku: string | null;
  current_stock: number;
  min_stock: number | null;
}

/** KPIs glanceáveis do estoque para o Dashboard. */
export interface InventoryMetricsSummary {
  belowMin: number;
  stockValue: number;
  products: number;
  services: number;
  lowStockSample: LowStockItem[];
}

/** Linha do relatório de posição (Fase 2). */
export interface InventoryReportRow {
  id: string;
  name: string;
  sku: string | null;
  current_stock: number;
  min_stock: number | null;
  cost_price: number | null;
  sale_price: number | null;
  stockValue: number;
  belowMin: boolean;
}

/** Relatório de posição: linhas + valor total em estoque (Fase 2). */
export interface InventoryMetricsReport {
  rows: InventoryReportRow[];
  stockValue: number;
}
