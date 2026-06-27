/**
 * "Só na virada": true quando a operação leva o item de NÃO-baixo para baixo.
 * Mínimo nulo = nunca baixo (Opção A). prevMin/nextMin separados para cobrir o
 * caso de o próprio mínimo mudar (ex.: subir o mínimo acima do saldo atual).
 */
export function crossedIntoLowStock(
  prevStock: number,
  prevMin: number | null,
  nextStock: number,
  nextMin: number | null,
): boolean {
  const wasLow = prevMin != null && prevStock <= prevMin;
  const isLow = nextMin != null && nextStock <= nextMin;
  return !wasLow && isLow;
}
