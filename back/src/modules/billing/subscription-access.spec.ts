import { subscriptionAllows } from './subscription-access';

describe('subscriptionAllows', () => {
  describe('enforcement OFF (default até existir módulo de assinatura)', () => {
    it('libera qualquer status, leitura e escrita', () => {
      for (const status of ['trialing', 'active', 'past_due', 'canceled', 'seja_o_que_for']) {
        expect(subscriptionAllows(status, false, false)).toBe(true);
        expect(subscriptionAllows(status, true, false)).toBe(true);
      }
    });
  });

  describe('enforcement ON', () => {
    it('trialing e active liberam leitura e escrita', () => {
      for (const status of ['trialing', 'active']) {
        expect(subscriptionAllows(status, false, true)).toBe(true);
        expect(subscriptionAllows(status, true, true)).toBe(true);
      }
    });
    it('past_due libera leitura e barra escrita', () => {
      expect(subscriptionAllows('past_due', false, true)).toBe(true);
      expect(subscriptionAllows('past_due', true, true)).toBe(false);
    });
    it('canceled barra leitura e escrita', () => {
      expect(subscriptionAllows('canceled', false, true)).toBe(false);
      expect(subscriptionAllows('canceled', true, true)).toBe(false);
    });
    it('status desconhecido barra tudo (fail-closed)', () => {
      expect(subscriptionAllows('whatever', false, true)).toBe(false);
      expect(subscriptionAllows('whatever', true, true)).toBe(false);
    });
  });
});
