import { OsService } from './os.service';
import {
  buildPaymentSummary,
  CashierService,
} from '../cashier/cashier.service';
import type { AuthUser } from '../../common/auth/auth.types';

/**
 * Fake do contrato do Caixa para unit (sem banco): espelha a semântica "nada
 * recebido ⇒ a_receber" usada pela derivação do status de pagamento.
 */
class FakeCashierService extends CashierService {
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
}

/**
 * Unit do recorte "status de pagamento" do OsService — deps mockadas.
 * Cobre: pagamento derivado do caixa (nada recebido ⇒ a_receber) no detalhe e
 * a tag `payment_status` na listagem. (A emissão de NF da OS é do módulo
 * `invoice` — coberta lá, não aqui.)
 */

const user: AuthUser = {
  userId: 'u1',
  tenantId: 't1',
  role: 'owner',
  permissions: [],
} as unknown as AuthUser;

// TenantContext fake: roda o callback direto (sem tx real).
const tenant = {
  withTenantTx: <T>(fn: () => Promise<T> | T) => Promise.resolve(fn()),
  runWithTenant: <T>(_tid: string, fn: () => Promise<T> | T) =>
    Promise.resolve(fn()),
} as unknown as ConstructorParameters<typeof OsService>[0];

const order = {
  id: 'os1',
  tenant_id: 't1',
  number: 'OS-0001',
  customer_id: 'c1',
  customer_name: 'Cliente Teste',
  status: 'concluida',
  total: 150,
  deleted_at: null,
  items: [
    {
      name: 'Filtro',
      kind: 'product',
      quantity: 1,
      unit_price: 150,
      discount: 0,
      total: 150,
      inventory_item_id: 'inv1',
    },
  ],
};

function makeService(over: {
  repo?: Partial<Record<string, jest.Mock>>;
  audit?: { log: jest.Mock };
  cashier?: CashierService;
}) {
  const repo = {
    findOrderById: jest.fn().mockResolvedValue(order),
    listEvents: jest.fn().mockResolvedValue([]),
    listPhotos: jest.fn().mockResolvedValue([]),
    listOrders: jest
      .fn()
      .mockResolvedValue({ items: [order], total: 1 }),
    setStatusFields: jest.fn().mockResolvedValue(undefined),
    ...(over.repo ?? {}),
  };
  const audit = over.audit ?? { log: jest.fn().mockResolvedValue(undefined) };
  const svc = new OsService(
    tenant,
    repo as never,
    audit as never,
    {} as never, // customers
    {} as never, // inventory
    {} as never, // messages
    {} as never, // iam
    over.cashier ?? new FakeCashierService(),
    {} as never, // storage
  );
  return { svc, repo, audit };
}

describe('OsService — pagamento', () => {
  it('getOrderOrThrow inclui o resumo de pagamento (nada recebido ⇒ a_receber)', async () => {
    const { svc } = makeService({});
    const result = (await svc.getOrderOrThrow('os1')) as { payment: unknown };
    expect(result.payment).toEqual({
      total: 150,
      paid: 0,
      balance: 150,
      status: 'a_receber',
    });
  });

  it('listOrders enriquece cada linha com payment_status', async () => {
    const { svc } = makeService({});
    const page = (await svc.listOrders(user, {})) as {
      items: Array<{ payment_status: string }>;
    };
    expect(page.items[0].payment_status).toBe('a_receber');
  });
});
