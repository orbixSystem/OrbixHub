import {
  buildPaymentSummary,
  derivePaymentStatus,
} from './cashier.service';

/**
 * Testes das funções PURAS do contrato do Caixa (derivação do status de
 * pagamento) — compartilhadas pela implementação real e pelos consumidores.
 * A implementação `CashierServiceImpl` (com banco) é testada à parte.
 */
describe('derivePaymentStatus', () => {
  it('a_receber quando nada foi pago', () => {
    expect(derivePaymentStatus(100, 0)).toBe('a_receber');
  });
  it('parcial quando pago < total', () => {
    expect(derivePaymentStatus(100, 40)).toBe('parcial');
  });
  it('pago quando pago >= total (com tolerância de centavo)', () => {
    expect(derivePaymentStatus(100, 100)).toBe('pago');
    expect(derivePaymentStatus(100, 99.999)).toBe('pago');
    expect(derivePaymentStatus(100, 120)).toBe('pago');
  });
});

describe('buildPaymentSummary', () => {
  it('balance nunca é negativo e espelha total/paid', () => {
    expect(buildPaymentSummary(100, 30)).toEqual({
      total: 100,
      paid: 30,
      balance: 70,
      status: 'parcial',
    });
    expect(buildPaymentSummary(100, 150).balance).toBe(0);
  });
});
