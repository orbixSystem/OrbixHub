import {
  EM_ANDAMENTO,
  ENCERRADAS,
  FATURAVEIS,
  OS_STATUSES,
} from './os-status';

/**
 * A razão de este arquivo existir: quando `a_receber`, `aguardando_pecas`,
 * `pendente` e `sem_conserto` entraram na FSM, nenhum dos conjuntos espalhados
 * pelo código foi atualizado. Nada quebrou — só o faturamento passou a sair
 * menor e o atraso maior, em silêncio. Estes testes transformam "status novo"
 * numa falha visível.
 */
describe('grupos de status da OS', () => {
  it('todo status cai em exatamente um lado: encerrado ou em andamento', () => {
    for (const s of OS_STATUSES) {
      const encerrado = ENCERRADAS.has(s);
      const andando = EM_ANDAMENTO.has(s);
      expect([encerrado, andando]).toContainEqual(true);
      expect(encerrado && andando).toBe(false);
    }
  });

  it('a_receber é faturável — é serviço pronto esperando pagamento', () => {
    expect(FATURAVEIS.has('a_receber')).toBe(true);
  });

  it('sem_conserto encerra mas NÃO fatura — não houve serviço', () => {
    expect(ENCERRADAS.has('sem_conserto')).toBe(true);
    expect(FATURAVEIS.has('sem_conserto')).toBe(false);
  });

  it('cancelada encerra e não fatura', () => {
    expect(ENCERRADAS.has('cancelada')).toBe(true);
    expect(FATURAVEIS.has('cancelada')).toBe(false);
  });

  it('toda faturável está encerrada', () => {
    for (const s of FATURAVEIS) expect(ENCERRADAS.has(s)).toBe(true);
  });

  it('o que espera peça ou aprovação continua em andamento', () => {
    const vivas = [
      'aberta',
      'aguardando_aprovacao',
      'aprovada',
      'em_execucao',
      'aguardando_pecas',
      'pendente',
    ] as const;
    for (const s of vivas) expect(EM_ANDAMENTO.has(s)).toBe(true);
  });
});
