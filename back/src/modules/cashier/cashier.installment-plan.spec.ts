import { BadRequestException } from '@nestjs/common';
import { CashierServiceImpl } from './cashier.service.impl';

/**
 * Substituir um plano de prazo é como se CORRIGE uma combinação errada (data
 * trocada, número de parcelas errado). Sem isso, errar uma vez congelava a
 * cobrança: não há rota de editar nem de cancelar plano, e criar de novo era
 * recusado.
 *
 * A linha que não se cruza: parcela PAGA é dinheiro que entrou. Ela vira
 * histórico e nunca é apagada — só as em aberto dão lugar às novas.
 */
function makeService(pendentes: number) {
  const db = {
    receivable_installment: {
      count: jest.fn().mockResolvedValue(pendentes),
      deleteMany: jest.fn().mockResolvedValue({ count: pendentes }),
      createMany: jest.fn().mockResolvedValue({ count: 1 }),
    },
  };
  const tenant = {
    withTenantTx: <T>(fn: () => Promise<T> | T) => Promise.resolve(fn()),
    getClient: () => db,
  };
  const svc = new CashierServiceImpl(
    tenant as never,
    {} as never,
    {} as never,
    {} as never,
  );
  return { svc, db };
}

const user = { tenantId: 't1', userId: 'u1' } as never;
const base = {
  saleKind: 'sale' as const,
  saleId: '11111111-1111-4111-8111-111111111111',
  installmentCount: 1,
  dueDayOfMonth: 10,
  totalAmount: 80,
};

describe('createInstallmentPlan — corrigir um prazo combinado', () => {
  it('sem o flag, recusa quando já há plano pendente (comportamento antigo)', async () => {
    const { svc, db } = makeService(2);
    await expect(svc.createInstallmentPlan(user, { ...base })).rejects.toThrow(
      BadRequestException,
    );
    expect(db.receivable_installment.deleteMany).not.toHaveBeenCalled();
    expect(db.receivable_installment.createMany).not.toHaveBeenCalled();
  });

  it('com o flag, troca as parcelas EM ABERTO pelas novas', async () => {
    const { svc, db } = makeService(3);
    await svc.createInstallmentPlan(user, {
      ...base,
      substituirPendentes: true,
    });

    const where = db.receivable_installment.deleteMany.mock.calls[0][0].where;
    expect(where).toEqual({
      sale_kind: 'sale',
      sale_id: base.saleId,
      // O filtro é o que protege o dinheiro: só apaga o que está EM ABERTO.
      paid_at: null,
    });
    expect(db.receivable_installment.createMany).toHaveBeenCalled();
  });

  it('sem plano pendente, o flag não apaga nada — só cria', async () => {
    const { svc, db } = makeService(0);
    await svc.createInstallmentPlan(user, {
      ...base,
      substituirPendentes: true,
    });
    expect(db.receivable_installment.deleteMany).not.toHaveBeenCalled();
    expect(db.receivable_installment.createMany).toHaveBeenCalled();
  });
});
