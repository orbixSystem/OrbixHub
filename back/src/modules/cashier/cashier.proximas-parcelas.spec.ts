import { CashierServiceImpl } from './cashier.service.impl';

/**
 * Porta estreita para o "A receber": para N títulos, a PRÓXIMA parcela em
 * aberto de cada um, numa consulta só. O chamador não vê a parcela — só a data.
 * Uma chamada por devedor seria N+1 numa lista que já custa uma varredura.
 */
type Row = {
  sale_kind: string;
  sale_id: string;
  due_date: Date;
  paid_at: Date | null;
};

function makeService(rows: Row[]) {
  const db = {
    receivable_installment: {
      // O impl pede `paid_at: null` no where; o fake honra isso para o teste
      // provar que a filtragem acontece no banco, não no JS.
      findMany: jest.fn().mockImplementation(() =>
        Promise.resolve(
          rows
            .filter((r) => r.paid_at === null)
            .sort((a, b) => a.due_date.getTime() - b.due_date.getTime()),
        ),
      ),
    },
  };
  const tenant = {
    runWithTenant: <T>(_tid: string, fn: () => Promise<T> | T) =>
      Promise.resolve(fn()),
    withTenantTx: <T>(fn: () => Promise<T> | T) => Promise.resolve(fn()),
    getClient: () => db,
  };
  const svc = new CashierServiceImpl(
    tenant as never,
    {} as never,
    {} as never,
    {} as never,
  );
  return { svc, db };
}

describe('proximasParcelasEmAberto', () => {
  it('devolve a parcela em aberto mais próxima de cada título, ignorando as pagas', async () => {
    const { svc } = makeService([
      { sale_kind: 'sale', sale_id: 'v1', due_date: new Date('2026-10-10'), paid_at: null },
      { sale_kind: 'sale', sale_id: 'v1', due_date: new Date('2026-09-10'), paid_at: new Date() },
      { sale_kind: 'sale', sale_id: 'v1', due_date: new Date('2026-09-20'), paid_at: null },
      { sale_kind: 'os', sale_id: 'o1', due_date: new Date('2026-09-05'), paid_at: null },
    ]);
    const r = await svc.proximasParcelasEmAberto('t1', [
      { saleKind: 'sale', saleId: 'v1' },
      { saleKind: 'os', saleId: 'o1' },
      { saleKind: 'sale', saleId: 'sem-plano' },
    ]);
    expect(r.get('sale:v1')).toBe('2026-09-20');
    expect(r.get('os:o1')).toBe('2026-09-05');
    expect(r.has('sale:sem-plano')).toBe(false);
  });

  it('pede ao banco só parcelas em aberto dos títulos informados', async () => {
    const { svc, db } = makeService([]);
    await svc.proximasParcelasEmAberto('t1', [{ saleKind: 'os', saleId: 'o1' }]);
    const args = db.receivable_installment.findMany.mock.calls[0][0] as {
      where: { paid_at: null; OR: unknown[] };
    };
    expect(args.where.paid_at).toBeNull();
    expect(args.where.OR).toEqual([{ sale_kind: 'os', sale_id: 'o1' }]);
  });

  it('sem refs não consulta o banco', async () => {
    const { svc, db } = makeService([]);
    expect((await svc.proximasParcelasEmAberto('t1', [])).size).toBe(0);
    expect(db.receivable_installment.findMany).not.toHaveBeenCalled();
  });
});
