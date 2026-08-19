import { ReceivablesService } from './receivables.service';
import type { AuthUser } from '../../common/auth/auth.types';

/**
 * Controle de fiado — composição pura sobre os services públicos de OS e Vendas.
 *
 * O que este módulo decide (e portanto o que se testa aqui): o que CONTA como
 * dívida, como a dívida é agrupada por cliente, e que a varredura não omite
 * títulos em silêncio.
 */

const user = { tenantId: 't1', userId: 'u1', role: 'owner' } as unknown as AuthUser;

const pagamento = (total: number, paid: number) => ({
  total,
  paid,
  balance: Math.max(0, total - paid),
  status: paid <= 0 ? 'a_receber' : paid >= total ? 'pago' : 'parcial',
});

type Linha = Record<string, unknown>;
type Query = { page?: number; status?: string; pageSize?: number };

/** Fábrica de OS/venda como as listagens as devolvem (snake_case + payment). */
const linha = (over: Linha = {}): Linha => ({
  id: 'id-1',
  number: 'OS-0001',
  status: 'concluida',
  customer_id: 'c1',
  customer_name: 'João Silva',
  created_at: new Date('2026-07-01T10:00:00Z'),
  payment: pagamento(100, 0),
  items: [],
  ...over,
});

function makeService(opts: {
  os?: Linha[];
  vendas?: Linha[];
  osTotal?: number;
  vendasTotal?: number;
  detalhe?: (id: string) => Linha;
}) {
  const os = {
    listOrders: jest.fn(async (_u: AuthUser, q: Query) => {
      const items = q.page === 1 ? (opts.os ?? []) : [];
      return { items, total: opts.osTotal ?? (opts.os ?? []).length };
    }),
    getOrderOrThrow: jest.fn(async (id: string) =>
      opts.detalhe ? opts.detalhe(id) : { items: [] },
    ),
  };
  const sales = {
    listSales: jest.fn(async (_u: AuthUser, q: Query) => {
      const items = q.page === 1 ? (opts.vendas ?? []) : [];
      return { items, total: opts.vendasTotal ?? (opts.vendas ?? []).length };
    }),
  };
  return {
    service: new ReceivablesService(
      os as unknown as ConstructorParameters<typeof ReceivablesService>[0],
      sales as unknown as ConstructorParameters<typeof ReceivablesService>[1],
    ),
    os,
    sales,
  };
}

describe('ReceivablesService — o que conta como dívida', () => {
  it('título totalmente pago NÃO é fiado', async () => {
    const { service } = makeService({
      os: [linha({ payment: pagamento(100, 100) })],
    });
    const r = await service.listCustomers(user);
    expect(r.items).toHaveLength(0);
    expect(r.totalDue).toBe(0);
  });

  it('resíduo de centavo não vira dívida', async () => {
    // Saldo de meio centavo é arredondamento, não fiado (tolerância EPS).
    const { service } = makeService({
      os: [linha({ payment: { total: 100, paid: 99.998, balance: 0.002 } })],
    });
    const r = await service.listCustomers(user);
    expect(r.items).toHaveLength(0);
  });

  it('nada recebido ⇒ a_receber; parte recebida ⇒ parcial', async () => {
    const { service } = makeService({
      os: [
        linha({ id: 'a', payment: pagamento(100, 0) }),
        linha({ id: 'b', number: 'OS-0002', payment: pagamento(100, 40) }),
      ],
    });
    const r = await service.listTitles(user, 'c1');
    expect(r.items.map((t) => t.status)).toEqual(['a_receber', 'parcial']);
    expect(r.items.map((t) => t.balance)).toEqual([100, 60]);
    expect(r.totalDue).toBe(160);
  });

  it('OS cancelada não é dívida', async () => {
    const { service } = makeService({
      os: [linha({ status: 'cancelada', payment: pagamento(100, 0) })],
    });
    expect((await service.listCustomers(user)).items).toHaveLength(0);
  });

  it('venda cancelada não é dívida', async () => {
    const { service } = makeService({
      vendas: [linha({ status: 'canceled', payment: pagamento(100, 0) })],
    });
    expect((await service.listCustomers(user)).items).toHaveLength(0);
  });

  it('sem resumo de pagamento (caixa Noop) não inventa dívida', async () => {
    const { service } = makeService({ os: [linha({ payment: null })] });
    expect((await service.listCustomers(user)).items).toHaveLength(0);
  });
});

describe('ReceivablesService — agrupamento por cliente', () => {
  it('soma OS e vendas do mesmo cliente num único saldo', async () => {
    const { service } = makeService({
      os: [linha({ id: 'os1', payment: pagamento(100, 0) })],
      vendas: [
        linha({ id: 'v1', number: '15', status: 'active', payment: pagamento(50, 20) }),
      ],
    });
    const r = await service.listCustomers(user);
    expect(r.items).toHaveLength(1);
    expect(r.items[0].customerName).toBe('João Silva');
    expect(r.items[0].totalDue).toBe(130); // 100 + 30
    expect(r.items[0].titleCount).toBe(2);
    expect(r.totalDue).toBe(130);
  });

  it('ordena do maior devedor para o menor', async () => {
    const { service } = makeService({
      os: [
        linha({ id: 'a', customer_id: 'c1', customer_name: 'Ana', payment: pagamento(50, 0) }),
        linha({ id: 'b', customer_id: 'c2', customer_name: 'Bruno', payment: pagamento(300, 0) }),
        linha({ id: 'c', customer_id: 'c3', customer_name: 'Carla', payment: pagamento(120, 0) }),
      ],
    });
    const r = await service.listCustomers(user);
    expect(r.items.map((c) => c.customerName)).toEqual(['Bruno', 'Carla', 'Ana']);
  });

  it('guarda a data do título mais antigo ("deve desde quando")', async () => {
    const { service } = makeService({
      os: [
        linha({ id: 'novo', created_at: new Date('2026-07-20T10:00:00Z') }),
        linha({ id: 'velho', created_at: new Date('2026-05-02T10:00:00Z') }),
      ],
    });
    const r = await service.listCustomers(user);
    expect(r.items[0].oldestAt).toBe('2026-05-02T10:00:00.000Z');
  });

  it('venda de balcão sem cliente fica num balde próprio', async () => {
    const { service } = makeService({
      vendas: [
        linha({
          id: 'v1',
          status: 'active',
          customer_id: null,
          customer_name: null,
          payment: pagamento(80, 0),
        }),
      ],
    });
    const r = await service.listCustomers(user);
    expect(r.items[0].customerId).toBeNull();
    expect(r.items[0].customerName).toBe('Sem cliente');

    const titulos = await service.listTitles(user, null);
    expect(titulos.items).toHaveLength(1);
    expect(titulos.totalDue).toBe(80);
  });

  it('títulos de um cliente não vazam para outro', async () => {
    const { service } = makeService({
      os: [
        linha({ id: 'a', customer_id: 'c1', customer_name: 'Ana' }),
        linha({ id: 'b', customer_id: 'c2', customer_name: 'Bruno' }),
      ],
    });
    const r = await service.listTitles(user, 'c1');
    expect(r.items.map((t) => t.id)).toEqual(['a']);
    expect(r.customerName).toBe('Ana');
  });
});

describe('ReceivablesService — detalhamento dos itens', () => {
  it('venda já traz os itens da própria listagem', async () => {
    const { service, os } = makeService({
      vendas: [
        linha({
          id: 'v1',
          status: 'active',
          items: [
            { name: 'Óleo 5W30', kind: 'product', quantity: 4, unit_price: 45, total: 180 },
          ],
        }),
      ],
    });
    const r = await service.listTitles(user, 'c1');
    expect(r.items[0].items).toEqual([
      { name: 'Óleo 5W30', kind: 'product', quantity: 4, unitPrice: 45, total: 180 },
    ]);
    // Não precisou do detalhe da OS.
    expect(os.getOrderOrThrow).not.toHaveBeenCalled();
  });

  it('OS busca os itens no detalhe (a listagem não os traz)', async () => {
    const { service, os } = makeService({
      os: [linha({ id: 'os1' })],
      detalhe: () => ({
        items: [
          { name: 'Mão de obra', kind: 'service', quantity: 2, unit_price: 90, total: 180 },
        ],
      }),
    });
    const r = await service.listTitles(user, 'c1');
    expect(os.getOrderOrThrow).toHaveBeenCalledWith('os1', 't1');
    expect(r.items[0].items[0].name).toBe('Mão de obra');
    expect(r.items[0].items[0].unitPrice).toBe(90);
  });

  it('falha ao detalhar não derruba o título (o saldo é o que importa)', async () => {
    const { service } = makeService({
      os: [linha({ id: 'os1' })],
      detalhe: () => {
        throw new Error('indisponível');
      },
    });
    const r = await service.listTitles(user, 'c1');
    expect(r.items).toHaveLength(1);
    expect(r.items[0].balance).toBe(100);
    expect(r.items[0].items).toEqual([]);
  });

  it('a visão agregada NÃO busca detalhe de OS (evita N+1 na carteira)', async () => {
    const { service, os } = makeService({ os: [linha({ id: 'os1' })] });
    await service.listCustomers(user);
    expect(os.getOrderOrThrow).not.toHaveBeenCalled();
  });
});

/**
 * Listagem ACHATADA — existe para o histórico do caixa poder mostrar a OS que
 * ficou fiada. Antes o histórico listava venda em fiado e não OS em fiado: o
 * mesmo fato aparecia numa tela e sumia na outra.
 */
describe('ReceivablesService — títulos em aberto achatados', () => {
  it('devolve OS e venda juntas, cada uma com o próprio dono', async () => {
    const { service } = makeService({
      os: [linha({ id: 'os-1', payment: pagamento(300, 0) })],
      vendas: [
        linha({
          id: 'v-1',
          number: '15',
          status: 'active',
          customer_id: 'c2',
          customer_name: 'Maria Souza',
          payment: pagamento(150, 50),
        }),
      ],
    });
    const r = await service.listOpenTitles(user);
    expect(r.items).toHaveLength(2);
    expect(r.items.map((t) => [t.origin, t.customerName])).toEqual(
      expect.arrayContaining([
        ['os', 'João Silva'],
        ['sale', 'Maria Souza'],
      ]),
    );
    expect(r.totalDue).toBe(400);
  });

  it('ordena do mais recente para o mais antigo', async () => {
    const { service } = makeService({
      os: [
        linha({ id: 'velha', created_at: new Date('2026-07-01T10:00:00Z') }),
        linha({ id: 'nova', created_at: new Date('2026-08-10T10:00:00Z') }),
      ],
    });
    const r = await service.listOpenTitles(user);
    expect(r.items.map((t) => t.id)).toEqual(['nova', 'velha']);
  });

  it('título quitado não entra (mesma régua do resto do módulo)', async () => {
    const { service } = makeService({
      os: [linha({ id: 'paga', payment: pagamento(100, 100) })],
    });
    const r = await service.listOpenTitles(user);
    expect(r.items).toHaveLength(0);
    expect(r.totalDue).toBe(0);
  });

  it('venda de balcão sem cliente vem com customerId nulo', async () => {
    const { service } = makeService({
      vendas: [
        linha({
          id: 'v-1',
          status: 'active',
          customer_id: null,
          customer_name: null,
          payment: pagamento(80, 0),
        }),
      ],
    });
    const r = await service.listOpenTitles(user);
    expect(r.items[0].customerId).toBeNull();
    expect(r.items[0].customerName).toBe('Sem cliente');
  });

  it('não busca o detalhe da OS (o histórico quer quem/quanto, não itens)', async () => {
    const { service, os } = makeService({
      os: [linha({ id: 'os-1' })],
    });
    await service.listOpenTitles(user);
    expect(os.getOrderOrThrow).not.toHaveBeenCalled();
  });
});

describe('ReceivablesService — varredura', () => {
  it('não sinaliza truncamento quando leu tudo', async () => {
    const { service } = makeService({ os: [linha()], osTotal: 1 });
    expect((await service.listCustomers(user)).truncated).toBe(false);
  });

  it('para de paginar quando a fonte esgota (não entra em loop)', async () => {
    // Página 2 vazia = acabou, mesmo que `total` diga o contrário.
    const { service, os } = makeService({ os: [linha()], osTotal: 999_999 });
    const r = await service.listCustomers(user);
    expect(r.truncated).toBe(false);
    expect(os.listOrders.mock.calls.length).toBeLessThanOrEqual(2);
  });

  it('sinaliza truncated quando a carteira excede o teto da varredura', async () => {
    // Fonte "infinita": toda página vem cheia, então a varredura bate no teto e
    // precisa AVISAR — omitir dívida em silêncio seria pior que um aviso.
    const cheia = Array.from({ length: 100 }, (_, i) =>
      linha({ id: `os-${i}`, customer_id: `c-${i}`, customer_name: `Cliente ${i}` }),
    );
    const os = {
      listOrders: jest.fn(async () => ({ items: cheia, total: 999_999 })),
      getOrderOrThrow: jest.fn(),
    };
    const sales = { listSales: jest.fn(async () => ({ items: [], total: 0 })) };
    const service = new ReceivablesService(
      os as unknown as ConstructorParameters<typeof ReceivablesService>[0],
      sales as unknown as ConstructorParameters<typeof ReceivablesService>[1],
    );

    const r = await service.listCustomers(user);
    expect(r.truncated).toBe(true);
    // Respeita o teto de páginas (não varre a tabela inteira).
    expect(os.listOrders.mock.calls.length).toBe(10);
  });

  it('cobra ambas as fontes (OS e vendas) em paralelo', async () => {
    const { service, os, sales } = makeService({ os: [], vendas: [] });
    await service.listCustomers(user);
    expect(os.listOrders).toHaveBeenCalled();
    expect(sales.listSales).toHaveBeenCalled();
    // Vendas canceladas não interessam: pede só as ativas.
    expect(sales.listSales.mock.calls[0][1]).toMatchObject({ status: 'active' });
  });
});
