/**
 * Resolve o range [from, to] das métricas a partir de query params ISO opcionais.
 * Default: últimos 30 dias até agora. `from` ganha 00:00:00 do dia? Não — usa o
 * instante exato passado; o front manda ISO completo. `to` default = agora.
 * Compartilhado pelos endpoints `GET /<módulo>/metrics`.
 */
export function resolveRange(
  from?: string,
  to?: string,
): { from: Date; to: Date } {
  const toDate = to ? new Date(to) : new Date();
  const fromDate = from
    ? new Date(from)
    : new Date(toDate.getTime() - 30 * 24 * 60 * 60 * 1000);
  return { from: fromDate, to: toDate };
}
