import { crossedIntoLowStock } from './low-stock';

describe('crossedIntoLowStock', () => {
  it('dispara quando o saldo cai de acima do mínimo para <= mínimo', () => {
    expect(crossedIntoLowStock(5, 3, 2, 3)).toBe(true);
  });

  it('conta o saldo exatamente no mínimo como baixo', () => {
    expect(crossedIntoLowStock(5, 3, 3, 3)).toBe(true);
  });

  it('NÃO dispara quando já estava baixo e continua baixando', () => {
    expect(crossedIntoLowStock(2, 3, 1, 3)).toBe(false);
  });

  it('NÃO dispara sem mínimo definido (Opção A)', () => {
    expect(crossedIntoLowStock(5, null, 0, null)).toBe(false);
  });

  it('NÃO dispara quando o saldo segue acima do mínimo', () => {
    expect(crossedIntoLowStock(10, 3, 8, 3)).toBe(false);
  });

  it('dispara quando o mínimo sobe acima do saldo atual (virada pelo mínimo)', () => {
    expect(crossedIntoLowStock(5, null, 5, 10)).toBe(true);
    expect(crossedIntoLowStock(5, 3, 5, 10)).toBe(true);
  });

  it('NÃO dispara em reabastecimento (sobe acima do mínimo)', () => {
    expect(crossedIntoLowStock(2, 3, 5, 3)).toBe(false);
  });

  it('rearma: após reabastecer, baixar de novo dispara', () => {
    expect(crossedIntoLowStock(5, 3, 2, 3)).toBe(true);
  });
});
