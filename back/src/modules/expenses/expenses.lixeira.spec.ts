import { ConflictException, NotFoundException } from '@nestjs/common';
import { ExpensesService } from './expenses.service';
import type { AuthUser } from '../../common/auth/auth.types';

/**
 * Unit da LIXEIRA: excluir (soft), restaurar e apagar de vez.
 *
 * Sem banco — o que se testa aqui é o ALCANCE de cada operação (uma conta ou a
 * compra parcelada inteira) e as travas do hard delete, que é irreversível.
 */
const user = {
  userId: 'u1',
  tenantId: 't1',
  role: 'owner',
} as unknown as AuthUser;

type Linha = {
  id: string;
  description: string;
  amount: number;
  status: 'active' | 'canceled';
  paid_at: Date | null;
  cash_entry_id: string | null;
  installment_no: number | null;
  installment_total: number | null;
  installment_group_id: string | null;
};

function parcela(n: number, over: Partial<Linha> = {}): Linha {
  return {
    id: `p${n}`,
    description: 'Compressor',
    amount: 150,
    status: 'active',
    paid_at: null,
    cash_entry_id: null,
    installment_no: n,
    installment_total: 6,
    installment_group_id: 'g1',
    ...over,
  };
}

function avulsa(over: Partial<Linha> = {}): Linha {
  return {
    id: 'e1',
    description: 'Aluguel',
    amount: 2500,
    status: 'active',
    paid_at: null,
    cash_entry_id: null,
    installment_no: null,
    installment_total: null,
    installment_group_id: null,
    ...over,
  };
}

function montar(linhas: Linha[]) {
  const repo = {
    findById: jest.fn((id: string) =>
      Promise.resolve(linhas.find((l) => l.id === id) ?? null),
    ),
    listInstallmentGroup: jest.fn((groupId: string) =>
      Promise.resolve(linhas.filter((l) => l.installment_group_id === groupId)),
    ),
    setStatusMany: jest.fn((ids: string[], status: 'active' | 'canceled') => {
      for (const l of linhas) if (ids.includes(l.id)) l.status = status;
      return Promise.resolve({ count: ids.length });
    }),
    deleteMany: jest.fn((ids: string[]) => Promise.resolve({ count: ids.length })),
    findRecurrence: jest.fn(() => Promise.resolve(null)),
  };
  const tenant = { withTenantTx: <T>(fn: () => Promise<T>) => fn() };
  const audit = { log: jest.fn(() => Promise.resolve()) };
  const cashier = { registrarSaidaDeDespesa: jest.fn(), estornarSaidaDeDespesa: jest.fn() };
  const cnpj = { fetch: jest.fn() };

  const service = new ExpensesService(
    tenant as never,
    repo as never,
    audit as never,
    cashier as never,
    cnpj as never,
  );
  return { service, repo, audit, linhas };
}

describe('expenses — lixeira (excluir / restaurar / apagar de vez)', () => {
  describe('excluir', () => {
    it('numa PARCELADA leva a compra inteira', async () => {
      // O bug que motivou isto: cancelar só a 3ª deixava as irmãs para trás e o
      // total da compra encolhia sozinho, com buraco na numeração.
      const grupo = [1, 2, 3, 4, 5, 6].map((n) => parcela(n));
      const { service, repo } = montar(grupo);

      await service.cancel(user, 'p3');

      expect(repo.setStatusMany).toHaveBeenCalledWith(
        ['p1', 'p2', 'p3', 'p4', 'p5', 'p6'],
        'canceled',
      );
      expect(grupo.every((p) => p.status === 'canceled')).toBe(true);
    });

    it('numa avulsa mexe só nela', async () => {
      const { service, repo } = montar([avulsa()]);
      await service.cancel(user, 'e1');
      expect(repo.setStatusMany).toHaveBeenCalledWith(['e1'], 'canceled');
    });

    it('QUALQUER parcela paga bloqueia a exclusão do grupo', async () => {
      // Desfazer a baixa é o que devolve o dinheiro ao caixa, e precisa ser
      // explícito — excluir não pode fazer isso por tabela.
      const grupo = [
        parcela(1, { paid_at: new Date(), cash_entry_id: 'c1' }),
        parcela(2),
      ];
      const { service, repo } = montar(grupo);

      await expect(service.cancel(user, 'p2')).rejects.toBeInstanceOf(
        ConflictException,
      );
      expect(repo.setStatusMany).not.toHaveBeenCalled();
    });

    it('excluir o que já está na lixeira é conflito', async () => {
      const { service } = montar([avulsa({ status: 'canceled' })]);
      await expect(service.cancel(user, 'e1')).rejects.toBeInstanceOf(
        ConflictException,
      );
    });

    it('id inexistente é 404', async () => {
      const { service } = montar([]);
      await expect(service.cancel(user, 'nao-existe')).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });
  });

  describe('restaurar', () => {
    it('devolve a compra parcelada INTEIRA', async () => {
      // Restaurar só uma deixaria o grupo pela metade — o mesmo estado
      // incoerente que o cancelamento por grupo evita.
      const grupo = [1, 2, 3].map((n) => parcela(n, { status: 'canceled' }));
      const { service, repo } = montar(grupo);

      await service.restore(user, 'p2');

      expect(repo.setStatusMany).toHaveBeenCalledWith(
        ['p1', 'p2', 'p3'],
        'active',
      );
    });

    it('restaurar o que não está excluído é conflito', async () => {
      const { service } = montar([avulsa()]);
      await expect(service.restore(user, 'e1')).rejects.toBeInstanceOf(
        ConflictException,
      );
    });
  });

  describe('apagar de vez (hard delete)', () => {
    it('apaga a compra inteira quando nada foi pago', async () => {
      const grupo = [1, 2].map((n) => parcela(n, { status: 'canceled' }));
      const { service, repo } = montar(grupo);

      await service.purge(user, 'p1');

      expect(repo.deleteMany).toHaveBeenCalledWith(['p1', 'p2']);
    });

    it('EXIGE estar na lixeira — não apaga direto da lista', async () => {
      // Apagar de verdade é sempre o segundo passo, para nunca ser um acidente
      // de um toque só.
      const { service, repo } = montar([avulsa()]);
      await expect(service.purge(user, 'e1')).rejects.toBeInstanceOf(
        ConflictException,
      );
      expect(repo.deleteMany).not.toHaveBeenCalled();
    });

    it('recusa quando há pagamento registrado no caixa', async () => {
      // O lançamento do caixa guarda o caminho de volta para esta despesa;
      // apagá-la deixaria o extrato com um clique que não abre nada.
      const { service, repo } = montar([
        avulsa({
          status: 'canceled',
          paid_at: new Date(),
          cash_entry_id: 'c1',
        }),
      ]);
      await expect(service.purge(user, 'e1')).rejects.toBeInstanceOf(
        ConflictException,
      );
      expect(repo.deleteMany).not.toHaveBeenCalled();
    });

    it('recusa o grupo inteiro se UMA irmã tiver pagamento', async () => {
      const grupo = [
        parcela(1, { status: 'canceled' }),
        parcela(2, {
          status: 'canceled',
          paid_at: new Date(),
          cash_entry_id: 'c1',
        }),
      ];
      const { service, repo } = montar(grupo);
      await expect(service.purge(user, 'p1')).rejects.toBeInstanceOf(
        ConflictException,
      );
      expect(repo.deleteMany).not.toHaveBeenCalled();
    });

    it('audita ANTES de apagar (depois não sobra linha para descrever)', async () => {
      const ordem: string[] = [];
      const { service, repo, audit } = montar([avulsa({ status: 'canceled' })]);
      audit.log.mockImplementation(() => {
        ordem.push('audit');
        return Promise.resolve();
      });
      repo.deleteMany.mockImplementation((ids: string[]) => {
        ordem.push('delete');
        return Promise.resolve({ count: ids.length });
      });

      await service.purge(user, 'e1');

      expect(ordem).toEqual(['audit', 'delete']);
      expect(audit.log).toHaveBeenCalledWith(
        't1',
        'u1',
        'expense_purge',
        'e1',
        expect.objectContaining({ description: 'Aluguel' }),
      );
    });
  });
});
