import { ConflictException } from '@nestjs/common';
import { SaleService } from './sale.service';
import type { AuthUser } from '../../common/auth/auth.types';

/**
 * Editar os ITENS de uma venda registrada.
 *
 * O que estes testes protegem são as duas coisas que a edição não pode quebrar:
 *  - **nota fiscal emitida**: mudar o total faria a NF divergir do que declara;
 *  - **total abaixo do já pago**: ficaríamos devendo troco, e não existe crédito
 *    para representar isso — o dinheiro simplesmente desapareceria da conta.
 *
 * E a armadilha do estoque: reconciliar é keyed pelo id da LINHA, então trocar as
 * linhas sem zerar o consumo das antigas deixaria o produto baixado para sempre.
 */

const user: AuthUser = {
  userId: 'u1',
  tenantId: 't1',
  role: 'owner',
  jti: 'j1',
} as AuthUser;

type Row = Record<string, unknown>;

interface Cenario {
  total?: number;
  discount?: number;
  fiscalStatus?: string | null;
  pago?: number;
  itens?: Row[];
}

function makeService(c: Cenario = {}) {
  const venda: Row = {
    id: 's1',
    tenant_id: 't1',
    status: 'active',
    total: c.total ?? 100,
    discount: c.discount ?? 0,
    fiscal_status: c.fiscalStatus ?? null,
  };
  let itens: Row[] = c.itens ?? [
    {
      id: 'li-1',
      kind: 'product',
      inventory_item_id: 'inv-1',
      name: 'Palheta',
      quantity: 2,
      unit_price: 50,
      subtotal: 100,
    },
  ];
  /** Chamadas de reconciliação: (linha, alvo) — o diário do estoque. */
  const reconciliacoes: Array<{ refItemId: string; targetQty: number }> = [];

  const repo = {
    findSaleById: () => Promise.resolve({ ...venda, items: itens }),
    listItems: () => Promise.resolve(itens),
    deleteItems: () => {
      itens = [];
      return Promise.resolve({ count: 0 });
    },
    addItem: (_t: string, _id: string, data: Row) => {
      const novo = { id: `li-nova-${itens.length + 1}`, ...data };
      itens.push(novo);
      return Promise.resolve(novo);
    },
    setCustomer: (_id: string, data: Row) => {
      Object.assign(venda, data);
      return Promise.resolve(venda);
    },
    setTotals: (_id: string, data: Row) => {
      Object.assign(venda, data);
      return Promise.resolve(venda);
    },
  };
  const tenant = { withTenantTx: <T>(fn: () => Promise<T>) => fn() };
  const audit = { log: () => Promise.resolve(undefined) };
  const customers = {
    getCustomer: () => Promise.resolve({ id: 'c1', name: 'João' }),
  };
  const inventory = {
    getItem: (id: string) =>
      Promise.resolve({ id, name: 'Palheta', kind: 'product', sale_price: 50 }),
    reconcileConsumption: (_t: string, args: Row) => {
      reconciliacoes.push({
        refItemId: args.refItemId as string,
        targetQty: args.targetQty as number,
      });
      return Promise.resolve();
    },
  };
  const cashier = {
    getPaymentSummary: (_t: string, _id: string, fallback: number) =>
      Promise.resolve({
        total: fallback,
        paid: c.pago ?? 0,
        balance: Math.max(0, fallback - (c.pago ?? 0)),
        status: 'x',
      }),
  };

  const service = new SaleService(
    tenant as never,
    repo as never,
    audit as never,
    customers as never,
    inventory as never,
    cashier as never,
  );
  return { service, venda, itens: () => itens, reconciliacoes };
}

describe('updateSale — editar itens', () => {
  it('substitui as linhas e recalcula o total no SERVIDOR', async () => {
    const { service, venda, itens } = makeService();
    await service.updateSale(user, 's1', {
      items: [
        { name: 'Filtro', kind: 'product', quantity: 3, unitPrice: 20 },
      ],
    });
    expect(venda.total).toBe(60); // 3 × 20 — nunca o total mandado pelo cliente
    expect(itens()).toHaveLength(1);
    expect(itens()[0].name).toBe('Filtro');
  });

  it('devolve o estoque das linhas ANTIGAS e consome as novas', async () => {
    // Reconciliar é keyed pelo id da linha: sem o alvo 0 na linha apagada, o
    // produto ficaria baixado para sempre.
    const { service, reconciliacoes } = makeService();
    await service.updateSale(user, 's1', {
      items: [
        { inventoryItemId: 'inv-2', quantity: 1 },
      ],
    });
    expect(reconciliacoes).toContainEqual({ refItemId: 'li-1', targetQty: 0 });
    // E a linha nova consome o que pede.
    expect(reconciliacoes.some((r) => r.targetQty === 1)).toBe(true);
  });

  it('item do estoque re-snapshota nome e preço do cadastro', async () => {
    const { service, venda, itens } = makeService();
    await service.updateSale(user, 's1', {
      items: [{ inventoryItemId: 'inv-9', quantity: 2 }],
    });
    expect(itens()[0].name).toBe('Palheta');
    expect(venda.total).toBe(100); // 2 × 50 (preço do cadastro)
  });

  it('aplica desconto sobre o novo bruto, clampado', async () => {
    const { service, venda } = makeService();
    await service.updateSale(user, 's1', {
      items: [{ name: 'X', quantity: 1, unitPrice: 100 }],
      discount: 30,
    });
    expect(venda.total).toBe(70);
    expect(venda.discount).toBe(30);
  });

  it('desconto maior que a venda não cria total negativo', async () => {
    const { service, venda } = makeService();
    await service.updateSale(user, 's1', {
      items: [{ name: 'X', quantity: 1, unitPrice: 40 }],
      discount: 500,
    });
    expect(venda.total).toBe(0);
    expect(venda.discount).toBe(40);
  });

  it('RECUSA quando a venda já tem nota fiscal', async () => {
    const { service } = makeService({ fiscalStatus: 'emitida' });
    await expect(
      service.updateSale(user, 's1', {
        items: [{ name: 'X', quantity: 1, unitPrice: 10 }],
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('nota REJEITADA não bloqueia (ela não vale)', async () => {
    const { service, venda } = makeService({ fiscalStatus: 'rejeitada' });
    await service.updateSale(user, 's1', {
      items: [{ name: 'X', quantity: 1, unitPrice: 10 }],
    });
    expect(venda.total).toBe(10);
  });

  it('RECUSA reduzir o total abaixo do que o cliente já pagou', async () => {
    // Sem esta guarda o pagamento excedente sumiria: `buildPaymentSummary`
    // clampa o saldo em 0 e ninguém saberia que devemos troco.
    const { service } = makeService({ total: 100, pago: 80 });
    await expect(
      service.updateSale(user, 's1', {
        items: [{ name: 'X', quantity: 1, unitPrice: 50 }],
      }),
    ).rejects.toThrow(/já pagou/);
  });

  it('aceita reduzir ATÉ o valor já pago', async () => {
    const { service, venda } = makeService({ total: 100, pago: 80 });
    await service.updateSale(user, 's1', {
      items: [{ name: 'X', quantity: 1, unitPrice: 80 }],
    });
    expect(venda.total).toBe(80);
  });

  it('AUMENTAR o total é sempre permitido (o saldo vira fiado)', async () => {
    const { service, venda } = makeService({ total: 100, pago: 100 });
    await service.updateSale(user, 's1', {
      items: [{ name: 'X', quantity: 1, unitPrice: 150 }],
    });
    expect(venda.total).toBe(150);
  });

  it('venda cancelada não se edita', async () => {
    const { service, venda } = makeService();
    venda.status = 'canceled';
    await expect(
      service.updateSale(user, 's1', {
        items: [{ name: 'X', quantity: 1, unitPrice: 10 }],
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('trocar SÓ o cliente não mexe em itens nem estoque', async () => {
    const { service, venda, itens, reconciliacoes } = makeService();
    await service.updateSale(user, 's1', { customerId: 'c1' });
    expect(venda.customer_id).toBe('c1');
    expect(venda.customer_name).toBe('João');
    expect(itens()).toHaveLength(1);
    expect(reconciliacoes).toEqual([]);
    expect(venda.total).toBe(100);
  });
});
