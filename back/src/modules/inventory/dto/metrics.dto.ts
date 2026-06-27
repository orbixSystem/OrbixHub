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

/** Uma página do relatório de posição: linhas da página + total + valor global. */
export interface InventoryMetricsReportPage {
  rows: InventoryReportRow[];
  /** Total de itens (todas as páginas) — para o paginador. */
  total: number;
  page: number;
  pageSize: number;
  /** Valor total em estoque (todas as páginas, não só a página atual). */
  stockValue: number;
}
