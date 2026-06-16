import {
  mergeInventoryConfig,
  DEFAULT_INVENTORY_CONFIG,
  suggestPriceCents,
  computeMovement,
} from './inventory.config';

describe('inventory.config', () => {
  it('returns defaults when nothing saved', () => {
    expect(mergeInventoryConfig(undefined)).toEqual(DEFAULT_INVENTORY_CONFIG);
  });

  it('shallow-merges a partial patch over current', () => {
    const merged = mergeInventoryConfig(
      { defaultUnit: 'L', categories: ['Óleos'] },
      { defaultMarginPercent: 50 },
    );
    expect(merged.defaultUnit).toBe('L');
    expect(merged.categories).toEqual(['Óleos']);
    expect(merged.defaultMarginPercent).toBe(50);
    expect(merged.trackStockDefault).toBe(true);
  });
});

describe('suggestPriceCents', () => {
  it('applies margin over cost and rounds to cents', () => {
    expect(suggestPriceCents(1000, 50)).toBe(1500);
    expect(suggestPriceCents(999, 33.33)).toBe(1332); // 999*1.3333=1332.0
  });
  it('returns cost when margin is 0 or missing', () => {
    expect(suggestPriceCents(1000, 0)).toBe(1000);
  });
});

describe('computeMovement', () => {
  it('adds on in', () => {
    expect(computeMovement(5, 'in', 3)).toEqual({ quantity: 3, balanceAfter: 8 });
  });
  it('subtracts on out', () => {
    expect(computeMovement(5, 'out', 2)).toEqual({ quantity: 2, balanceAfter: 3 });
  });
  it('blocks negative out', () => {
    expect(() => computeMovement(1, 'out', 5)).toThrow(/negativ/i);
  });
  it('sets target on adjust and records the delta magnitude', () => {
    expect(computeMovement(5, 'adjust', 2)).toEqual({ quantity: 3, balanceAfter: 2 });
    expect(computeMovement(5, 'adjust', 9)).toEqual({ quantity: 4, balanceAfter: 9 });
  });
});
