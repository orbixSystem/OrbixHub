import { ConflictException, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { CashierServiceImpl } from './cashier.service.impl';
import type { AuthUser } from '../../common/auth/auth.types';

/**
 * Despesas fixas (modelos de lançamento).
 *
 * O que estes testes protegem: o modelo é **preset, não dinheiro**. Ele pode ter
 * o valor editado à vontade (diferente de um lançamento, que exige correção com
 * estorno) e nunca é apagado de verdade — desativar preserva o histórico de quem
 * lançou o quê. E `amount: 0` é legítimo: significa "o valor varia".
 */

const user: AuthUser = {
  userId: 'u1',
  tenantId: 't1',
  role: 'owner',
  jti: 'j1',
} as AuthUser;

type Row = Record<string, unknown>;

/** Erro de unique do Postgres, como o Prisma o entrega. */
const uniqueViolation = (target?: string[]) =>
  new Prisma.PrismaClientKnownRequestError('duplicate key', {
    code: 'P2002',
    clientVersion: 'test',
    meta: target ? { target } : {},
  });

function makeService(iniciais: Row[] = []) {
  const rows = new Map<string, Row>();
  for (const r of iniciais) rows.set(r.id as string, r);
  let seq = 0;

  const ativos = () =>
    [...rows.values()].filter((r) => r.status === 'active');

  const repo = {
    listTemplates: (p: { includeDisabled?: boolean } = {}) =>
      Promise.resolve(
        (p.includeDisabled ? [...rows.values()] : ativos()).sort((a, b) =>
          String(a.name).localeCompare(String(b.name)),
        ),
      ),
    findTemplate: (id: string) => Promise.resolve(rows.get(id) ?? null),
    createTemplate: (tenantId: string, data: Row) => {
      // Espelha o unique parcial (tenant, lower(name)) WHERE status='active'.
      const nome = String(data.name).trim().toLowerCase();
      if (ativos().some((r) => String(r.name).trim().toLowerCase() === nome)) {
        return Promise.reject(uniqueViolation(['tenant_id', 'name']));
      }
      if (data.id && rows.has(data.id as string)) {
        return Promise.reject(uniqueViolation(['id']));
      }
      const novo: Row = {
        id: (data.id as string) ?? `tpl-${++seq}`,
        tenant_id: tenantId,
        status: 'active',
        ...data,
      };
      rows.set(novo.id as string, novo);
      return Promise.resolve(novo);
    },
    updateTemplate: (id: string, data: Row) => {
      const atual = rows.get(id) as Row;
      if (data.name) {
        const nome = String(data.name).trim().toLowerCase();
        const colide = ativos().some(
          (r) => r.id !== id && String(r.name).trim().toLowerCase() === nome,
        );
        if (colide) return Promise.reject(uniqueViolation(['tenant_id', 'name']));
      }
      const novo = { ...atual, ...data };
      rows.set(id, novo);
      return Promise.resolve(novo);
    },
  };
  const tenant = { withTenantTx: <T>(fn: () => Promise<T>) => fn() };
  const billing = { getModuleSettings: () => Promise.resolve({}) };
  const auditadas: string[] = [];
  const audit = {
    log: (_t: string, _u: string, action: string) => {
      auditadas.push(action);
      return Promise.resolve(undefined);
    },
  };

  const service = new CashierServiceImpl(
    tenant as never,
    repo as never,
    billing as never,
    audit as never,
  );
  return { service, rows, auditadas };
}

describe('caixa — despesas fixas (modelos de lançamento)', () => {
  it('cria com valor e forma sugerida, e audita', async () => {
    const { service, auditadas } = makeService();
    const tpl = await service.createExpenseTemplate(user, {
      name: 'Aluguel',
      amount: 1200,
      method: 'pix',
    });
    expect(tpl.name).toBe('Aluguel');
    expect(tpl.amount).toBe(1200);
    expect(tpl.method).toBe('pix');
    expect(tpl.category).toBe('despesa');
    expect(auditadas).toEqual(['cashier_template_create']);
  });

  it('valor 0 é aceito: significa "o valor varia" (conta de luz)', async () => {
    const { service } = makeService();
    const tpl = await service.createExpenseTemplate(user, { name: 'Luz' });
    expect(tpl.amount).toBe(0);
    // Sem forma sugerida ⇒ null (o caixa usa o default dele, não um palpite).
    expect(tpl.method).toBeNull();
  });

  it('apara espaços do nome antes de gravar', async () => {
    const { service } = makeService();
    const tpl = await service.createExpenseTemplate(user, {
      name: '  Contador  ',
      amount: 400,
    });
    expect(tpl.name).toBe('Contador');
  });

  it('nome repetido entre os ATIVOS é 409 com o nome na mensagem', async () => {
    const { service } = makeService();
    await service.createExpenseTemplate(user, { name: 'Aluguel', amount: 1200 });
    await expect(
      service.createExpenseTemplate(user, { name: 'aluguel', amount: 900 }),
    ).rejects.toThrow(ConflictException);
    await expect(
      service.createExpenseTemplate(user, { name: 'ALUGUEL' }),
    ).rejects.toThrow(/Já existe uma despesa fixa "ALUGUEL"/);
  });

  it('id duplicado (replay offline) dá a mensagem de id, não a de nome', async () => {
    const { service } = makeService();
    const id = '11111111-1111-1111-1111-111111111111';
    await service.createExpenseTemplate(user, { id, name: 'Internet' });
    // Mesmo id, nome DIFERENTE: o conflito é de id — trocar as mensagens
    // mandaria o operador renomear algo que não é o problema.
    await expect(
      service.createExpenseTemplate(user, { id, name: 'Internet fibra' }),
    ).rejects.toThrow(/id duplicado/);
  });

  it('desativado libera o nome para ser recriado', async () => {
    const { service } = makeService();
    const tpl = await service.createExpenseTemplate(user, { name: 'Aluguel' });
    await service.disableExpenseTemplate(user, tpl.id);
    // O unique é parcial (só ativos) — recriar tem de funcionar.
    const novo = await service.createExpenseTemplate(user, {
      name: 'Aluguel',
      amount: 1500,
    });
    expect(novo.id).not.toBe(tpl.id);
    expect(novo.amount).toBe(1500);
  });

  it('editar o VALOR é permitido (modelo não é dinheiro no livro caixa)', async () => {
    const { service, auditadas } = makeService();
    const tpl = await service.createExpenseTemplate(user, {
      name: 'Aluguel',
      amount: 1200,
    });
    const editado = await service.updateExpenseTemplate(user, tpl.id, {
      amount: 1350,
    });
    expect(editado.amount).toBe(1350);
    expect(auditadas).toEqual([
      'cashier_template_create',
      'cashier_template_update',
    ]);
  });

  it('desativar não apaga: a linha continua, com status disabled', async () => {
    const { service, rows } = makeService();
    const tpl = await service.createExpenseTemplate(user, { name: 'Internet' });
    await service.disableExpenseTemplate(user, tpl.id);
    expect(rows.get(tpl.id)).toBeDefined();
    expect(rows.get(tpl.id)?.status).toBe('disabled');
  });

  it('a listagem padrão esconde os desativados; includeDisabled mostra', async () => {
    const { service } = makeService();
    await service.createExpenseTemplate(user, { name: 'Aluguel' });
    const luz = await service.createExpenseTemplate(user, { name: 'Luz' });
    await service.disableExpenseTemplate(user, luz.id);

    const ativos = await service.listExpenseTemplates();
    expect(ativos.map((t) => t.name)).toEqual(['Aluguel']);

    const todos = await service.listExpenseTemplates(true);
    expect(todos.map((t) => t.name)).toEqual(['Aluguel', 'Luz']);
  });

  it('editar modelo inexistente é 404 (não cria pelas costas)', async () => {
    const { service } = makeService();
    await expect(
      service.updateExpenseTemplate(user, 'nao-existe', { amount: 10 }),
    ).rejects.toThrow(NotFoundException);
  });

  it('renomear para um nome já usado por outro ativo é 409', async () => {
    const { service } = makeService();
    await service.createExpenseTemplate(user, { name: 'Aluguel' });
    const luz = await service.createExpenseTemplate(user, { name: 'Luz' });
    await expect(
      service.updateExpenseTemplate(user, luz.id, { name: 'Aluguel' }),
    ).rejects.toThrow(ConflictException);
  });

  it('limpar a forma sugerida (null explícito) é diferente de não mexer', async () => {
    const { service } = makeService();
    const tpl = await service.createExpenseTemplate(user, {
      name: 'Aluguel',
      method: 'pix',
    });
    // Sem o campo: preserva.
    const a = await service.updateExpenseTemplate(user, tpl.id, { amount: 1 });
    expect(a.method).toBe('pix');
    // Com null: limpa.
    const b = await service.updateExpenseTemplate(user, tpl.id, {
      method: null as never,
    });
    expect(b.method).toBeNull();
  });

  it('reativar um modelo desativado volta a listá-lo', async () => {
    const { service } = makeService();
    const tpl = await service.createExpenseTemplate(user, { name: 'Contador' });
    await service.disableExpenseTemplate(user, tpl.id);
    await service.updateExpenseTemplate(user, tpl.id, { status: 'active' });
    const ativos = await service.listExpenseTemplates();
    expect(ativos.map((t) => t.name)).toEqual(['Contador']);
  });
});
