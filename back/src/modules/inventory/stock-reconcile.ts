export type StockMovementReason = 'os_consumption' | 'os_reversal';

export interface ReconcileResult {
  /** Valor a somar ao current_stock: negativo = consumo (saída), positivo = estorno (entrada). */
  stockDelta: number;
  reason: StockMovementReason;
}

/**
 * Calcula o movimento de estoque necessário para levar o consumo já registrado
 * de uma linha (`prevConsumed`) até o consumo desejado (`targetConsumed`).
 * Função pura e idempotente: alvo igual ao atual → null (nenhum movimento).
 */
export function computeReconcile(
  prevConsumed: number,
  targetConsumed: number,
): ReconcileResult | null {
  const deltaConsumed = targetConsumed - prevConsumed;
  if (deltaConsumed === 0) return null;
  return {
    stockDelta: -deltaConsumed,
    reason: deltaConsumed > 0 ? 'os_consumption' : 'os_reversal',
  };
}
