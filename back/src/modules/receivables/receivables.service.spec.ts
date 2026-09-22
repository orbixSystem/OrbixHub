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
  // Fiado agora é DECLARADO, não derivado: um título só conta como dívida
  // depois de passar pelo caixa. A fixture representa dívida legítima, então
  // nasce declarada — os cenários que testam a regra de passagem sobrescrevem.
  fiado_at: new Date('2026-07-01T11:00:00Z'),
  items: [],
  ...over,
});

function makeService(opts: {
  os?: Linha[];
  vendas?: Linha[];
  osTotal?: number;
  vendasTotal?: number;
  detalhe?: (id: string) => Linha;
  /** `${origin}:${id}` → próxima parcela (YYYY-MM-DD). */
  parcelas?: Map<string, string>;
  contatos?: Array<{ id: string; name: string; phone: string | null }>;
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
  // Portas do caixa e de clientes — o padrão é "sem parcela, sem telefone";
  // cenários que precisam de vencimento por parcela sobrescrevem `parcelas`.
  const cashier = {
    proximasParcelasEmAberto: jest.fn(
      async (_tid: string, _refs: Array<{ saleKind: string; saleId: string }>) =>
        opts.parcelas ?? new Map<string, string>(),
    ),
  };
  const customers = {
    getCustomersByIds: jest.fn(
      async (_u: AuthUser, _ids: string[]) => opts.contatos ?? [],
    ),
  };
  return {
    service: new ReceivablesService(
      os as unknown as ConstructorParameters<typeof ReceivablesService>[0],
      sales as unknown as ConstructorParameters<typeof ReceivablesService>[1],
      cashier as unknown as ConstructorParameters<typeof ReceivablesService>[2],
      customers as unknown as ConstructorParameters<typeof ReceivablesService>[3],
    ),
    os,
    sales,
    cashier,
    customers,
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

describe('ReceivablesService — só é fiado depois de passar pelo caixa', () => {
  it('OS recém-aberta, nada recebido e não declarada, NÃO é fiado', async () => {
    // O bug que originou a mudança: a OS entrava na carteira de cobrança no
    // instante em que era criada, antes do serviço e de qualquer conversa
    // sobre pagamento.
    const { service } = makeService({
      os: [linha({ status: 'aberta', fiado_at: null, payment: pagamento(100, 0) })],
    });
    const r = await service.listCustomers(user);
    expect(r.items).toHaveLength(0);
    expect(r.totalDue).toBe(0);
  });

  it('recebimento PARCIAL já prova a passagem — vira fiado sem declaração', async () => {
    // Quem recebeu alguma coisa deixou lançamento no caixa; não precisa de
    // `fiado_at` para provar que passou por lá.
    const { service } = makeService({
      os: [linha({ status: 'aberta', fiado_at: null, payment: pagamento(100, 40) })],
    });
    const r = await service.listCustomers(user);
    expect(r.items).toHaveLength(1);
    expect(r.items[0].totalDue).toBe(60);
  });

  it('declarada com fiado_at e zero recebido É fiado', async () => {
    const { service } = makeService({
      os: [linha({ status: 'aberta', payment: pagamento(100, 0) })],
    });
    expect((await service.listCustomers(user)).items).toHaveLength(1);
  });

  it('OS finalizada sem acerto vira AVISO, não dívida', async () => {
    // Serviço entregue e não cobrado não pode simplesmente sumir: sai da
    // carteira, mas aparece como pendente de acerto.
    const { service } = makeService({
      os: [
        linha({ id: 'a', status: 'entregue', fiado_at: null, payment: pagamento(100, 0) }),
        linha({ id: 'b', status: 'concluida', fiado_at: null, payment: pagamento(50, 0) }),
      ],
    });
    const r = await service.listCustomers(user);
    expect(r.items).toHaveLength(0);
    expect(r.pendingSettlement).toEqual({ count: 2, total: 150 });
  });

  it('OS em andamento não entra nem no aviso', async () => {
    // Trabalho acontecendo não é dinheiro esquecido.
    const { service } = makeService({
      os: [linha({ status: 'aberta', fiado_at: null, payment: pagamento(100, 0) })],
    });
    expect((await service.listCustomers(user)).pendingSettlement).toEqual({
      count: 0,
      total: 0,
    });
  });

  it('venda de balcão sem acerto entra no aviso (é entregue no ato)', async () => {
    const { service } = makeService({
      vendas: [
        linha({ id: 'v1', status: 'active', fiado_at: null, payment: pagamento(80, 0) }),
      ],
    });
    const r = await service.listCustomers(user);
    expect(r.items).toHaveLength(0);
    expect(r.pendingSettlement).toEqual({ count: 1, total: 80 });
  });

  it('título já pago não vira aviso (não há o que acertar)', async () => {
    const { service } = makeService({
      os: [linha({ status: 'entregue', fiado_at: null, payment: pagamento(100, 100) })],
    });
    const r = await service.listCustomers(user);
    expect(r.items).toHaveLength(0);
    expect(r.pendingSettlement).toEqual({ count: 0, total: 0 });
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
      { proximasParcelasEmAberto: async () => new Map() } as never,
      { getCustomersByIds: async () => [] } as never,
    );

    const r = await service.listCustomers(user);
    expect(r.truncated).toBe(true);
    // Respeita o teto de páginas (não varre a tabela inteira).
    expect(os.listOrders.mock.calls.length).toBe(10);
  });

  describe('venda de balcao com APELIDO (customerNote) e sem cadastro', () => {
    // `CreateSaleDto.customerNote` grava um apelido livre ("Macarrao") em
    // `customer_name` quando NAO ha cliente cadastrado. Duas vendas assim, com
    // apelidos diferentes, viram DOIS devedores na carteira — mas os dois com
    // `customerId: null`.
    //
    // Foi o que a cliente filmou: abrir a aba de um apelido e ver a venda de
    // outro. Nao e vazamento entre empresas (tudo no mesmo tenant), mas e
    // dado errado na cara de quem cobra.
    const balcao = () => ({
      vendas: [
        linha({
          id: 's1',
          number: 'VND-0001',
          status: 'active',
          customer_id: null,
          customer_name: 'Macarrao',
          payment: pagamento(100, 0),
        }),
        linha({
          id: 's2',
          number: 'VND-0002',
          status: 'active',
          customer_id: null,
          customer_name: 'Rapaz da Hilux',
          payment: pagamento(50, 0),
        }),
      ],
    });

    it('a carteira separa os dois apelidos', async () => {
      const { service } = makeService(balcao());
      const r = await service.listCustomers(user);
      const nomes = r.items.map((i) => i.customerName).sort();
      expect(nomes).toEqual(['Macarrao', 'Rapaz da Hilux']);
    });

    it('abrir UM apelido nao pode mostrar a venda do OUTRO', async () => {
      const { service } = makeService(balcao());
      const r = await service.listTitles(user, null, 'Macarrao');
      expect(r.items.map((t) => t.number)).toEqual(['VND-0001']);
      expect(r.customerName).toBe('Macarrao');
      expect(r.totalDue).toBe(100);
    });

    it('sem apelido informado, devolve so o que e de fato anonimo', async () => {
      // "Sem cliente" e um grupo legitimo: venda sem apelido nenhum. Ela nao
      // pode arrastar junto as vendas apelidadas.
      const { service } = makeService({
        vendas: [
          ...balcao().vendas,
          linha({
            id: 's3',
            number: 'VND-0003',
            status: 'active',
          customer_id: null,
            customer_name: null,
            payment: pagamento(30, 0),
          }),
        ],
      });
      const r = await service.listTitles(user, null, null);
      expect(r.items.map((t) => t.number)).toEqual(['VND-0003']);
    });

    it('cliente CADASTRADO segue filtrando por id, ignorando apelido', async () => {
      const { service } = makeService({
        vendas: [
          linha({ id: 's1', number: 'VND-0001', status: 'active', customer_id: 'c1', customer_name: 'Joao' }),
          linha({ id: 's2', number: 'VND-0002', status: 'active', customer_id: 'c2', customer_name: 'Maria' }),
        ],
      });
      const r = await service.listTitles(user, 'c1');
      expect(r.items.map((t) => t.number)).toEqual(['VND-0001']);
    });
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

describe('listCustomers com filtros no SERVIDOR', () => {
  // Dois devedores fiados: v1 (Ana) com parcela VENCIDA, v2 (Bruno) sem parcela
  // e criado hoje (portanto a vencer / não vencido).
  const hoje = new Date();
  const fixtures = () => ({
    vendas: [
      // `status: 'active'`: o ramo de VENDAS pula qualquer outro status (o
      // default da fábrica, 'concluida', é vocabulário de OS).
      linha({
        id: 'v1', number: '1', status: 'active', customer_id: 'c1', customer_name: 'Ana',
        created_at: new Date('2026-01-10T10:00:00Z'), payment: pagamento(100, 0),
      }),
      linha({
        id: 'v2', number: '2', status: 'active', customer_id: 'c2', customer_name: 'Bruno',
        created_at: hoje, payment: pagamento(250, 0),
      }),
    ],
    parcelas: new Map([['sale:v1', '2026-01-20']]),
    contatos: [{ id: 'c1', name: 'Ana', phone: '(11) 9999-0001' }],
  });

  it('vencidos filtra a lista, mas totalDue continua o da carteira INTEIRA', async () => {
    const { service } = makeService(fixtures());
    const r = await service.listCustomers(user, { vencimento: 'vencidos' });
    expect(r.items.map((d) => d.customerName)).toEqual(['Ana']);
    expect(r.total).toBe(1);
    // "quanto tenho na rua" não muda quando se clica num chip.
    expect(r.totalDue).toBe(350);
    expect(r.overdueTotal).toBe(100);
    expect(r.overdueCount).toBe(1);
  });

  it('enriquece com telefone (só cadastrado) e próxima parcela', async () => {
    const { service } = makeService(fixtures());
    const r = await service.listCustomers(user, {});
    const ana = r.items.find((d) => d.customerName === 'Ana')!;
    const bruno = r.items.find((d) => d.customerName === 'Bruno')!;
    expect(ana.phone).toBe('(11) 9999-0001');
    expect(ana.nextDueAt).toBe('2026-01-20');
    expect(ana.overdue).toBe(true);
    expect(bruno.phone).toBeNull();
    expect(bruno.overdue).toBe(false);
  });

  it('a soma das páginas bate com o total', async () => {
    const { service } = makeService({
      vendas: ['a', 'b', 'c'].map((n, i) =>
        linha({ id: `v-${n}`, number: `${i}`, status: 'active', customer_id: `c-${n}`, customer_name: `Cliente ${n}`, payment: pagamento(10 * (i + 1), 0) }),
      ),
    });
    const p1 = await service.listCustomers(user, { page: 1, pageSize: 2 });
    const p2 = await service.listCustomers(user, { page: 2, pageSize: 2 });
    expect(p1.total).toBe(3);
    expect(p2.total).toBe(3);
    expect(p1.items.length + p2.items.length).toBe(3);
    // Nenhum devedor repetido entre as páginas.
    const ids = [...p1.items, ...p2.items].map((d) => d.customerId);
    expect(new Set(ids).size).toBe(3);
  });

  it('pede ao caixa a próxima parcela de TODOS os títulos numa chamada só', async () => {
    const { service, cashier } = makeService(fixtures());
    await service.listCustomers(user, {});
    expect(cashier.proximasParcelasEmAberto).toHaveBeenCalledTimes(1);
    const refs = cashier.proximasParcelasEmAberto.mock.calls[0][1];
    expect(refs).toHaveLength(2);
  });
});


/**
 * Bateria adversarial da carteira filtrada: os casos que não aparecem no uso
 * comum e por isso só quebrariam em produção — colisão de id entre módulos,
 * dado faltando, empates, busca com acento e os limites da paginação.
 */
describe('listCustomers — casos que quebram em produção, não no happy path', () => {
  const venda = (over: Record<string, unknown> = {}) =>
    linha({ status: 'active', ...over });

  describe('colisão de identificador entre OS e venda', () => {
    // OS e venda são tabelas diferentes: nada impede que um uuid se repita
    // entre elas (e no replay offline o id vem do cliente). A chave da próxima
    // parcela é `${saleKind}:${saleId}` justamente por isso — se fosse só o id,
    // o vencimento de uma venda vazaria para a OS de mesmo id.
    const mesmoId = 'id-colidido';

    it('não mistura o vencimento de uma com o da outra', async () => {
      const { service } = makeService({
        os: [
          linha({
            id: mesmoId, number: 'OS-1', customer_id: 'c1', customer_name: 'Ana',
            payment: pagamento(100, 0),
          }),
        ],
        vendas: [
          venda({
            id: mesmoId, number: '1', customer_id: 'c2', customer_name: 'Bruno',
            payment: pagamento(200, 0),
          }),
        ],
        // Só a VENDA tem prazo combinado.
        parcelas: new Map([[`sale:${mesmoId}`, '2099-01-10']]),
      });
      const r = await service.listCustomers(user, {});
      const ana = r.items.find((d) => d.customerName === 'Ana')!;
      const bruno = r.items.find((d) => d.customerName === 'Bruno')!;
      expect(bruno.nextDueAt).toBe('2099-01-10');
      expect(ana.nextDueAt).toBeNull();
    });

    it('cada uma continua sendo um título próprio', async () => {
      const { service } = makeService({
        os: [linha({ id: mesmoId, customer_id: 'c1', customer_name: 'Ana', payment: pagamento(100, 0) })],
        vendas: [venda({ id: mesmoId, customer_id: 'c1', customer_name: 'Ana', payment: pagamento(50, 0) })],
      });
      const r = await service.listCustomers(user, {});
      expect(r.items).toHaveLength(1);
      expect(r.items[0].titleCount).toBe(2);
      expect(r.items[0].totalDue).toBe(150);
    });
  });

  describe('dado faltando não derruba a carteira', () => {
    it('título sem data fica no fim da ordem por mais antigo', async () => {
      const { service } = makeService({
        vendas: [
          venda({ id: 'v1', customer_id: 'c1', customer_name: 'Sem data', created_at: null, payment: pagamento(10, 0) }),
          venda({ id: 'v2', customer_id: 'c2', customer_name: 'Com data', created_at: new Date('2020-01-01'), payment: pagamento(10, 0) }),
        ],
      });
      const r = await service.listCustomers(user, { sort: 'mais_antigo' });
      expect(r.items.map((d) => d.customerName)).toEqual(['Com data', 'Sem data']);
    });

    it('cliente cadastrado SEM telefone vem com phone nulo (não vazio)', async () => {
      const { service } = makeService({
        vendas: [venda({ id: 'v1', customer_id: 'c1', customer_name: 'Ana', payment: pagamento(10, 0) })],
        contatos: [{ id: 'c1', name: 'Ana', phone: null }],
      });
      const r = await service.listCustomers(user, {});
      expect(r.items[0].phone).toBeNull();
    });

    it('apelido (sem cadastro) nunca recebe telefone de ninguém', async () => {
      const { service } = makeService({
        vendas: [venda({ id: 'v1', customer_id: null, customer_name: 'Macarrão', payment: pagamento(10, 0) })],
        // Um contato existe na base, mas não é deste título.
        contatos: [{ id: 'c1', name: 'Ana', phone: '(11) 9999-0001' }],
      });
      const r = await service.listCustomers(user, {});
      expect(r.items[0].customerId).toBeNull();
      expect(r.items[0].phone).toBeNull();
    });
  });

  describe('busca', () => {
    const comNomes = () =>
      makeService({
        vendas: [
          venda({ id: 'v1', customer_id: 'c1', customer_name: 'José da Silva', payment: pagamento(10, 0) }),
          venda({ id: 'v2', customer_id: 'c2', customer_name: 'Maria Souza', payment: pagamento(20, 0) }),
        ],
      });

    it.each([
      ['jose', 'sem acento acha com acento'],
      ['JOSÉ', 'caixa alta acha minúscula'],
      ['  josé  ', 'espaços em volta não atrapalham'],
      ['silva', 'casa no meio do nome'],
    ])('busca "%s" — %s', async (q) => {
      const { service } = comNomes();
      const r = await service.listCustomers(user, { q });
      expect(r.items.map((d) => d.customerName)).toEqual(['José da Silva']);
    });

    it('busca sem resultado devolve lista vazia, mas mantém o total da carteira', async () => {
      const { service } = comNomes();
      const r = await service.listCustomers(user, { q: 'zzz' });
      expect(r.items).toEqual([]);
      expect(r.total).toBe(0);
      // O "na rua" é da carteira inteira: filtrar não faz dinheiro sumir.
      expect(r.totalDue).toBe(30);
    });

    it('busca em branco equivale a não buscar', async () => {
      const { service } = comNomes();
      const r = await service.listCustomers(user, { q: '   ' });
      expect(r.items).toHaveLength(2);
    });
  });

  describe('paginação nos limites', () => {
    const carteira = () =>
      makeService({
        vendas: Array.from({ length: 5 }, (_, i) =>
          venda({
            id: `v${i}`, customer_id: `c${i}`, customer_name: `Cliente ${i}`,
            payment: pagamento(10 * (i + 1), 0),
          }),
        ),
      });

    it('página além do fim devolve vazio SEM mentir no total', async () => {
      const { service } = carteira();
      const r = await service.listCustomers(user, { page: 99, pageSize: 2 });
      expect(r.items).toEqual([]);
      expect(r.total).toBe(5);
      expect(r.page).toBe(99);
      expect(r.totalDue).toBe(150);
    });

    it('a última página vem incompleta, não repetindo itens', async () => {
      const { service } = carteira();
      const p3 = await service.listCustomers(user, { page: 3, pageSize: 2 });
      expect(p3.items).toHaveLength(1);
    });

    it('filtrar e paginar juntos continua consistente', async () => {
      const { service } = carteira();
      const r = await service.listCustomers(user, { q: 'Cliente', page: 2, pageSize: 2 });
      expect(r.total).toBe(5);
      expect(r.items).toHaveLength(2);
    });
  });

  describe('origem', () => {
    // Um devedor com as DUAS origens precisa aparecer nos dois filtros — o
    // filtro é sobre os títulos dele, não sobre uma etiqueta do devedor.
    const misto = () =>
      makeService({
        os: [linha({ id: 'o1', customer_id: 'c1', customer_name: 'Ana', payment: pagamento(100, 0) })],
        vendas: [venda({ id: 'v1', customer_id: 'c1', customer_name: 'Ana', payment: pagamento(50, 0) })],
      });

    it('aparece em "só OS"', async () => {
      const { service } = misto();
      const r = await service.listCustomers(user, { origem: 'os' });
      expect(r.items).toHaveLength(1);
      // O saldo mostrado é o do DEVEDOR (as duas origens somadas): o filtro
      // escolhe quem aparece, não recalcula o que ele deve.
      expect(r.items[0].totalDue).toBe(150);
    });

    it('aparece em "só venda"', async () => {
      const { service } = misto();
      const r = await service.listCustomers(user, { origem: 'sale' });
      expect(r.items).toHaveLength(1);
    });
  });

  describe('empates', () => {
    it('mesmo valor desempata por nome, ignorando acento', async () => {
      const { service } = makeService({
        vendas: [
          venda({ id: 'v1', customer_id: 'c1', customer_name: 'Zeca', payment: pagamento(100, 0) }),
          venda({ id: 'v2', customer_id: 'c2', customer_name: 'Ána', payment: pagamento(100, 0) }),
          venda({ id: 'v3', customer_id: 'c3', customer_name: 'ana', payment: pagamento(100, 0) }),
        ],
      });
      const r = await service.listCustomers(user, { sort: 'valor' });
      // "Ána" e "ana" empatam entre si (mesma chave sem acento); o que importa
      // é que a ordem é estável e "Zeca" fica por último.
      expect(r.items[2].customerName).toBe('Zeca');
      expect(r.items.slice(0, 2).map((d) => d.customerName).sort()).toEqual(['ana', 'Ána']);
    });
  });

  describe('sem prazo combinado', () => {
    it('fiado antigo sem parcela NÃO é atraso e tem fila própria', async () => {
      const { service } = makeService({
        vendas: [
          venda({ id: 'v1', customer_id: 'c1', customer_name: 'Antigo', created_at: new Date('2020-01-01'), payment: pagamento(100, 0) }),
          venda({ id: 'v2', customer_id: 'c2', customer_name: 'Combinado', payment: pagamento(50, 0) }),
        ],
        parcelas: new Map([['sale:v2', '2099-01-10']]),
      });

      const vencidos = await service.listCustomers(user, { vencimento: 'vencidos' });
      expect(vencidos.items).toEqual([]);
      expect(vencidos.overdueTotal).toBe(0);

      const semPrazo = await service.listCustomers(user, { vencimento: 'sem_prazo' });
      expect(semPrazo.items.map((d) => d.customerName)).toEqual(['Antigo']);
    });
  });
});
