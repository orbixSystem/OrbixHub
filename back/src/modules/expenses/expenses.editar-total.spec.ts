import { BadRequestException, ConflictException } from '@nestjs/common';
import { ExpensesService } from './expenses.service';
import type { AuthUser } from '../../common/auth/auth.types';

/**
 * Editar o valor de uma compra PARCELADA.
 *
 * O bug que motivou isto: a compra de R$ 1.000 em 5x abria a edição com R$ 200 (o
 * valor da parcela) e salvava esse número. `amount` numa parcelada é o TOTAL, e o
 * serviço refaz o rateio pelas irmãs em aberto.
 *
 * O que não pode acontecer aqui: a soma das parcelas deixar de ser o total, e
 * parcela JÁ PAGA mudar de valor (o dinheiro dela já saiu e está no caixa).
 */
const user = {
  userId: 'u1',
  tenantId: 't1',
  role: 'owner',
} as unknown as AuthUser;

type Parc = {
  id: string;
  description: string;
  amount: number;
  status: string;
  paid_at: Date | null;
  paid_amount: number | null;
  cash_entry_id: string | null;
  installment_no: number | null;
  installment_total: number | null;
  installment_group_id: string | null;
  due_date: Date;
};

function parc(n: number, valor: number, pago = false): Parc {
  return {
    id: `p${n}`,
    description: 'Compressor',
    amount: valor,
    status: 'active',
    paid_at: pago ? new Date('2026-08-01') : null,
    paid_amount: pago ? valor : null,
    cash_entry_id: pago ? `c${n}` : null,
    installment_no: n,
    installment_total: 5,
    installment_group_id: 'g1',
    due_date: new Date(Date.UTC(2026, 7 + n - 1, 20)),
  };
}

function montar(linhas: Parc[]) {
  /** Valor final de cada parcela depois das gravações. */
  const gravado = new Map<string, number>();
  const repo = {
    findById: jest.fn((id: string) =>
      Promise.resolve(linhas.find((l) => l.id === id) ?? null),
    ),
    listInstallmentGroup: jest.fn(() => Promise.resolve(linhas)),
    findCategory: jest.fn(() => Promise.resolve({ id: 'c' })),
    update: jest.fn((id: string, patch: { amount?: number }) => {
      if (patch.amount !== undefined) gravado.set(id, patch.amount);
      return Promise.resolve({ ...linhas[0], ...patch });
    }),
  };
  const service = new ExpensesService(
    { withTenantTx: <T>(fn: () => Promise<T>) => fn() } as never,
    repo as never,
    { log: jest.fn(() => Promise.resolve()) } as never,
    { registrarSaidaDeDespesa: jest.fn() } as never,
    { fetch: jest.fn() } as never,
  );
  return { service, repo, gravado };
}

const somaCentavos = (vs: number[]) =>
  vs.reduce((a, v) => a + Math.round(v * 100), 0);

describe('editar o total de uma compra parcelada', () => {
  it('reparte o novo total entre TODAS quando nada foi pago', async () => {
    // 1000 em 5x = 200 cada. Sobe para 1500 → 300 cada.
    const grupo = [1, 2, 3, 4, 5].map((n) => parc(n, 200));
    const { service, gravado } = montar(grupo);

    await service.update(user, 'p1', { amount: 1500 });

    expect(gravado.get('p1')).toBe(300);
    expect([...gravado.values()]).toEqual([300, 300, 300, 300, 300]);
  });

  it('a SOMA fecha o total mesmo quando não divide redondo', async () => {
    const grupo = [1, 2, 3].map((n) => parc(n, 100));
    const { service, gravado } = montar(grupo);

    await service.update(user, 'p1', { amount: 100 });

    expect(somaCentavos([...gravado.values()])).toBe(10000);
    // Resto de centavos na PRIMEIRA em aberto, como na criação.
    expect(gravado.get('p1')).toBe(33.34);
    expect(gravado.get('p2')).toBe(33.33);
  });

  it('parcela JÁ PAGA não muda de valor e é abatida do total', async () => {
    // 1 e 2 pagas a 200 cada = 400 comprometidos; total sobe para 1200 → sobram
    // 800 para as 3 em aberto.
    const grupo = [
      parc(1, 200, true),
      parc(2, 200, true),
      parc(3, 200),
      parc(4, 200),
      parc(5, 200),
    ];
    const { service, gravado } = montar(grupo);

    await service.update(user, 'p3', { amount: 1200 });

    // As pagas não foram tocadas.
    expect(gravado.has('p1')).toBe(false);
    expect(gravado.has('p2')).toBe(false);
    // E as três em aberto somam exatamente os 800 que sobraram.
    expect(somaCentavos([...gravado.values()])).toBe(80000);
    expect(gravado.get('p3')).toBe(266.68); // resto na primeira em aberto
    expect(gravado.get('p4')).toBe(266.66);
    expect(gravado.get('p5')).toBe(266.66);
  });

  it('recusa total abaixo do que já foi pago', async () => {
    // 800 já comprometidos em 4 parcelas pagas; pedir 500 deixaria as em aberto
    // com valor negativo.
    const grupo = [
      parc(1, 200, true),
      parc(2, 200, true),
      parc(3, 200, true),
      parc(4, 200, true),
      parc(5, 200),
    ];
    const { service, gravado } = montar(grupo);

    await expect(service.update(user, 'p5', { amount: 500 })).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(gravado.size).toBe(0);
  });

  it('conta AVULSA continua editando o próprio valor', async () => {
    const avulsa: Parc = {
      ...parc(1, 2500),
      id: 'e1',
      installment_no: null,
      installment_total: null,
      installment_group_id: null,
    };
    const { service, repo } = montar([avulsa]);

    await service.update(user, 'e1', { amount: 3000 });

    expect(repo.listInstallmentGroup).not.toHaveBeenCalled();
    expect(repo.update).toHaveBeenCalledWith(
      'e1',
      expect.objectContaining({ amount: 3000 }),
    );
  });

  it('editar sem mexer no valor não redistribui nada', async () => {
    const grupo = [1, 2, 3].map((n) => parc(n, 200));
    const { service, gravado } = montar(grupo);

    await service.update(user, 'p1', { description: 'Compressor usado' });

    expect(gravado.size).toBe(0);
  });

  it('não deixa editar a partir de uma parcela JÁ PAGA', async () => {
    // Regra que já existia e continua: desfaça a baixa, corrija e pague de novo.
    const grupo = [parc(1, 200, true), parc(2, 200)];
    const { service } = montar(grupo);

    await expect(service.update(user, 'p1', { amount: 900 })).rejects.toBeInstanceOf(
      ConflictException,
    );
  });
});
