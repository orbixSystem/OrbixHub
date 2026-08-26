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
      received: 30,
      discount: 0,
      balance: 70,
      status: 'parcial',
    });
    expect(buildPaymentSummary(100, 150).balance).toBe(0);
  });

  it('desconto QUITA sem entrar dinheiro: 90 + 10 fecha uma dívida de 100', () => {
    expect(buildPaymentSummary(100, 90, 10)).toEqual({
      total: 100,
      paid: 100,
      received: 90,
      discount: 10,
      balance: 0,
      status: 'pago',
    });
  });

  it('separa o que ENTROU do que foi QUITADO — confundir os dois é bug de dinheiro', () => {
    const r = buildPaymentSummary(100, 90, 10);
    // O fechamento do caixa soma `received`; o saldo do documento soma `paid`.
    expect(r.received).toBe(90);
    expect(r.paid).toBe(100);
  });

  it('perdão integral: nada entrou, mas a dívida fechou', () => {
    const r = buildPaymentSummary(100, 0, 100);
    expect(r.status).toBe('pago');
    expect(r.balance).toBe(0);
    expect(r.received).toBe(0);
  });

  it('desconto omitido equivale a zero — recebimento anterior à 0055', () => {
    expect(buildPaymentSummary(100, 40)).toEqual(buildPaymentSummary(100, 40, 0));
  });
});
