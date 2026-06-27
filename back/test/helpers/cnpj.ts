// Gera um CNPJ estruturalmente válido (dígitos verificadores corretos) para os
// testes. Aleatório → único o suficiente para o índice global de CNPJ.

const FIRST_WEIGHTS = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
const SECOND_WEIGHTS = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];

function dv(digits: string, weights: number[]): number {
  const sum = weights.reduce((acc, w, i) => acc + Number(digits[i]) * w, 0);
  const mod = sum % 11;
  return mod < 2 ? 0 : 11 - mod;
}

/** Returns a valid 14-digit CNPJ (bare digits). */
export function randomCnpj(): string {
  let base = '';
  for (let i = 0; i < 12; i++) base += Math.floor(Math.random() * 10);
  const d1 = dv(base, FIRST_WEIGHTS);
  const d2 = dv(base + d1, SECOND_WEIGHTS);
  return `${base}${d1}${d2}`;
}
