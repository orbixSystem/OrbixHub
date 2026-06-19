// CNPJ helpers — generic identity for a tenant (empresa). Pure functions, no I/O.
// Algoritmo oficial dos dígitos verificadores (módulo 11).

/** Strips mask/whitespace, returning only the bare digits of a CNPJ. */
export function normalizeCnpj(raw: string | null | undefined): string {
  return (raw ?? '').replace(/\D/g, '');
}

const FIRST_WEIGHTS = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
const SECOND_WEIGHTS = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];

function checkDigit(digits: string, weights: number[]): number {
  const sum = weights.reduce((acc, w, i) => acc + Number(digits[i]) * w, 0);
  const mod = sum % 11;
  return mod < 2 ? 0 : 11 - mod;
}

/** True when `raw` is a structurally valid CNPJ (14 digits + matching DV). */
export function isValidCnpj(raw: string | null | undefined): boolean {
  const c = normalizeCnpj(raw);
  if (c.length !== 14) return false;
  if (/^(\d)\1{13}$/.test(c)) return false; // rejeita 00000000000000, 11111111111111, …
  if (checkDigit(c.slice(0, 12), FIRST_WEIGHTS) !== Number(c[12])) return false;
  return checkDigit(c.slice(0, 13), SECOND_WEIGHTS) === Number(c[13]);
}

/** Formats bare/masked digits as `XX.XXX.XXX/XXXX-XX`; returns input unchanged if not 14 digits. */
export function formatCnpj(raw: string | null | undefined): string {
  const c = normalizeCnpj(raw);
  if (c.length !== 14) return raw ?? '';
  return `${c.slice(0, 2)}.${c.slice(2, 5)}.${c.slice(5, 8)}/${c.slice(8, 12)}-${c.slice(12)}`;
}
