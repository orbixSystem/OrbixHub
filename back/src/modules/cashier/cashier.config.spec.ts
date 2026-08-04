import {
  computeDifference,
  computeExpected,
  DEFAULT_CASHIER_CONFIG,
  directionForCategory,
  mergeCashierConfig,
  PAYMENT_METHODS,
  round2,
} from './cashier.config';

describe('directionForCategory', () => {
  it('despesa e sangria são saída; o resto é entrada', () => {
    expect(directionForCategory('despesa')).toBe('out');
    expect(directionForCategory('sangria')).toBe('out');
    expect(directionForCategory('os_payment')).toBe('in');
    expect(directionForCategory('venda_avulsa')).toBe('in');
    expect(directionForCategory('suprimento')).toBe('in');
  });
});

describe('computeExpected / computeDifference', () => {
  it('esperado = abertura + entradas − saídas (arredondado a centavo)', () => {
    expect(computeExpected({ opening: 100, totalIn: 250.5, totalOut: 30.25 })).toBe(
      320.25,
    );
    expect(computeExpected({ opening: 0, totalIn: 0, totalOut: 0 })).toBe(0);
  });
  it('diferença = contado − esperado (sobra positiva, falta negativa)', () => {
    expect(computeDifference(320.25, 320.25)).toBe(0);
    expect(computeDifference(330, 320.25)).toBe(9.75); // sobra
    expect(computeDifference(300, 320.25)).toBe(-20.25); // falta
  });
  it('round2 elimina ruído de ponto flutuante', () => {
    expect(round2(0.1 + 0.2)).toBe(0.3);
  });
});

describe('mergeCashierConfig', () => {
  it('defaults quando nada salvo', () => {
    expect(mergeCashierConfig(undefined)).toEqual(DEFAULT_CASHIER_CONFIG);
  });
  it('aplica patch parcial preservando o resto', () => {
    const merged = mergeCashierConfig(
      { countCashOnly: true },
      { countCashOnly: false },
    );
    expect(merged.countCashOnly).toBe(false);
  });
  it('filtra métodos inválidos e cai no default se a lista ficar vazia', () => {
    expect(
      mergeCashierConfig(undefined, { paymentMethods: ['pix', 'bitcoin'] as never })
        .paymentMethods,
    ).toEqual(['pix']);
    expect(
      mergeCashierConfig(undefined, { paymentMethods: ['nada'] as never })
        .paymentMethods,
    ).toEqual([...PAYMENT_METHODS]);
  });

  // Decisão de produto: a cerimônia de abrir/fechar caixa foi REMOVIDA. Ela
  // servia para conferir gaveta de dinheiro, mas na prática só produzia telas de
  // "abra o caixa" bloqueando o lançamento. O campo permanece no tipo (e no jsonb
  // de tenants antigos) para não quebrar contrato — mas é NORMALIZADO.
  it('nunca exige caixa aberto — nem por default', () => {
    expect(DEFAULT_CASHIER_CONFIG.requireOpenSession).toBe(false);
    expect(mergeCashierConfig(undefined).requireOpenSession).toBe(false);
  });

  it('IGNORA `true` gravado no tenant (não fica preso na cerimônia)', () => {
    // Tenant antigo, anterior à remoção, com `true` no jsonb: sem esta
    // normalização ele continuaria pedindo abertura de uma tela que não existe.
    expect(
      mergeCashierConfig({ requireOpenSession: true }).requireOpenSession,
    ).toBe(false);
  });

  it('IGNORA `true` vindo por API (ninguém religa a cerimônia)', () => {
    expect(
      mergeCashierConfig(undefined, { requireOpenSession: true })
          .requireOpenSession,
    ).toBe(false);
  });

  it('normalizar requireOpenSession não afeta as outras chaves', () => {
    const m = mergeCashierConfig(
      { requireOpenSession: true, countCashOnly: false },
      { paymentMethods: ['pix'] },
    );
    expect(m.requireOpenSession).toBe(false);
    expect(m.countCashOnly).toBe(false);
    expect(m.paymentMethods).toEqual(['pix']);
  });
});
