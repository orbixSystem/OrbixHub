import { InventoryService } from './inventory.service';
import type { NotificationsService } from '../notifications/notifications.service';
import type { TenantContext } from '../../common/database/tenant-context';
import type { InventoryRepository } from './inventory.repository';

type Item = {
  id: string;
  name: string;
  kind: 'product' | 'service';
  unit: string | null;
  current_stock: number;
  min_stock: number | null;
  deleted_at: Date | null;
};

function makeService(item: Item) {
  const stored: Item = { ...item };
  const notify = jest.fn().mockResolvedValue(undefined);

  // tenant: executa o callback direto (sem banco real).
  const tenant = {
    runWithTenant: (_tid: string, fn: () => unknown) => fn(),
    withTenantTx: (fn: () => unknown) => fn(),
  } as unknown as TenantContext;

  const repo = {
    findItemById: async () => ({ ...stored }),
    adjustStock: async (_id: string, next: number) => {
      stored.current_stock = next;
      return { ...stored };
    },
    updateItem: async (_id: string, data: Record<string, unknown>) => {
      Object.assign(stored, data);
      return { ...stored };
    },
  } as unknown as InventoryRepository;

  const notifications = { notify } as unknown as NotificationsService;
  const audit = { log: jest.fn().mockResolvedValue(undefined) } as never;
  const noop = {} as never;

  // Ordem do construtor: tenant, repo, billing, audit, notifications,
  // catalogStore, catalog, env (ver inventory.service.ts).
  const svc = new InventoryService(
    tenant, repo, noop, audit, notifications, noop, noop, noop,
  );
  return { svc, notify };
}

const baseItem: Item = {
  id: 'item-1', name: 'Produto 0001', kind: 'product', unit: 'un',
  current_stock: 5, min_stock: 3, deleted_at: null,
};

describe('InventoryService — notificação de estoque baixo', () => {
  it('decrementStock cruzando o mínimo notifica 1x', async () => {
    const { svc, notify } = makeService(baseItem);
    await svc.decrementStock('t1', 'item-1', 3); // 5 -> 2 (<= 3)
    expect(notify).toHaveBeenCalledTimes(1);
    expect(notify).toHaveBeenCalledWith('t1', expect.objectContaining({
      type: 'inventory_low_stock',
      refType: 'inventory_item',
      refId: 'item-1',
    }));
  });

  it('decrementStock de item já baixo NÃO notifica', async () => {
    const { svc, notify } = makeService({ ...baseItem, current_stock: 2 });
    await svc.decrementStock('t1', 'item-1', 1); // 2 -> 1 (já baixo)
    expect(notify).not.toHaveBeenCalled();
  });

  it('decrementStock sem mínimo (Opção A) NÃO notifica', async () => {
    const { svc, notify } = makeService({ ...baseItem, min_stock: null });
    await svc.decrementStock('t1', 'item-1', 5); // 5 -> 0, sem mínimo
    expect(notify).not.toHaveBeenCalled();
  });

  it('updateItem reduzindo o saldo abaixo do mínimo notifica 1x', async () => {
    const { svc, notify } = makeService(baseItem);
    await svc.updateItem({ tenantId: 't1', userId: 'u1' } as never, 'item-1', {
      currentStock: 1,
    });
    expect(notify).toHaveBeenCalledTimes(1);
  });

  it('updateItem subindo o mínimo acima do saldo notifica 1x', async () => {
    const { svc, notify } = makeService(baseItem);
    await svc.updateItem({ tenantId: 't1', userId: 'u1' } as never, 'item-1', {
      minStock: 10,
    });
    expect(notify).toHaveBeenCalledTimes(1);
  });

  it('updateItem em serviço NÃO notifica mesmo que saldo fique baixo', async () => {
    const { svc, notify } = makeService({
      ...baseItem,
      kind: 'service',
      current_stock: 1,
      min_stock: 3,
    });
    await svc.updateItem({ tenantId: 't1', userId: 'u1' } as never, 'item-1', {
      currentStock: 0,
    });
    expect(notify).not.toHaveBeenCalled();
  });

  it('notify que falha não propaga (decrement conclui)', async () => {
    const { svc, notify } = makeService(baseItem);
    notify.mockRejectedValueOnce(new Error('down'));
    const res = await svc.decrementStock('t1', 'item-1', 3);
    expect((res as unknown as { current_stock: number }).current_stock).toBe(2);
  });
});
