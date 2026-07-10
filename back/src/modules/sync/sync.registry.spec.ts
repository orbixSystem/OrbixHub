import 'reflect-metadata';
import { PULL_ROUTES, SYNC_OPS, SyncServices } from './sync.registry';

describe('sync registry — whitelist S7 + roteamento do pull', () => {
  // Mapa esperado entity.op → permissão (espelha o @Permissions da rota HTTP).
  const EXPECTED_PERMS: Record<string, string> = {
    'customer.create': 'customer.write',
    'customer.update': 'customer.write',
    'customer.archive': 'customer.write',
    'customer.unarchive': 'customer.write',
    'customer.delete': 'customer.write',
    'subject.create': 'subject.write',
    'subject.update': 'subject.write',
    'subject.archive': 'subject.write',
    'subject.unarchive': 'subject.write',
    'subject.delete': 'subject.write',
    'inventory_item.create': 'inventory.write',
    'inventory_item.update': 'inventory.write',
    'inventory_item.archive': 'inventory.write',
    'inventory_item.unarchive': 'inventory.write',
    'inventory_item.delete': 'inventory.write',
    'service_order.create': 'os.write',
    'service_order.update': 'os.write',
    'service_order.changeStatus': 'os.write',
    'service_order.addItem': 'os.write',
    'service_order.updateItem': 'os.write',
    'service_order.deleteItem': 'os.write',
    'service_order.createNote': 'os.write',
    'service_order.applyTemplate': 'os.write',
    'cash_session.open': 'cashier.manage',
    'cash_session.close': 'cashier.manage',
    'cash_entry.create': 'cashier.write',
    'cash_entry.reverse': 'cashier.manage',
  };

  it('expõe exatamente a whitelist de ops esperada (nada a mais, nada a menos)', () => {
    expect(Object.keys(SYNC_OPS).sort()).toEqual(Object.keys(EXPECTED_PERMS).sort());
  });

  it('cada op tem dto + apply e a permissão espelha a rota HTTP equivalente', () => {
    for (const [key, def] of Object.entries(SYNC_OPS)) {
      expect(typeof def.apply).toBe('function');
      expect(def.dto).toBeDefined();
      expect(def.permission).toBe(EXPECTED_PERMS[key]);
    }
  });

  it('caixa: abrir/fechar/estornar são cashier.manage (nunca rebaixa para cashier.write)', () => {
    expect(SYNC_OPS['cash_session.open'].permission).toBe('cashier.manage');
    expect(SYNC_OPS['cash_session.close'].permission).toBe('cashier.manage');
    expect(SYNC_OPS['cash_entry.reverse'].permission).toBe('cashier.manage');
    expect(SYNC_OPS['cash_entry.create'].permission).toBe('cashier.write');
  });

  it('só ops de update têm alvo LWW; creates e transições não', () => {
    const withLww = Object.entries(SYNC_OPS)
      .filter(([, d]) => d.lww)
      .map(([k]) => k)
      .sort();
    expect(withLww).toEqual([
      'customer.update',
      'inventory_item.update',
      'service_order.update',
      'subject.update',
    ]);
  });

  it('creates são marcados (recuperação de id duplicado — S9)', () => {
    const creates = Object.entries(SYNC_OPS)
      .filter(([, d]) => d.create)
      .map(([k]) => k)
      .sort();
    expect(creates).toEqual([
      'cash_entry.create',
      'cash_session.open',
      'customer.create',
      'inventory_item.create',
      'service_order.create',
      'subject.create',
    ]);
  });

  it('sub-itens da OS extraem as chaves estruturais corretas do payload', () => {
    expect(SYNC_OPS['service_order.updateItem'].structuralKeys).toEqual(['id', 'itemId']);
    expect(SYNC_OPS['service_order.deleteItem'].structuralKeys).toEqual(['id', 'itemId']);
    expect(SYNC_OPS['service_order.applyTemplate'].structuralKeys).toEqual(['id', 'templateId']);
    expect(SYNC_OPS['subject.create'].structuralKeys).toEqual(['customerId']);
  });

  it('PULL_ROUTES cobre as 11 entidades dos 4 módulos donos', () => {
    const expected: Record<string, keyof SyncServices> = {
      customer: 'customers',
      subject: 'customers',
      inventory_item: 'inventory',
      stock_movement: 'inventory',
      service_order: 'os',
      service_order_item: 'os',
      service_order_event: 'os',
      service_order_photo: 'os',
      service_order_template: 'os',
      cash_session: 'cashier',
      cash_entry: 'cashier',
    };
    expect(PULL_ROUTES).toEqual(expected);
  });
});
