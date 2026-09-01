import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { OrderLockRegistry } from './order-lock.registry';
import { OsService } from './os.service';
import { buildPaymentSummary, CashierService } from '../cashier/cashier.service';
import type { AuthUser } from '../../common/auth/auth.types';

/**
 * Unit da REABERTURA e da EXCLUSÃO de uma OS finalizada — as duas portas que
 * destravam uma OS `entregue`. O que estes testes protegem é o que quebraria
 * silenciosamente se alguém "simplificasse" as regras depois: carimbo de
 * conclusão reescrito (faturamento mudando de mês), peça sumida da prateleira,
 * dinheiro no extrato apontando para uma OS que não existe mais.
 */

const user: AuthUser = {
  userId: 'u1',
  tenantId: 't1',
  role: 'owner',
  permissions: [],
} as unknown as AuthUser;

const ENTREGUE_EM = new Date('2026-01-10T12:00:00Z');

/** OS entregue em janeiro, com uma peça baixada do estoque. */
const orderEntregue = () => ({
  id: 'os1',
  tenant_id: 't1',
  number: 'OS-0001',
  customer_id: 'c1',
  customer_name: 'Cliente Teste',
  status: 'entregue',
  total: 150,
  deleted_at: null,
  started_at: new Date('2026-01-08T09:00:00Z'),
  finished_at: ENTREGUE_EM,
  closed_at: ENTREGUE_EM,
  items: [
    {
      id: 'it1',
      name: 'Filtro',
      kind: 'product',
      quantity: 2,
      unit_price: 75,
      discount: 0,
      total: 150,
      inventory_item_id: 'inv1',
    },
  ],
});

/** Caixa fake: nada recebido e nenhuma parcela, salvo o que o teste pedir. */
class FakeCashier extends CashierService {
  constructor(
    private readonly pago = 0,
    private readonly parcelas = 0,
  ) {
    super();
  }
  async receivedBySale() {
    return new Map<string, { recebido: number; desconto: number }>();
  }
  async contarParcelasEmAberto() {
    return this.parcelas;
  }
  getPaymentSummary(_t: string, _v: string, fallbackTotal = 0) {
    return Promise.resolve(buildPaymentSummary(fallbackTotal, this.pago));
  }
  getPaymentSummaryBatch() {
    return Promise.resolve(
      new Map<string, ReturnType<typeof buildPaymentSummary>>(),
    );
  }
  listChangedSince() {
    return Promise.resolve({ rows: [], nextCursor: null, hasMore: false });
  }
  registrarSaidaDeDespesa() {
    return Promise.resolve({ id: 'entry-fake' });
  }
  estornarSaidaDeDespesa() {
    return Promise.resolve();
  }
}

function makeService(
  opts: {
    /** Permissões que o cargo do usuário tem (consulta crua no banco). */
    permissoes?: string[];
    cashier?: CashierService;
    /** Impedimento registrado por outro módulo (ex.: nota fiscal ativa). */
    impedimento?: string;
  } = {},
) {
  const order = orderEntregue();
  const permissoes = opts.permissoes ?? ['os.approve'];

  // TenantContext fake: roda o callback direto e responde à consulta de
  // permissão do `userHasPermission` (tabelas globais, sem RLS).
  const tenant = {
    withTenantTx: <T>(fn: () => Promise<T> | T) => Promise.resolve(fn()),
    runWithTenant: <T>(_tid: string, fn: () => Promise<T> | T) =>
      Promise.resolve(fn()),
    getClient: () => ({
      $queryRaw: (_sql: TemplateStringsArray, ...values: unknown[]) =>
        Promise.resolve(
          permissoes.includes(String(values[1])) ? [{ key: values[1] }] : [],
        ),
    }),
  } as unknown as ConstructorParameters<typeof OsService>[0];

  const repo = {
    findOrderById: jest.fn().mockResolvedValue(order),
    listEvents: jest.fn().mockResolvedValue([]),
    listPhotos: jest.fn().mockResolvedValue([]),
    listItems: jest.fn().mockResolvedValue(order.items),
    setStatusFields: jest.fn().mockResolvedValue(undefined),
    createEvent: jest.fn().mockResolvedValue(undefined),
    softDelete: jest.fn().mockResolvedValue({ id: order.id }),
  };
  const audit = { log: jest.fn().mockResolvedValue(undefined) };
  const inventory = {
    reconcileConsumption: jest.fn().mockResolvedValue(undefined),
  };
  const locks = new OrderLockRegistry();
  if (opts.impedimento) {
    const motivo = opts.impedimento;
    locks.registrar({ key: 'teste', motivo: () => Promise.resolve(motivo) });
  }

  const svc = new OsService(
    tenant,
    repo as never,
    audit as never,
    {} as never, // customers
    inventory as never,
    {} as never, // messages
    {} as never, // iam
    opts.cashier ?? new FakeCashier(),
    {} as never, // storage
    { emit: () => true } as never,
    { texto: () => undefined } as never,
    { getTenantVertical: async () => 'veiculos' } as never,
    locks,
  );
  return { svc, repo, audit, inventory };
}

describe('OsService — reabrir OS finalizada', () => {
  it('entregue → em_execucao é permitido para quem tem os.approve', async () => {
    const { svc, repo } = makeService();
    await svc.changeStatus(user, 'os1', { status: 'em_execucao' } as never);
    expect(repo.setStatusFields).toHaveBeenCalledWith(
      'os1',
      expect.objectContaining({ status: 'em_execucao' }),
    );
  });

  it('preserva finished_at e limpa closed_at (o faturamento não muda de mês)', async () => {
    const { svc, repo } = makeService();
    await svc.changeStatus(user, 'os1', { status: 'em_execucao' } as never);
    const fields = repo.setStatusFields.mock.calls[0][1] as {
      finished_at?: Date;
      started_at?: Date;
      closed_at?: Date | null;
    };
    // Carimbos já gravados não são reescritos — a OS foi concluída em janeiro
    // e continua contando como faturamento de janeiro.
    expect(fields.finished_at).toBeUndefined();
    expect(fields.started_at).toBeUndefined();
    // Mas ela deixou de estar entregue.
    expect(fields.closed_at).toBeNull();
  });

  it('sem os.approve não reabre', async () => {
    const { svc, repo } = makeService({ permissoes: ['os.write'] });
    await expect(
      svc.changeStatus(user, 'os1', { status: 'em_execucao' } as never),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(repo.setStatusFields).not.toHaveBeenCalled();
  });

  it('entregue → aberta segue sendo transição inválida (reabre em execução)', async () => {
    const { svc } = makeService();
    await expect(
      svc.changeStatus(user, 'os1', { status: 'aberta' } as never),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('nota fiscal ativa impede a reabertura', async () => {
    const { svc, repo } = makeService({
      impedimento: 'Esta OS tem nota fiscal ativa.',
    });
    await expect(
      svc.changeStatus(user, 'os1', { status: 'em_execucao' } as never),
    ).rejects.toThrow('Esta OS tem nota fiscal ativa.');
    expect(repo.setStatusFields).not.toHaveBeenCalled();
  });

  it('reabrir NÃO mexe no estoque (entregue e em_execucao consomem igual)', async () => {
    const { svc, inventory } = makeService();
    await svc.changeStatus(user, 'os1', { status: 'em_execucao' } as never);
    // A reconciliação roda, mas com o alvo IGUAL ao que já estava baixado.
    expect(inventory.reconcileConsumption).toHaveBeenCalledWith(
      't1',
      expect.objectContaining({ inventoryItemId: 'inv1', targetQty: 2 }),
    );
  });
});

describe('OsService — excluir OS finalizada', () => {
  it('exige os.approve', async () => {
    const { svc, repo } = makeService({ permissoes: ['os.write'] });
    await expect(svc.deleteOrder(user, 'os1')).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    expect(repo.softDelete).not.toHaveBeenCalled();
  });

  it('recusa quando há pagamento lançado no caixa', async () => {
    const { svc, repo } = makeService({ cashier: new FakeCashier(50) });
    await expect(svc.deleteOrder(user, 'os1')).rejects.toThrow(/Estorne/);
    expect(repo.softDelete).not.toHaveBeenCalled();
  });

  it('recusa quando há parcela de fiado em aberto', async () => {
    const { svc, repo } = makeService({ cashier: new FakeCashier(0, 3) });
    await expect(svc.deleteOrder(user, 'os1')).rejects.toThrow(/3 parcela/);
    expect(repo.softDelete).not.toHaveBeenCalled();
  });

  it('recusa quando há nota fiscal ativa', async () => {
    const { svc, repo } = makeService({
      impedimento: 'Esta OS tem nota fiscal ativa.',
    });
    await expect(svc.deleteOrder(user, 'os1')).rejects.toThrow(
      'Esta OS tem nota fiscal ativa.',
    );
    expect(repo.softDelete).not.toHaveBeenCalled();
  });

  it('sem pendência: exclui e DEVOLVE as peças ao estoque', async () => {
    const { svc, repo, inventory, audit } = makeService();
    await svc.deleteOrder(user, 'os1');
    expect(repo.softDelete).toHaveBeenCalledWith('os1');
    // Alvo 0 = a peça volta para a prateleira, ainda que o status diga
    // "entregue" (que normalmente consome).
    expect(inventory.reconcileConsumption).toHaveBeenCalledWith(
      't1',
      expect.objectContaining({ inventoryItemId: 'inv1', targetQty: 0 }),
    );
    expect(audit.log).toHaveBeenCalledWith(
      't1',
      'u1',
      'os_delete',
      'os1',
      expect.objectContaining({ status: 'entregue', itensDevolvidos: 1 }),
    );
  });
});
