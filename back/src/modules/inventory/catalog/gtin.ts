/** true se `code` é um GTIN válido (8/12/13/14 dígitos + dígito verificador GS1). */
export function isValidGtin(code: string): boolean {
  if (!/^\d{8}$|^\d{12}$|^\d{13}$|^\d{14}$/.test(code)) return false;
  const digits = code.split('').map(Number);
  const check = digits.pop()!;
  // GS1 mod-10: da direita p/ esquerda, pesos alternam 3,1,3,1...
  let sum = 0;
  for (let i = digits.length - 1, mult = 3; i >= 0; i--, mult = mult === 3 ? 1 : 3) {
    sum += digits[i] * mult;
  }
  const expected = (10 - (sum % 10)) % 10;
  return expected === check;
}
