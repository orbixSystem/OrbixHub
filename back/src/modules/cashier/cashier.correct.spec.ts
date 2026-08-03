import { BadRequestException, ConflictException } from '@nestjs/common';
import { CashierServiceImpl } from './cashier.service.impl';
import type { AuthUser } from '../../common/auth/auth.types';

/**
 * Editar × corrigir um lançamento do caixa.
 *
 * A regra que estes testes protegem: **o livro caixa não sobrescreve dinheiro**.
 * Descrição e categoria de mesma direção são edição (o lançamento continua
 * valendo o mesmo); valor e forma são CORREÇÃO — estorna o original e relança,
 * preservando a trilha. Trocar despesa (saída) por suprimento (entrada) mudaria
 * o saldo sem registro nenhum: isso é bloqueado.
 */

const user: AuthUser = {
  userId: 'u1',
  tenantId: 't1',
  role: 'owner',
  jti: 'j1',
} as AuthUser;

/** Lançamento no espelho do "banco" fake. */
type Row = Record<string, unknown>;

/** "O único lançamento criado" — falha alto se houver mais de um. */
const unico = (rows: Row[]): Row => {
  if (rows.length !== 1) {
    throw new Error(`esperava exatamente 1 lançamento, veio ${rows.length}`);
  }
  return rows[0];
};

function makeService(entrada: Row | null) {
  const rows = new Map<string, Row>();
  if (entrada) rows.set(entrada.id as string, entrada);
  const criados: Row[] = [];

  const repo = {
    findEntryById: (id: string) => Promise.resolve(rows.get(id) ?? null),
    updateEntry: (id: string, data: Row) => {
      const atual = { ...(rows.get(id) as Row), ...data };
      rows.set(id, atual);
      return Promise.resolve(atual);
    },
    markReversed: (id: string, data: Row) => {
      const atual = { ...(rows.get(id) as Row), ...data, reversed_at: new Date() };
      rows.set(id, atual);
      return Promise.resolve(atual);
    },
    findOpenSession: () => Promise.resolve({ id: 'sess-hoje' }),
    createSession: () => Promise.resolve({ id: 'sess-hoje' }),
    createEntry: (_t: string, data: Row) => {
      const novo = { id: (data.id as string) ?? 'novo-1', ...data };
      criados.push(novo);
      rows.set(novo.id as string, novo);
      return Promise.resolve(novo);
    },
  };
  const tenant = {
    // O fake não tem transação: executa direto.
    withTenantTx: <T>(fn: () => Promise<T>) => fn(),
  };
  // Settings vazio ⇒ config default (requireOpenSession=false), que é o que o
  // fluxo de correção usa ao relançar.
  const billing = { getModuleSettings: () => Promise.resolve({}) };
  const audit = { log: () => Promise.resolve(undefined) };

  const service = new CashierServiceImpl(
    tenant as never,
    repo as never,
    billing as never,
    audit as never,
  );
  // `hasPermission` consulta cargo→permissões no banco; aqui o ator é owner.
  (service as unknown as { hasPermission: () => Promise<boolean> }).hasPermission =
      () => Promise.resolve(true);
  return { service, rows, criados };
}

const despesa: Row = {
  id: 'e1',
  direction: 'out',
  amount: 50,
  method: 'pix',
  category: 'despesa',
  description: 'Óleo do fornecedor',
  sale_kind: null,
  sale_id: null,
  reversed_at: null,
};

describe('updateEntry — edita o que o lançamento DIZ', () => {
  it('altera a descrição sem tocar no valor', async () => {
    const { service, rows } = makeService({ ...despesa });
    await service.updateEntry(user, 'e1', { description: 'Óleo 5W30 — nota 123' });
    expect(rows.get('e1')!.description).toBe('Óleo 5W30 — nota 123');
    expect(rows.get('e1')!.amount).toBe(50);
  });

  it('aceita trocar despesa por sangria (ambas SAÍDA)', async () => {
    const { service, rows } = makeService({ ...despesa });
    await service.updateEntry(user, 'e1', { category: 'sangria' });
    expect(rows.get('e1')!.category).toBe('sangria');
  });

  it('RECUSA troca que inverte entrada/saída (despesa → suprimento)', async () => {
    // Isto mudaria o saldo do caixa sem nenhum registro do que havia antes.
    const { service } = makeService({ ...despesa });
    await expect(
      service.updateEntry(user, 'e1', { category: 'suprimento' }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('descrição vazia limpa o campo (não grava string vazia)', async () => {
    const { service, rows } = makeService({ ...despesa });
    await service.updateEntry(user, 'e1', { description: '   ' });
    expect(rows.get('e1')!.description).toBeNull();
  });

  it('RECUSA editar lançamento estornado (é histórico fechado)', async () => {
    const { service } = makeService({ ...despesa, reversed_at: new Date() });
    await expect(
      service.updateEntry(user, 'e1', { description: 'x' }),
    ).rejects.toBeInstanceOf(ConflictException);
  });
});

describe('correctEntry — estorna e relança', () => {
  it('estorna o original com o motivo e cria o novo com o valor certo', async () => {
    const { service, rows, criados } = makeService({ ...despesa });
    const novo = await service.correctEntry(user, 'e1', {
      reason: 'valor digitado errado',
      amount: 45,
    });

    // O original NÃO é sobrescrito: fica estornado, com o motivo.
    expect(rows.get('e1')!.reversed_at).toBeInstanceOf(Date);
    expect(rows.get('e1')!.reversal_reason).toBe('valor digitado errado');
    expect(rows.get('e1')!.amount).toBe(50);

    // E nasce um lançamento com o valor corrigido.
    expect(criados).toHaveLength(1);
    expect(novo.amount).toBe(45);
  });

  it('herda forma, categoria, descrição e vínculo do original', async () => {
    const { service, criados } = makeService({
      ...despesa,
      category: 'os_payment',
      direction: 'in',
      sale_kind: 'os',
      sale_id: 'os-1',
    });
    await service.correctEntry(user, 'e1', {
      reason: 'recebi a mais',
      amount: 30,
    });

    const novo = unico(criados);
    expect(novo.method).toBe('pix');
    expect(novo.category).toBe('os_payment');
    expect(novo.description).toBe('Óleo do fornecedor');
    // O vínculo com a OS tem de sobreviver, senão o pagamento dela some.
    expect(novo.sale_kind).toBe('os');
    expect(novo.sale_id).toBe('os-1');
  });

  it('preserva o uuid gerado offline para o lançamento novo', async () => {
    const { service } = makeService({ ...despesa });
    const novo = await service.correctEntry(user, 'e1', {
      reason: 'corrigindo',
      amount: 10,
      newId: 'uuid-do-cliente',
    });
    expect(novo.id).toBe('uuid-do-cliente');
  });

  it('RECUSA corrigir o que já foi estornado (evita estorno duplo)', async () => {
    const { service } = makeService({ ...despesa, reversed_at: new Date() });
    await expect(
      service.correctEntry(user, 'e1', { reason: 'tarde demais' }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('sem valor novo, corrige só o texto mantendo o valor', async () => {
    const { service, criados } = makeService({ ...despesa });
    await service.correctEntry(user, 'e1', {
      reason: 'descrição errada',
      description: 'Filtro, não óleo',
    });
    expect(unico(criados).amount).toBe(50);
    expect(unico(criados).description).toBe('Filtro, não óleo');
  });
});

