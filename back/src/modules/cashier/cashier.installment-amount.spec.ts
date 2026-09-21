import { Prisma } from '@prisma/client';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { CashierServiceImpl } from './cashier.service.impl';

/**
 * Corrigir o VALOR de uma parcela.
 *
 * O plano divide o total igualmente; a combinação real raramente é igual ("essa
 * eu pago 500, as outras menores"), e valor digitado errado acontece. Antes a
 * única saída era refazer o plano inteiro, o que reescreve as datas — quem só
 * queria mudar um número perdia o prazo combinado.
 *
 * A linha que não se cruza é a mesma de sempre: parcela PAGA já virou
 * lançamento no caixa. Mudar o valor dela deixaria o lançamento e a parcela
 * discordando para sempre, sem nada que explicasse a diferença.
 */
function makeService(parcela: Record<string, unknown> | null) {
  const db = {
    receivable_installment: {
      findFirst: jest.fn().mockResolvedValue(parcela),
      update: jest.fn().mockImplementation(({ data }: { data: unknown }) =>
        Promise.resolve({ ...parcela, ...(data as object) }),
      ),
    },
  };
  const audit = { log: jest.fn().mockResolvedValue(undefined) };
  const tenant = {
    withTenantTx: <T>(fn: () => Promise<T> | T) => Promise.resolve(fn()),
    getClient: () => db,
  };
  // Ordem do construtor: tenant, repo, billing, audit.
  const svc = new CashierServiceImpl(
    tenant as never,
    {} as never,
    {} as never,
    audit as never,
  );
  return { svc, db, audit };
}

const user = { tenantId: 't1', userId: 'u1' } as never;
const emAberto = {
  id: 'p2',
  sale_kind: 'sale',
  sale_id: '11111111-1111-4111-8111-111111111111',
  // Decimal, como o Postgres devolve — o serviço passa por `toNum`, e uma
  // string aqui esconderia isso.
  amount: new Prisma.Decimal(30),
  due_date: new Date('2026-10-10'),
  paid_at: null,
};

describe('updateInstallment — corrigir o valor de uma parcela', () => {
  it('grava o novo valor da parcela em aberto', async () => {
    const { svc, db } = makeService(emAberto);

    const out = await svc.updateInstallment(user, 'p2', { amount: 500 });

    expect(db.receivable_installment.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'p2' },
        data: expect.objectContaining({ amount: 500 }),
      }),
    );
    expect(out.amount).toBe(500);
  });

  it('arredonda para centavos — valor de dinheiro não tem terceira casa', async () => {
    const { svc, db } = makeService(emAberto);
    await svc.updateInstallment(user, 'p2', { amount: 33.333 });
    expect(db.receivable_installment.update.mock.calls[0][0].data.amount).toBe(
      33.33,
    );
  });

  it('recusa parcela JÁ PAGA (o lançamento no caixa já existe)', async () => {
    const { svc, db } = makeService({
      ...emAberto,
      paid_at: new Date('2026-09-20'),
    });

    await expect(
      svc.updateInstallment(user, 'p2', { amount: 500 }),
    ).rejects.toThrow(BadRequestException);
    expect(db.receivable_installment.update).not.toHaveBeenCalled();
  });

  it('recusa parcela inexistente (ou de outro tenant — a RLS a esconde)', async () => {
    const { svc, db } = makeService(null);

    await expect(
      svc.updateInstallment(user, 'nao-existe', { amount: 10 }),
    ).rejects.toThrow(NotFoundException);
    expect(db.receivable_installment.update).not.toHaveBeenCalled();
  });

  it('audita com o ANTES e o DEPOIS — é o que explica a diferença', async () => {
    const { svc, audit } = makeService(emAberto);

    await svc.updateInstallment(user, 'p2', {
      amount: 500,
      reason: 'cliente pediu para concentrar na primeira',
    });

    expect(audit.log).toHaveBeenCalledWith(
      't1',
      'u1',
      'installment_amount_update',
      'p2',
      {
        antes: 30,
        depois: 500,
        reason: 'cliente pediu para concentrar na primeira',
      },
    );
  });
});
