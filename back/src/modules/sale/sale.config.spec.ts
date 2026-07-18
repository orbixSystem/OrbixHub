import {
  computeSaleTotal,
  computeSubtotal,
  formatSaleNumber,
} from './sale.config';

describe('sale.config — helpers puros', () => {
  it('computeSubtotal = qty × preço, nunca negativo, 2 casas', () => {
    expect(computeSubtotal(2, 10)).toBe(20);
    expect(computeSubtotal(3, 9.99)).toBe(29.97);
    expect(computeSubtotal(-1, 10)).toBe(0); // clamp
    expect(computeSubtotal(0.5, 10.5)).toBe(5.25);
  });

  it('computeSaleTotal soma os subtotais (2 casas)', () => {
    expect(
      computeSaleTotal([
        { quantity: 2, unitPrice: 10 },
        { quantity: 1, unitPrice: 5.5 },
      ]),
    ).toBe(25.5);
    expect(computeSaleTotal([])).toBe(0);
  });

  it('formatSaleNumber gera VND-NNNN', () => {
    expect(formatSaleNumber(1)).toBe('VND-0001');
    expect(formatSaleNumber(42)).toBe('VND-0042');
    expect(formatSaleNumber(12345)).toBe('VND-12345');
  });
});
