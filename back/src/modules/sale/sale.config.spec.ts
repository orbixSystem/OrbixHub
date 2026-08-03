import {
  applySaleDiscount,
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

  describe('applySaleDiscount — desconto na venda', () => {
    it('desconta do bruto e registra o que foi dado', () => {
      expect(applySaleDiscount(100, 10)).toEqual({ total: 90, discount: 10 });
    });

    it('sem desconto, total = bruto', () => {
      expect(applySaleDiscount(100, 0)).toEqual({ total: 100, discount: 0 });
    });

    it('desconto MAIOR que a venda zera o total, sem virar negativo', () => {
      // Total negativo seria dinheiro SAINDO do caixa numa venda.
      expect(applySaleDiscount(150, 200)).toEqual({ total: 0, discount: 150 });
    });

    it('desconto negativo é ignorado (seria aumento disfarçado)', () => {
      expect(applySaleDiscount(100, -50)).toEqual({ total: 100, discount: 0 });
    });

    it('bruto negativo não produz total negativo', () => {
      expect(applySaleDiscount(-10, 0)).toEqual({ total: 0, discount: 0 });
    });

    it('arredonda para centavos', () => {
      expect(applySaleDiscount(99.999, 0.004)).toEqual({
        total: 100,
        discount: 0,
      });
      expect(applySaleDiscount(10, 3.333)).toEqual({
        total: 6.67,
        discount: 3.33,
      });
    });

    it('desconto igual ao total zera a venda (brinde)', () => {
      expect(applySaleDiscount(80, 80)).toEqual({ total: 0, discount: 80 });
    });
  });
});
