import { BadRequestException, ConflictException } from '@nestjs/common';
import { ExpensesService } from './expenses.service';
import type { AuthUser } from '../../common/auth/auth.types';

/**
 * Unit da PONTE com o Caixa — o pedaço que a cliente descreve como "dou baixa e
 * cai no caixa". Sem banco: o que importa aqui é a ORDEM das chamadas e o que
 * acontece quando cada lado falha.
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
  status: string;
  paid_at: Date | null;
  cash_entry_id: string | null;
};

function montar(over: Partial<Linha> = {}) {
  const linha: Linha = {
    id: 'e1',
    description: 'Aluguel',
    amount: 2500,
    status: 'active',
    paid_at: null,
    cash_entry_id: null,
    ...over,
  };

  const chamadas: string[] = [];
  const repo = {
    findById: jest.fn(() => Promise.resolve(linha)),
    setPayment: jest.fn((_id: string, patch: Record<string, unknown>) => {
      chamadas.push('repo.setPayment');
      Object.assign(linha, patch);
      return Promise.resolve(linha);
    }),
  };
  const cashier = {
    registrarSaidaDeDespesa: jest.fn(() => {
      chamadas.push('cashier.registrar');
      return Promise.resolve({ id: 'entry-1' });
    }),
    estornarSaidaDeDespesa: jest.fn(() => {
      chamadas.push('cashier.estornar');
      return Promise.resolve();
    }),
  };
  const tenant = {
    // Executa direto: não há banco neste unit.
    withTenantTx: <T>(fn: () => Promise<T>) => fn(),
  };
  const audit = { log: jest.fn(() => Promise.resolve()) };

  // Gateway de CNPJ: este unit não consulta nada fora, e passar `never` deixaria
  // claro no stack se algum caminho aqui tentasse consultar.
  const cnpj = { fetch: jest.fn() };

  const service = new ExpensesService(
    tenant as never,
    repo as never,
    audit as never,
    cashier as never,
    cnpj as never,
  );
  return { service, repo, cashier, audit, chamadas, linha };
}

describe('expenses — baixa espelhada no caixa', () => {
  it('pagar lança no caixa ANTES de gravar a baixa', async () => {
    // A ordem é a proteção: se a segunda etapa falhar, sobra um lançamento
    // visível e estornável. Na ordem inversa sobraria uma conta paga sem
    // registro no caixa — buraco silencioso no livro.
    const { service, chamadas } = montar();
    await service.pay(user, 'e1', { method: 'pix' });
    expect(chamadas).toEqual(['cashier.registrar', 'repo.setPayment']);
  });

  it('grava o id do lançamento na despesa (o único vínculo entre os módulos)', async () => {
    const { service, repo } = montar();
    await service.pay(user, 'e1', { method: 'pix' });
    expect(repo.setPayment).toHaveBeenCalledWith(
      'e1',
      expect.objectContaining({ cash_entry_id: 'entry-1', paid_amount: 2500 }),
    );
  });

  it('valor informado vence o previsto (juros/desconto)', async () => {
    const { service, cashier } = montar();
    await service.pay(user, 'e1', { amount: 2612.5, method: 'dinheiro' });
    expect(cashier.registrarSaidaDeDespesa).toHaveBeenCalledWith(
      user,
      expect.objectContaining({ amount: 2612.5, method: 'dinheiro' }),
    );
  });

  it('a forma padrão é dinheiro quando não informada', async () => {
    const { service, cashier } = montar();
    await service.pay(user, 'e1', {});
    expect(cashier.registrarSaidaDeDespesa).toHaveBeenCalledWith(
      user,
      expect.objectContaining({ method: 'dinheiro' }),
    );
  });

  it('conta "a confirmar" (valor 0) exige o valor na hora de pagar', async () => {
    // Sem isso o caixa registraria uma saída de zero — pior que recusar.
    const { service, cashier } = montar({ amount: 0 });
    await expect(service.pay(user, 'e1', {})).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(cashier.registrarSaidaDeDespesa).not.toHaveBeenCalled();
  });

  it('NÃO grava a baixa se o caixa recusar (ex.: caixa fechado)', async () => {
    const { service, repo, cashier } = montar();
    cashier.registrarSaidaDeDespesa.mockRejectedValueOnce(
      new BadRequestException('Não há caixa aberto.'),
    );
    await expect(service.pay(user, 'e1', {})).rejects.toBeInstanceOf(
      BadRequestException,
    );
    // O ponto do teste: a conta continua em aberto, coerente com o caixa.
    expect(repo.setPayment).not.toHaveBeenCalled();
  });

  it('pagar duas vezes é conflito, e o caixa nem é chamado', async () => {
    const { service, cashier } = montar({ paid_at: new Date() });
    await expect(service.pay(user, 'e1', {})).rejects.toBeInstanceOf(
      ConflictException,
    );
    expect(cashier.registrarSaidaDeDespesa).not.toHaveBeenCalled();
  });

  it('desfazer estorna no caixa ANTES de reabrir a conta', async () => {
    const { service, chamadas } = montar({
      paid_at: new Date(),
      cash_entry_id: 'entry-1',
    });
    await service.unpay(user, 'e1');
    expect(chamadas).toEqual(['cashier.estornar', 'repo.setPayment']);
  });

  it('desfazer limpa o vínculo com o caixa', async () => {
    const { service, repo } = montar({
      paid_at: new Date(),
      cash_entry_id: 'entry-1',
    });
    await service.unpay(user, 'e1');
    expect(repo.setPayment).toHaveBeenCalledWith(
      'e1',
      expect.objectContaining({ paid_at: null, cash_entry_id: null }),
    );
  });

  it('desfazer sem lançamento vinculado não chama o caixa', async () => {
    // Baixa antiga (anterior à ponte) ou registrada com o caixa desligado.
    const { service, cashier } = montar({
      paid_at: new Date(),
      cash_entry_id: null,
    });
    await service.unpay(user, 'e1');
    expect(cashier.estornarSaidaDeDespesa).not.toHaveBeenCalled();
  });

  it('despesa cancelada não aceita baixa', async () => {
    const { service } = montar({ status: 'canceled' });
    await expect(service.pay(user, 'e1', {})).rejects.toBeInstanceOf(
      ConflictException,
    );
  });

  describe('parcela se paga na ORDEM', () => {
    type Parc = {
      id: string;
      description: string;
      amount: number;
      status: string;
      paid_at: Date | null;
      cash_entry_id: string | null;
      installment_no: number;
      installment_total: number;
      installment_group_id: string;
      due_date: Date;
    };

    function parc(n: number, pago = false): Parc {
      return {
        id: `p${n}`,
        description: 'Compressor',
        amount: 100,
        status: 'active',
        paid_at: pago ? new Date('2026-08-01') : null,
        cash_entry_id: pago ? `c${n}` : null,
        installment_no: n,
        installment_total: 5,
        installment_group_id: 'g1',
        due_date: new Date(Date.UTC(2026, 7 + n - 1, 20)),
      };
    }

    function montarGrupo(linhas: Parc[]) {
      const repo = {
        findById: jest.fn((id: string) =>
          Promise.resolve(linhas.find((l) => l.id === id) ?? null),
        ),
        listInstallmentGroup: jest.fn(() => Promise.resolve(linhas)),
        setPayment: jest.fn(() => Promise.resolve(linhas[0])),
      };
      const cashier = {
        registrarSaidaDeDespesa: jest.fn(() => Promise.resolve({ id: 'e1' })),
        estornarSaidaDeDespesa: jest.fn(() => Promise.resolve()),
      };
      const service = new ExpensesService(
        { withTenantTx: <T>(fn: () => Promise<T>) => fn() } as never,
        repo as never,
        { log: jest.fn(() => Promise.resolve()) } as never,
        cashier as never,
        { fetch: jest.fn() } as never,
      );
      return { service, repo, cashier };
    }

    it('recusa a ÚLTIMA parcela com as anteriores em aberto', async () => {
      // O caso relatado: no mês da 5ª, as anteriores aparecem arrastadas e era
      // fácil dar baixa na errada.
      const { service, cashier } = montarGrupo([1, 2, 3, 4, 5].map((n) => parc(n)));
      await expect(service.pay(user, 'p5', {})).rejects.toThrow(
        /Pague antes a parcela 1\/5/,
      );
      // E o caixa nem é tocado: nada de saída lançada e depois desfeita.
      expect(cashier.registrarSaidaDeDespesa).not.toHaveBeenCalled();
    });

    it('a mensagem nomeia a MAIS ANTIGA em aberto, não a imediatamente anterior', async () => {
      // 1 e 2 abertas, 3 e 4 pagas: quem tenta a 5ª precisa saber que o buraco
      // começa na 1ª.
      const { service } = montarGrupo([
        parc(1),
        parc(2),
        parc(3, true),
        parc(4, true),
        parc(5),
      ]);
      await expect(service.pay(user, 'p5', {})).rejects.toThrow(
        /Pague antes a parcela 1\/5/,
      );
    });

    it('deixa pagar a primeira em aberto', async () => {
      const { service, cashier } = montarGrupo([1, 2, 3, 4, 5].map((n) => parc(n)));
      await service.pay(user, 'p1', {});
      expect(cashier.registrarSaidaDeDespesa).toHaveBeenCalled();
    });

    it('com as anteriores pagas, a vez é da seguinte', async () => {
      const { service, cashier } = montarGrupo([
        parc(1, true),
        parc(2, true),
        parc(3),
        parc(4),
        parc(5),
      ]);
      await service.pay(user, 'p3', {});
      expect(cashier.registrarSaidaDeDespesa).toHaveBeenCalled();
    });

    it('a ordem é por NÚMERO de parcela, não por vencimento', async () => {
      // Vencimento corrigido à mão (fornecedor deu mais prazo num mês) não pode
      // reordenar a dívida: a 1ª vence DEPOIS da 2ª aqui, e ainda assim é ela
      // que precisa ser paga primeiro — a data na mensagem prova qual linha o
      // serviço escolheu.
      const desordenado = [parc(1), parc(2)];
      desordenado[0].due_date = new Date(Date.UTC(2026, 11, 20)); // 1ª: dezembro
      desordenado[1].due_date = new Date(Date.UTC(2026, 7, 20)); //  2ª: agosto
      const { service } = montarGrupo(desordenado);
      await expect(service.pay(user, 'p2', {})).rejects.toThrow(
        /Pague antes a parcela 1\/5, que vence em 20\/12\/2026/,
      );
    });

    it('conta avulsa não passa pela regra (nem consulta grupo)', async () => {
      const { service, repo } = montarGrupo([]);
      repo.findById.mockResolvedValueOnce({
        id: 'e1',
        description: 'Aluguel',
        amount: 2500,
        status: 'active',
        paid_at: null,
        cash_entry_id: null,
        installment_no: null,
        installment_total: null,
        installment_group_id: null,
      } as never);
      await service.pay(user, 'e1', {});
      expect(repo.listInstallmentGroup).not.toHaveBeenCalled();
    });
  });

  it('marca a ORIGEM no lançamento (é o que faz o caminho de volta existir)', async () => {
    // Antes ia nulo e o vínculo era de um sentido só: o extrato mostrava
    // "Aluguel" sem como chegar na conta a pagar. `originId` é o id DESTA
    // despesa, que o caixa guarda como tag opaca em (sale_kind, sale_id).
    const { service, cashier } = montar();
    await service.pay(user, 'e1', {});
    expect(cashier.registrarSaidaDeDespesa).toHaveBeenCalledWith(
      user,
      expect.objectContaining({ originId: 'e1' }),
    );
  });
});
