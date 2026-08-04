import 'reflect-metadata';
import { plainToInstance } from 'class-transformer';
import {
  PULL_ROUTES,
  SYNC_OPS,
  structuralCollisions,
  SyncServices,
} from './sync.registry';

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
    // Editar/corrigir lançamento é gestão, como o estorno: reescrever ou
    // relançar um movimento de dinheiro é tão sensível quanto estorná-lo.
    'cash_entry.update': 'cashier.manage',
    'cash_entry.correct': 'cashier.manage',
    // Despesas fixas são catálogo (preset), não dinheiro — mas decidir o que a
    // oficina gasta é gestão, igual às rotas HTTP equivalentes.
    'cash_expense_template.create': 'cashier.manage',
    'cash_expense_template.update': 'cashier.manage',
    'sale.create': 'sale.write',
    'sale.cancel': 'sale.write',
    'sale.update': 'sale.write',
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
      'sale.update',
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
      'cash_expense_template.create',
      'cash_session.open',
      'customer.create',
      'inventory_item.create',
      'sale.create',
      'service_order.create',
      'subject.create',
    ]);
  });

  it('addItem endereça a OS-pai por `orderId` (NUNCA `id`: CreateItemDto declara `id`)', () => {
    expect(SYNC_OPS['service_order.addItem'].structuralKeys).toEqual(['orderId']);
  });

  it('venda: create preserva o uuid pelo DTO (sem chave estrutural) e cancel endereça por id', () => {
    // `CreateSaleDto` DECLARA `id` (uuid gerado offline). Declarar `id` também
    // como chave estrutural seria a colisão de `addItem`: o roteamento apagaria
    // o campo do DTO. Aqui o id chega pelo próprio payload validado.
    expect(SYNC_OPS['sale.create'].structuralKeys).toBeUndefined();
    expect(SYNC_OPS['sale.create'].create).toBe(true);
    expect(SYNC_OPS['sale.cancel'].structuralKeys).toEqual(['id']);
    // Cancelar não é LWW: a reentrância é regra do service (não cancela 2×).
    expect(SYNC_OPS['sale.cancel'].lww).toBeUndefined();
  });

  it('correção de lançamento: `id` roteia o original, `newId` vai no DTO', () => {
    // O uuid do lançamento NOVO não pode ser chave estrutural: `id` já é (aponta
    // o original), e duas chaves de id no mesmo payload se confundiriam. Por isso
    // o DTO declara `newId`.
    expect(SYNC_OPS['cash_entry.correct'].structuralKeys).toEqual(['id']);
    const declarados = Object.keys(
      plainToInstance(SYNC_OPS['cash_entry.correct'].dto, {}),
    );
    expect(declarados).toContain('newId');
    expect(declarados).not.toContain('id');
  });

  it('nenhuma chave estrutural colide com um campo declarado do DTO da op', () => {
    // Uma colisão apaga a chave de roteamento na 2ª validação (o campo do DTO
    // vem `undefined` e sobrescreve o id) — foi o bug de perda de item da OS.
    expect(structuralCollisions()).toEqual([]);
  });

  it('sub-itens da OS extraem as chaves estruturais corretas do payload', () => {
    expect(SYNC_OPS['service_order.updateItem'].structuralKeys).toEqual(['id', 'itemId']);
    expect(SYNC_OPS['service_order.deleteItem'].structuralKeys).toEqual(['id', 'itemId']);
    expect(SYNC_OPS['service_order.applyTemplate'].structuralKeys).toEqual(['id', 'templateId']);
    expect(SYNC_OPS['subject.create'].structuralKeys).toEqual(['customerId']);
  });

  it('PULL_ROUTES cobre as 16 entidades dos 6 módulos donos, com permissão de LEITURA espelhando os GETs do controller dono', () => {
    // Permissões dos GETs reais: customers → customer.read; subjects →
    // subject.read; inventory → inventory.read; os → os.read; cashier →
    // cashier.read; sale → sale.read; mensagens (conversation/message) → os.read. O pull nunca
    // pode ser mais permissivo que o online (ex.: mechanic sem cashier.read não
    // pode puxar o extrato do caixa).
    const expected: Record<
      string,
      { service: keyof SyncServices; module: string; permission: string }
    > = {
      customer: { service: 'customers', module: 'customers', permission: 'customer.read' },
      subject: { service: 'customers', module: 'customers', permission: 'subject.read' },
      inventory_item: { service: 'inventory', module: 'inventory', permission: 'inventory.read' },
      stock_movement: { service: 'inventory', module: 'inventory', permission: 'inventory.read' },
      service_order: { service: 'os', module: 'os', permission: 'os.read' },
      service_order_item: { service: 'os', module: 'os', permission: 'os.read' },
      service_order_event: { service: 'os', module: 'os', permission: 'os.read' },
      service_order_photo: { service: 'os', module: 'os', permission: 'os.read' },
      service_order_template: { service: 'os', module: 'os', permission: 'os.read' },
      cash_session: { service: 'cashier', module: 'cashier', permission: 'cashier.read' },
      cash_entry: { service: 'cashier', module: 'cashier', permission: 'cashier.read' },
      cash_expense_template: {
        service: 'cashier',
        module: 'cashier',
        permission: 'cashier.read',
      },
      sale: { service: 'sale', module: 'sale', permission: 'sale.read' },
      sale_item: { service: 'sale', module: 'sale', permission: 'sale.read' },
      conversation: { service: 'messages', module: 'os', permission: 'os.read' },
      message: { service: 'messages', module: 'os', permission: 'os.read' },
    };
    expect(PULL_ROUTES).toEqual(expected);
  });

  it('toda op declara o módulo comercial dono (gating de plano/assinatura no /sync)', () => {
    const moduleOf: Record<string, string> = {
      customer: 'customers',
      subject: 'customers',
      inventory_item: 'inventory',
      service_order: 'os',
      cash_session: 'cashier',
      cash_entry: 'cashier',
      cash_expense_template: 'cashier',
      sale: 'sale',
    };
    for (const [key, def] of Object.entries(SYNC_OPS)) {
      expect(def.module).toBe(moduleOf[key.split('.')[0]]);
    }
  });

  it('toda rota de pull exige uma permissão *.read (nunca vazia)', () => {
    for (const route of Object.values(PULL_ROUTES)) {
      expect(route.permission).toMatch(/\.read$/);
      expect(route.service).toBeTruthy();
    }
  });
});
