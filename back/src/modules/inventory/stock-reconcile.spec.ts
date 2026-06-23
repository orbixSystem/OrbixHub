import { computeReconcile } from './stock-reconcile';

describe('computeReconcile', () => {
  it('consome quando o alvo sobe a partir de zero (baixa)', () => {
    expect(computeReconcile(0, 3)).toEqual({
      stockDelta: -3,
      reason: 'os_consumption',
    });
  });

  it('estorna tudo quando o alvo cai a zero (cancelamento)', () => {
    expect(computeReconcile(3, 0)).toEqual({
      stockDelta: 3,
      reason: 'os_reversal',
    });
  });

  it('estorna a diferença quando o alvo diminui (redução de qtd)', () => {
    expect(computeReconcile(3, 1)).toEqual({
      stockDelta: 2,
      reason: 'os_reversal',
    });
  });

  it('baixa a mais quando o alvo aumenta', () => {
    expect(computeReconcile(1, 4)).toEqual({
      stockDelta: -3,
      reason: 'os_consumption',
    });
  });

  it('retorna null quando não há mudança (idempotência)', () => {
    expect(computeReconcile(2, 2)).toBeNull();
  });
});
