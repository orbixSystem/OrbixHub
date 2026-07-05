export type StockMovementReason =
  | 'os_consumption'
  | 'os_reversal'
  | 'sale_consumption'
  | 'sale_reversal';

/** Origem do consumo — define o prefixo do `reason` gravado no diário. */
export type ReconcileSource = 'os' | 'sale';

export interface ReconcileResult {
  /** Valor a somar ao current_stock: negativo = consumo (saída), positivo = estorno (entrada). */
  stockDelta: number;
  reason: StockMovementReason;
}

/**
 * Calcula o movimento de estoque necessário para levar o consumo já registrado
 * de uma linha (`prevConsumed`) até o consumo desejado (`targetConsumed`).
 * Função pura e idempotente: alvo igual ao atual → null (nenhum movimento).
 * `source` só rotula o motivo no diário (os_* | sale_*) — a matemática é a mesma.
 */
export function computeReconcile(
  prevConsumed: number,
  targetConsumed: number,
  source: ReconcileSource = 'os',
): ReconcileResult | null {
  const deltaConsumed = targetConsumed - prevConsumed;
  if (deltaConsumed === 0) return null;
  const consuming = deltaConsumed > 0;
  const reason: StockMovementReason =
    source === 'sale'
      ? consuming
        ? 'sale_consumption'
        : 'sale_reversal'
      : consuming
        ? 'os_consumption'
        : 'os_reversal';
  return { stockDelta: -deltaConsumed, reason };
}
