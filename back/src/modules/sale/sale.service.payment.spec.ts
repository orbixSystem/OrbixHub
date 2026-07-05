import { ServiceUnavailableException } from '@nestjs/common';
import { SaleService } from './sale.service';
import { NoopInvoiceService } from '../invoice/noop-invoice.service';
import {
  buildPaymentSummary,
  CashierService,
} from '../cashier/cashier.service';
import type { FiscalResult, InvoiceService } from '../invoice/invoice.service';
import type { AuthUser } from '../../common/auth/auth.types';

/** Fake do contrato do Caixa: "nada recebido ⇒ a_receber" (caller-passes-total). */
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

const user: AuthUser = {
  userId: 'u1',
  tenantId: 't1',
  role: 'caixa',
  permissions: [],
} as unknown as AuthUser;

// TenantContext fake: roda o callback direto (sem tx real).
const tenant = {
  withTenantTx: <T>(fn: () => Promise<T> | T) => Promise.resolve(fn()),
  runWithTenant: <T>(_tid: string, fn: () => Promise<T> | T) =>
    Promise.resolve(fn()),
} as unknown as ConstructorParameters<typeof SaleService>[0];

const sale = {
  id: 's1',
  tenant_id: 't1',
  number: 'VND-0001',
  customer_id: null,
  customer_name: null,
  status: 'active',
  total: 80,
  items: [
    {
      id: 'si1',
      name: 'Óleo',
      kind: 'product',
      quantity: 2,
      unit_price: 40,
      subtotal: 80,
      inventory_item_id: 'inv1',
    },
  ],
};

function makeService(over: {
  repo?: Partial<Record<string, jest.Mock>>;
  audit?: { log: jest.Mock };
  cashier?: CashierService;
  invoice?: InvoiceService;
  inventory?: Partial<Record<string, jest.Mock>>;
}) {
  const repo = {
    findSaleById: jest.fn().mockResolvedValue(sale),
    listSales: jest.fn().mockResolvedValue({ items: [sale], total: 1 }),
    setFiscalSnapshot: jest.fn().mockResolvedValue(undefined),
    cancelSale: jest.fn().mockResolvedValue(undefined),
    ...(over.repo ?? {}),
  };
  const audit = over.audit ?? { log: jest.fn().mockResolvedValue(undefined) };
  const inventory = {
    reconcileConsumption: jest.fn().mockResolvedValue(undefined),
    ...(over.inventory ?? {}),
  };
  const svc = new SaleService(
    tenant,
    repo as never,
    audit as never,
    {} as never, // customers
    inventory as never,
    over.cashier ?? new FakeCashierService(),
    over.invoice ?? new NoopInvoiceService(),
  );
  return { svc, repo, audit, inventory };
}

describe('SaleService — pagamento', () => {
  it('getSaleOrThrow inclui o resumo de pagamento (Noop ⇒ a_receber)', async () => {
    const { svc } = makeService({});
    const result = (await svc.getSaleOrThrow('s1')) as {
      payment: unknown;
      payment_status: string;
    };
    expect(result.payment).toEqual({
      total: 80,
      paid: 0,
      balance: 80,
      status: 'a_receber',
    });
    expect(result.payment_status).toBe('a_receber');
  });

  it('listSales enriquece cada linha com payment_status', async () => {
    const { svc } = makeService({});
    const page = (await svc.listSales(user, {})) as {
      items: Array<{ payment_status: string }>;
    };
    expect(page.items[0].payment_status).toBe('a_receber');
  });

  it('venda cancelada não pergunta o caixa (payment null, status cancelada)', async () => {
    const cashier = {
      getPaymentSummary: jest.fn(),
      getPaymentSummaryBatch: jest.fn(),
    } as unknown as CashierService;
    const { svc } = makeService({
      cashier,
      repo: {
        findSaleById: jest
          .fn()
          .mockResolvedValue({ ...sale, status: 'canceled' }),
      },
    });
    const result = (await svc.getSaleOrThrow('s1')) as {
      payment: unknown;
      payment_status: string;
    };
    expect(result.payment).toBeNull();
    expect(result.payment_status).toBe('cancelada');
    expect((cashier.getPaymentSummary as jest.Mock)).not.toHaveBeenCalled();
  });
});

describe('SaleService — cancelamento estorna estoque', () => {
  it('cancela e devolve o estoque (targetQty 0) via InventoryService', async () => {
    const { svc, inventory, repo, audit } = makeService({});
    await svc.cancelSale(user, 's1', { reason: 'desistência' });
    expect(repo.cancelSale).toHaveBeenCalled();
    // devolveu o estoque do item-produto (reconcile com alvo 0, refType 'sale')
    expect(inventory.reconcileConsumption).toHaveBeenCalledWith(
      't1',
      expect.objectContaining({
        inventoryItemId: 'inv1',
        refType: 'sale',
        refId: 's1',
        targetQty: 0,
      }),
    );
    expect(audit.log).toHaveBeenCalledWith(
      't1',
      'u1',
      'sale_cancel',
      's1',
      expect.any(Object),
    );
  });
});

describe('SaleService — emitir nota fiscal', () => {
  it('chama o Fiscal (não o caixa), faz snapshot e audita', async () => {
    const fiscal: FiscalResult = {
      status: 'emitida',
      externalId: 'NFe-9',
      message: null,
    };
    const invoice = {
      isAvailable: () => true,
      emit: jest.fn().mockResolvedValue(fiscal),
    } as unknown as InvoiceService;
    const cashier = {
      getPaymentSummary: jest.fn(),
      getPaymentSummaryBatch: jest.fn(),
    } as unknown as CashierService;

    const { svc, repo, audit } = makeService({ invoice, cashier });
    const res = await svc.emitInvoice(user, 's1');

    expect(res).toEqual(fiscal);
    expect((invoice.emit as jest.Mock)).toHaveBeenCalledWith(
      't1',
      's1',
      expect.objectContaining({ vendaId: 's1', number: 'VND-0001', total: 80 }),
    );
    expect((cashier.getPaymentSummary as jest.Mock)).not.toHaveBeenCalled();
    expect(repo.setFiscalSnapshot).toHaveBeenCalledWith(
      's1',
      expect.objectContaining({
        fiscal_status: 'emitida',
        fiscal_external_id: 'NFe-9',
      }),
    );
    expect(audit.log).toHaveBeenCalledWith(
      't1',
      'u1',
      'sale_emit_invoice',
      's1',
      expect.objectContaining({ fiscalStatus: 'emitida' }),
    );
  });

  it('propaga 503 quando o Fiscal está indisponível (Noop) e não faz snapshot', async () => {
    const { svc, repo } = makeService({});
    await expect(svc.emitInvoice(user, 's1')).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
    expect(repo.setFiscalSnapshot).not.toHaveBeenCalled();
  });
});
