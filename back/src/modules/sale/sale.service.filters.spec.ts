import { SaleService } from './sale.service';
import {
  buildPaymentSummary,
  CashierService,
} from '../cashier/cashier.service';
import type { AuthUser } from '../../common/auth/auth.types';

/**
 * Filtros da listagem de vendas — a base do histórico de vendas ("o que vendi,
 * para quem, quando").
 *
 * Sem recorte por período não há como responder "o que vendi em julho": a
 * listagem só tinha status/cliente/página. `q` busca pelo número da venda ou
 * pelo nome do cliente (o snapshot gravado na própria venda, que preserva o
 * histórico mesmo se o cliente for renomeado depois).
 */

class FakeCashier extends CashierService {
  getPaymentSummary(_t: string, _v: string, fallbackTotal = 0) {
    return Promise.resolve(buildPaymentSummary(fallbackTotal, 0));
  }
  getPaymentSummaryBatch(
    _t: string,
    vendas: Array<{ id: string; total: number }>,
  ) {
    const m = new Map<string, ReturnType<typeof buildPaymentSummary>>();
    for (const v of vendas) m.set(v.id, buildPaymentSummary(v.total, 0));
    return Promise.resolve(m);
  }
  listChangedSince() {
    return Promise.resolve({ rows: [], nextCursor: null, hasMore: false });
  }
}

const user = {
  userId: 'u1',
  tenantId: 't1',
  role: 'owner',
  permissions: [],
} as unknown as AuthUser;

const tenant = {
  withTenantTx: <T>(fn: () => Promise<T> | T) => Promise.resolve(fn()),
  runWithTenant: <T>(_tid: string, fn: () => Promise<T> | T) =>
    Promise.resolve(fn()),
} as unknown as ConstructorParameters<typeof SaleService>[0];

function makeService() {
  const repo = {
    listSales: jest.fn().mockResolvedValue({ items: [], total: 0 }),
  };
  const svc = new SaleService(
    tenant,
    repo as never,
    { log: jest.fn() } as never,
    {} as never,
    {} as never,
    new FakeCashier(),
  );
  return { svc, repo };
}

describe('SaleService.listSales — recorte por período', () => {
  it('converte from/to ISO em Date para o repositório', async () => {
    const { svc, repo } = makeService();
    await svc.listSales(user, {
      from: '2026-07-01T00:00:00.000Z',
      to: '2026-07-31T23:59:59.999Z',
    } as never);

    const f = repo.listSales.mock.calls[0][0];
    expect(f.from).toBeInstanceOf(Date);
    expect(f.to).toBeInstanceOf(Date);
    expect(f.from.toISOString()).toBe('2026-07-01T00:00:00.000Z');
    expect(f.to.toISOString()).toBe('2026-07-31T23:59:59.999Z');
  });

  it('sem período, não restringe data (undefined, não Invalid Date)', async () => {
    const { svc, repo } = makeService();
    await svc.listSales(user, {} as never);

    const f = repo.listSales.mock.calls[0][0];
    expect(f.from).toBeUndefined();
    expect(f.to).toBeUndefined();
  });

  it('aceita só o início do período (aberto até hoje)', async () => {
    const { svc, repo } = makeService();
    await svc.listSales(user, { from: '2026-08-01T00:00:00.000Z' } as never);

    const f = repo.listSales.mock.calls[0][0];
    expect(f.from).toBeInstanceOf(Date);
    expect(f.to).toBeUndefined();
  });
});

describe('SaleService.listSales — busca livre', () => {
  it('repassa o termo de busca', async () => {
    const { svc, repo } = makeService();
    await svc.listSales(user, { q: 'Maria' } as never);
    expect(repo.listSales.mock.calls[0][0].q).toBe('Maria');
  });

  it('espaço em branco não vira filtro (buscaria por nada)', async () => {
    const { svc, repo } = makeService();
    await svc.listSales(user, { q: '   ' } as never);
    expect(repo.listSales.mock.calls[0][0].q).toBeUndefined();
  });

  it('apara o termo antes de buscar', async () => {
    const { svc, repo } = makeService();
    await svc.listSales(user, { q: '  VND-0007 ' } as never);
    expect(repo.listSales.mock.calls[0][0].q).toBe('VND-0007');
  });
});

describe('SaleService.listSales — filtros combinados e paginação', () => {
  it('período + cliente + status convivem', async () => {
    const { svc, repo } = makeService();
    await svc.listSales(user, {
      status: 'active',
      customerId: '11111111-1111-1111-1111-111111111111',
      from: '2026-07-01T00:00:00.000Z',
      page: 2,
      pageSize: 50,
    } as never);

    const f = repo.listSales.mock.calls[0][0];
    expect(f.status).toBe('active');
    expect(f.customerId).toBe('11111111-1111-1111-1111-111111111111');
    expect(f.from).toBeInstanceOf(Date);
    expect(f.skip).toBe(50); // (2 - 1) * 50
    expect(f.take).toBe(50);
  });

  it('devolve a página junto do total (base do "carregar mais")', async () => {
    const { svc, repo } = makeService();
    repo.listSales.mockResolvedValue({ items: [], total: 137 });
    const r = await svc.listSales(user, { page: 3 } as never);
    expect(r.total).toBe(137);
    expect(r.page).toBe(3);
    expect(r.pageSize).toBe(20);
  });
});
