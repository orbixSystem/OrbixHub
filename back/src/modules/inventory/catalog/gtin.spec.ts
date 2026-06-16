import { isValidGtin } from './gtin';

describe('isValidGtin', () => {
  it('aceita GTINs válidos (dígito verificador GS1 correto)', () => {
    expect(isValidGtin('7891000100103')).toBe(true); // EAN-13 (Nestlé)
    expect(isValidGtin('40063812')).toBe(true); // EAN-8
    expect(isValidGtin('17891000100100')).toBe(true); // GTIN-14
  });

  it('rejeita GTINs com dígito verificador errado', () => {
    expect(isValidGtin('7891000100104')).toBe(false);
    expect(isValidGtin('40063813')).toBe(false);
  });

  it('rejeita comprimentos inválidos e não-numéricos', () => {
    expect(isValidGtin('123')).toBe(false);
    expect(isValidGtin('789100010010')).toBe(false); // 12 dígitos mas check errado
    expect(isValidGtin('789100010010a')).toBe(false);
    expect(isValidGtin('')).toBe(false);
  });
});
