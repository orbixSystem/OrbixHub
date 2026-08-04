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

  const service = new ExpensesService(
    tenant as never,
    repo as never,
    audit as never,
    cashier as never,
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
});
