import { ExpensesService } from './expenses.service';

/**
 * Resumo de despesas por categoria — a porta que o módulo `report` consome.
 *
 * Duas regras que estes testes fixam, porque erradas dariam relatório de custo
 * mentiroso:
 *  - o recorte é pelo VENCIMENTO (conta de agosto paga com atraso é custo de
 *    agosto), então `pago + emAberto` fecha o `previsto`;
 *  - conta SEM categoria aparece como linha própria — omiti-la faria a soma das
 *    linhas não bater com o total.
 */
type Linha = {
  id: string;
  amount: number;
  due_date: Date;
  category_id: string | null;
  paid_at: Date | null;
  paid_amount: number | null;
};

function montar(linhas: Array<Partial<Linha>>) {
  const itens: Linha[] = linhas.map((l, i) => ({
    id: `e${i}`,
    amount: 100,
    // Bem no PASSADO (2020) por padrão. O service usa `new Date()` como hoje, e
    // uma data "quase hoje" tornaria o teste dependente do dia em que roda — foi
    // o que me pegou: 10/08/2026 ainda era futuro quando escrevi isto.
    due_date: new Date(Date.UTC(2020, 0, 1)),
    category_id: null,
    paid_at: null,
    paid_amount: null,
    ...l,
  }));

  const repo = {
    listByDueRange: jest.fn(() => Promise.resolve(itens)),
    listCategories: jest.fn(() =>
      Promise.resolve([
        { id: 'c1', name: 'Energia', color: '#EAB308' },
        { id: 'c2', name: 'Aluguel', color: '#F97316' },
      ]),
    ),
  };
  const tenant = { withTenantTx: <T>(fn: () => Promise<T>) => fn() };
  const service = new ExpensesService(
    tenant as never,
    repo as never,
    { log: jest.fn() } as never,
    {} as never,
    {} as never,
  );
  return { service, repo };
}

const range = {
  from: new Date(Date.UTC(2026, 7, 1)),
  to: new Date(Date.UTC(2026, 7, 31)),
};

describe('summaryByCategory', () => {
  it('agrupa por categoria e resolve o nome', async () => {
    const { service } = montar([
      { category_id: 'c1', amount: 180 },
      { category_id: 'c1', amount: 20 },
      { category_id: 'c2', amount: 2500 },
    ]);
    const r = await service.summaryByCategory(range);

    expect(r.rows.map((l) => l.categoryName)).toEqual(['Aluguel', 'Energia']);
    // Maior gasto primeiro: o relatório responde "para onde vai o dinheiro", e a
    // resposta é a primeira linha.
    expect(r.rows[0].previsto).toBe(2500);
    expect(r.rows[1].previsto).toBe(200);
    expect(r.rows[1].count).toBe(2);
  });

  it('pago + em aberto FECHA o previsto (é o mesmo período)', async () => {
    const { service } = montar([
      { category_id: 'c1', amount: 100, paid_at: new Date(), paid_amount: 100 },
      { category_id: 'c1', amount: 300 },
    ]);
    const r = await service.summaryByCategory(range);
    const l = r.rows[0];
    expect(l.previsto).toBe(400);
    expect(l.pago).toBe(100);
    expect(l.emAberto).toBe(300);
    expect(l.pago + l.emAberto).toBe(l.previsto);
  });

  it('usa o valor REALMENTE pago (juros/desconto divergem do previsto)', async () => {
    const { service } = montar([
      {
        category_id: 'c1',
        amount: 200,
        paid_at: new Date(),
        paid_amount: 218.4,
      },
    ]);
    const r = await service.summaryByCategory(range);
    expect(r.rows[0].previsto).toBe(200);
    expect(r.rows[0].pago).toBe(218.4);
  });

  it('baixa antiga sem paid_amount cai no previsto, não em zero', async () => {
    const { service } = montar([
      { category_id: 'c1', amount: 90, paid_at: new Date(), paid_amount: null },
    ]);
    const r = await service.summaryByCategory(range);
    expect(r.rows[0].pago).toBe(90);
  });

  it('vencido é SUBCONJUNTO do em aberto', async () => {
    const { service } = montar([
      // Vencida (2020) e não paga.
      { category_id: 'c1', amount: 120 },
      // Bem no futuro: em aberto, mas não vencida.
      { category_id: 'c1', amount: 80, due_date: new Date(Date.UTC(2099, 0, 1)) },
    ]);
    const r = await service.summaryByCategory(range);
    expect(r.rows[0].emAberto).toBe(200);
    expect(r.rows[0].vencido).toBe(120);
  });

  it('conta paga em atraso NÃO conta como vencida', async () => {
    const { service } = montar([
      { category_id: 'c1', amount: 150, paid_at: new Date(), paid_amount: 150 },
    ]);
    const r = await service.summaryByCategory(range);
    expect(r.rows[0].vencido).toBe(0);
  });

  it('conta SEM categoria vira linha própria (senão a soma não fecha)', async () => {
    const { service } = montar([
      { category_id: 'c1', amount: 100 },
      { category_id: null, amount: 70 },
    ]);
    const r = await service.summaryByCategory(range);
    const sem = r.rows.find((l) => l.categoryId === null);
    expect(sem?.categoryName).toBe('Sem categoria');
    expect(sem?.previsto).toBe(70);
    // O total é a soma das LINHAS mostradas.
    expect(r.totals.previsto).toBe(170);
  });

  it('categoria apagada ainda aparece pelo nome (inclui desativadas)', async () => {
    const { service, repo } = montar([{ category_id: 'c1', amount: 10 }]);
    await service.summaryByCategory(range);
    // Sem `includeDisabled` a categoria desativada viraria "Sem categoria" e o
    // histórico perderia o rótulo que tinha.
    expect(repo.listCategories).toHaveBeenCalledWith({ includeDisabled: true });
  });

  it('período vazio devolve zeros, não erro', async () => {
    const { service } = montar([]);
    const r = await service.summaryByCategory(range);
    expect(r.rows).toEqual([]);
    expect(r.totals).toEqual({
      count: 0,
      previsto: 0,
      pago: 0,
      emAberto: 0,
      vencido: 0,
    });
  });

  it('recorta pelo VENCIMENTO — o range vai para a consulta', async () => {
    const { service, repo } = montar([]);
    await service.summaryByCategory(range);
    expect(repo.listByDueRange).toHaveBeenCalledWith({
      de: range.from,
      ate: range.to,
    });
  });
});
