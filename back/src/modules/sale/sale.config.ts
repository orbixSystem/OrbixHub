/**
 * Config + tipos + helpers PUROS do módulo Venda (balcão). A venda é entidade
 * própria (NÃO é OS); o pagamento é derivado do Caixa e a nota é disparada via
 * Fiscal — a `sale` nunca toca tabela alheia ("aponta, não invade"). As funções
 * de cálculo são puras (sem Nest) para serem testadas isoladamente.
 */

export const SALE_MODULE_KEY = 'sale';

export type SaleStatus = 'active' | 'canceled';
export type SaleItemKind = 'product' | 'service';

/** Arredonda a 2 casas (centavos), evitando ruído de ponto flutuante. */
export function round2(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100;
}

/** Subtotal de uma linha (qty × preço), nunca negativo. */
export function computeSubtotal(quantity: number, unitPrice: number): number {
  return round2(Math.max(0, quantity * unitPrice));
}

/** Total da venda = Σ subtotais (≥ 0). Pura — base do total persistido. */
export function computeSaleTotal(
  items: Array<{ quantity: number; unitPrice: number }>,
): number {
  return round2(
    items.reduce(
      (acc, it) => acc + computeSubtotal(it.quantity, it.unitPrice),
      0,
    ),
  );
}

/** Número sequencial da venda (VND-NNNN). */
export function formatSaleNumber(seq: number): string {
  return `VND-${String(seq).padStart(4, '0')}`;
}
