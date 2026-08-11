import { OsService } from './os.service';
import type { AuthUser } from '../../common/auth/auth.types';
import type { ListOrdersQueryDto } from './dto/order.dto';

/**
 * `statuses` (CSV) é o filtro ADITIVO que sustenta o seletor simplificado de
 * 3 estados no front: "Em andamento" agrupa 4 status reais numa chamada só,
 * sem quebrar o filtro exato (`status`) que já existia.
 */

const user: AuthUser = {
  userId: 'u1',
  tenantId: 't1',
  role: 'owner',
} as unknown as AuthUser;

const tenant = {
  withTenantTx: <T>(fn: () => Promise<T> | T) => Promise.resolve(fn()),
  runWithTenant: <T>(_tid: string, fn: () => Promise<T> | T) =>
    Promise.resolve(fn()),
} as unknown as ConstructorParameters<typeof OsService>[0];

function makeService() {
  const repo = {
    listOrders: jest.fn().mockResolvedValue({ items: [], total: 0 }),
  };
  const cashier = {
    getPaymentSummaryBatch: jest.fn().mockResolvedValue(new Map()),
  };
  const svc = new OsService(
    tenant,
    repo as never,
    { log: jest.fn() } as never, // audit
    {} as never, // customers
    {} as never, // inventory
    {} as never, // messages
    {} as never, // iam
    cashier as never,
    {} as never, // storage
    { emit: () => true } as never,
  );
  return { svc, repo };
}

describe('OsService.listOrders — filtro de grupo de status (statuses)', () => {
  it('divide o CSV e descarta tokens que não são status reais', async () => {
    const { svc, repo } = makeService();
    await svc.listOrders(user, {
      statuses: 'aberta,aguardando_aprovacao,aprovada,em_execucao,bogus',
    } as ListOrdersQueryDto);

    expect(repo.listOrders).toHaveBeenCalledWith(
      expect.objectContaining({
        statuses: ['aberta', 'aguardando_aprovacao', 'aprovada', 'em_execucao'],
      }),
    );
  });

  it('sem `statuses`, não filtra por grupo (undefined) e mantém `status` exato',
    async () => {
      const { svc, repo } = makeService();
      await svc.listOrders(user, { status: 'concluida' } as ListOrdersQueryDto);

      expect(repo.listOrders).toHaveBeenCalledWith(
        expect.objectContaining({ status: 'concluida', statuses: undefined }),
      );
    });
});
