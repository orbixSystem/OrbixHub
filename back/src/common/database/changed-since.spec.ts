import { clampChangedSinceLimit } from './changed-since';

describe('clampChangedSinceLimit', () => {
  it('mantém valores dentro do intervalo [1, 500]', () => {
    expect(clampChangedSinceLimit(1)).toBe(1);
    expect(clampChangedSinceLimit(200)).toBe(200);
    expect(clampChangedSinceLimit(500)).toBe(500);
  });

  it('clampa valores abaixo do mínimo para 1', () => {
    expect(clampChangedSinceLimit(0)).toBe(1);
    expect(clampChangedSinceLimit(-1)).toBe(1);
    expect(clampChangedSinceLimit(-999)).toBe(1);
  });

  it('clampa valores acima do máximo para 500 (anti-DoS)', () => {
    expect(clampChangedSinceLimit(501)).toBe(500);
    expect(clampChangedSinceLimit(10_000)).toBe(500);
  });

  it('trunca fracionários (500.9 → 500, 2.7 → 2)', () => {
    expect(clampChangedSinceLimit(500.9)).toBe(500);
    expect(clampChangedSinceLimit(2.7)).toBe(2);
    expect(clampChangedSinceLimit(0.5)).toBe(1); // trunca p/ 0, clampa p/ 1
  });

  it('não-finitos (NaN, ±Infinity, undefined) caem no default 500', () => {
    expect(clampChangedSinceLimit(Number.NaN)).toBe(500);
    expect(clampChangedSinceLimit(Number.POSITIVE_INFINITY)).toBe(500);
    expect(clampChangedSinceLimit(Number.NEGATIVE_INFINITY)).toBe(500);
    expect(
      clampChangedSinceLimit(undefined as unknown as number),
    ).toBe(500);
  });
});
