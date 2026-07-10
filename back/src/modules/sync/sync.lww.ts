/**
 * Decisão pura de Last-Write-Wins (S2), isolada para teste sem I/O.
 *
 * O relógio do cliente é CLAMPADO ao `now` do servidor: um timestamp futuro
 * (forjado ou por relógio adiantado) nunca "envenena" o LWW — vira `now` e, no
 * máximo, sobrescreve a linha atual (não bloqueia escritas legítimas futuras).
 * Um timestamp passado permanece no passado.
 */

/** ms efetivo = min(relógio do cliente, agora). NaN vira o passado-remoto (perde). */
export function effectiveTsMs(clientUpdatedAtMs: number, nowMs: number): number {
  if (!Number.isFinite(clientUpdatedAtMs)) return Number.NEGATIVE_INFINITY;
  return Math.min(clientUpdatedAtMs, nowMs);
}

/**
 * A mutação é descartada quando existe uma linha no servidor mais NOVA que o
 * timestamp efetivo do cliente. Sem linha alvo (`current === null`) nunca
 * descarta — a op segue para o apply.
 */
export function lwwDiscards(
  current: Date | null,
  clientUpdatedAtMs: number,
  nowMs: number,
): boolean {
  if (!current) return false;
  return current.getTime() > effectiveTsMs(clientUpdatedAtMs, nowMs);
}
