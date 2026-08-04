import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import type { AuthUser } from '../../common/auth/auth.types';
import { AuditService } from '../../common/audit/audit.service';
import { TenantContext } from '../../common/database/tenant-context';
import { CashierService } from '../cashier/cashier.service';
import {
  ChangedSincePage,
  clampChangedSinceLimit,
} from '../../common/database/changed-since';
import {
  ExpensesRepository,
  ExpensesSyncEntity,
  NewExpenseData,
} from './expenses.repository';
import {
  CreateExpenseDto,
  PayExpenseDto,
  UpdateExpenseDto,
} from './dto/expense.dto';
import {
  CreateExpenseCategoryDto,
  UpdateExpenseCategoryDto,
} from './dto/category.dto';
import { ExpensesMonthQueryDto } from './dto/query.dto';
import {
  Frequency,
  MESES_DE_ESTEIRA,
  PaymentMethod,
  limitesDoMes,
  primeiraOcorrencia,
  proximasOcorrencias,
  round2,
} from './expenses.config';

/** Categorias que todo tenant ganha no primeiro acesso ao módulo. */
const CATEGORIAS_PADRAO = [
  { name: 'Aluguel', icon: 'aluguel', color: '#F97316' },
  { name: 'Energia', icon: 'energia', color: '#EAB308' },
  { name: 'Água', icon: 'agua', color: '#38BDF8' },
  { name: 'Internet', icon: 'internet', color: '#8B5CF6' },
  { name: 'Telefone', icon: 'telefone', color: '#06B6D4' },
  { name: 'Impostos', icon: 'impostos', color: '#EF4444' },
  { name: 'Fornecedor', icon: 'fornecedor', color: '#10B981' },
  { name: 'Salários', icon: 'salarios', color: '#3B82F6' },
  { name: 'Manutenção', icon: 'manutencao', color: '#A16207' },
  { name: 'Outros', icon: 'outros', color: '#6B7280' },
];

const toNum = (d: Prisma.Decimal | number | null | undefined): number =>
  d == null ? 0 : typeof d === 'number' ? d : d.toNumber();

/** Data civil a partir de `YYYY-MM-DD`, ancorada em UTC (vencimento é dia). */
function parseDia(iso: string): Date {
  const [a, m, d] = iso.slice(0, 10).split('-').map(Number);
  return new Date(Date.UTC(a, m - 1, d));
}

function isUniqueViolation(e: unknown): boolean {
  return (
    e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002'
  );
}

/**
 * Módulo Despesas (contas a pagar / lembrete de pagamento).
 *
 * Dono das tabelas `expense*`. Fala com o Caixa SÓ pela porta pública
 * (`CashierService.registrarSaidaDeDespesa` / `estornarSaidaDeDespesa`) e guarda
 * apenas o `cash_entry_id` — nunca lê nem escreve `cash_entry` (regra 1).
 */
@Injectable()
export class ExpensesService {
  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: ExpensesRepository,
    private readonly audit: AuditService,
    private readonly cashier: CashierService,
  ) {}

  // ===================== Leitura =====================
  async listMonth(user: AuthUser, query: ExpensesMonthQueryDto) {
    const hoje = new Date();
    const ano = query.ano ?? hoje.getUTCFullYear();
    const mes = query.mes ?? hoje.getUTCMonth() + 1;
    const { de, ate } = limitesDoMes(ano, mes);

    const { itens, categorias } = await this.tenant.withTenantTx(async () => {
      await this.garantirCategorias(user.tenantId);
      return {
        itens: await this.repo.listByMonth({ de, ate }),
        categorias: await this.repo.listCategories(),
      };
    });

    // Totais no servidor: ele enxerga o mês inteiro, e "quanto ainda devo" não
    // pode depender do que coube na tela.
    const hojeDia = new Date(
      Date.UTC(hoje.getUTCFullYear(), hoje.getUTCMonth(), hoje.getUTCDate()),
    );
    let totalPrevisto = 0;
    let totalPago = 0;
    let totalEmAberto = 0;
    let totalVencido = 0;
    for (const e of itens) {
      const valor = toNum(e.amount);
      totalPrevisto += valor;
      if (e.paid_at) {
        totalPago += toNum(e.paid_amount ?? e.amount);
      } else {
        totalEmAberto += valor;
        if (e.due_date < hojeDia) totalVencido += valor;
      }
    }

    const situacao = query.situacao ?? 'todas';
    const visiveis = itens.filter((e) => {
      switch (situacao) {
        case 'aberto':
          return !e.paid_at;
        case 'pago':
          return !!e.paid_at;
        case 'vencido':
          return !e.paid_at && e.due_date < hojeDia;
        default:
          return true;
      }
    });

    return {
      items: visiveis,
      categories: categorias,
      totalPrevisto: round2(totalPrevisto),
      totalPago: round2(totalPago),
      totalEmAberto: round2(totalEmAberto),
      totalVencido: round2(totalVencido),
    };
  }

  /**
   * Semeia as categorias padrão na primeira vez que o tenant abre o módulo.
   *
   * Aqui e não no registro do tenant: o `auth` não deve conhecer `expenses`
   * (regra 1). `skipDuplicates` no repo torna a chamada repetida inofensiva, e o
   * `count` evita o INSERT quando já há categorias — inclusive quando a cliente
   * apagou todas as padrão de propósito e criou as suas.
   */
  private async garantirCategorias(tenantId: string): Promise<void> {
    const existentes = await this.repo.countCategories();
    if (existentes > 0) return;
    await this.repo.seedCategories(tenantId, CATEGORIAS_PADRAO);
  }

  // ===================== Escrita =====================
  async create(user: AuthUser, dto: CreateExpenseDto) {
    const vencimento = parseDia(dto.dueDate);
    const valor = round2(dto.amount ?? 0);

    const criada = await this.tenant.withTenantTx(async () => {
      await this.validarCategoria(dto.categoryId);

      let recurrenceId: string | null = null;
      if (dto.recorrencia) {
        const freq = (dto.recorrencia.frequency ?? 'monthly') as Frequency;
        if (freq === 'yearly' && !dto.recorrencia.monthOfYear) {
          // O CHECK do banco já barra, mas a mensagem dele não ajuda ninguém.
          throw new BadRequestException(
            'Despesa anual precisa do mês de vencimento.',
          );
        }
        const regra = await this.repo.createRecurrence(user.tenantId, {
          description: dto.description.trim(),
          amount: valor,
          category_id: dto.categoryId ?? null,
          frequency: freq,
          // Dia PEDIDO = o dia do vencimento informado. Mês curto encurta na
          // geração, não aqui.
          day_of_month:
            dto.recorrencia.dayOfMonth ?? vencimento.getUTCDate(),
          month_of_year:
            dto.recorrencia.monthOfYear ?? (freq === 'yearly'
              ? vencimento.getUTCMonth() + 1
              : null),
          method: null,
          notes: dto.notes?.trim() || null,
          starts_on: vencimento,
          ends_on: dto.recorrencia.endsOn
            ? parseDia(dto.recorrencia.endsOn)
            : null,
          created_by: user.userId,
        });
        recurrenceId = regra.id;
      }

      let conta;
      try {
        conta = await this.repo.create(user.tenantId, {
          id: dto.id,
          description: dto.description.trim(),
          amount: valor,
          due_date: vencimento,
          category_id: dto.categoryId ?? null,
          recurrence_id: recurrenceId,
          // A conta que a cliente acabou de cadastrar É a primeira ocorrência.
          occurrence_on: recurrenceId ? primeiraOcorrencia(vencimento) : null,
          notes: dto.notes?.trim() || null,
          created_by: user.userId,
        });
      } catch (e) {
        if (dto.id && isUniqueViolation(e)) {
          throw new ConflictException('Registro já existe (id duplicado).');
        }
        throw e;
      }

      // Esteira: as PRÓXIMAS ocorrências, no mesmo tx da criação, para a cliente
      // já navegar para o mês que vem e encontrar a conta lá.
      if (recurrenceId) {
        await this.materializar(user.tenantId, recurrenceId);
      }
      return conta;
    });

    await this.audit.log(
      user.tenantId,
      user.userId,
      'expense_create',
      criada.id,
      {
        amount: toNum(criada.amount),
        dueDate: dto.dueDate,
        recorrente: !!dto.recorrencia,
      },
    );
    return criada;
  }

  async update(user: AuthUser, id: string, dto: UpdateExpenseDto) {
    const atualizada = await this.tenant.withTenantTx(async () => {
      const atual = await this.repo.findById(id);
      if (!atual) throw new NotFoundException('Despesa não encontrada.');
      if (atual.paid_at) {
        // Editar valor/vencimento de conta paga desalinharia o lançamento que já
        // está no caixa. Desfaça a baixa, corrija e pague de novo.
        throw new ConflictException(
          'Despesa já paga. Desfaça o pagamento para editá-la.',
        );
      }
      await this.validarCategoria(dto.categoryId);
      return this.repo.update(id, {
        description: dto.description?.trim(),
        amount: dto.amount === undefined ? undefined : round2(dto.amount),
        due_date: dto.dueDate ? parseDia(dto.dueDate) : undefined,
        category_id: dto.limparCategoria ? null : dto.categoryId,
        notes: dto.notes === undefined ? undefined : dto.notes.trim() || null,
      });
    });
    await this.audit.log(user.tenantId, user.userId, 'expense_update', id, {
      campos: Object.keys(dto),
    });
    return atualizada;
  }

  /**
   * Dá baixa e ESPELHA no Caixa — o que a cliente descreve como "dou baixa e cai
   * no caixa".
   *
   * Ordem deliberada: o lançamento no caixa vem PRIMEIRO, a baixa depois. Se o
   * segundo passo falhar, sobra um lançamento sem conta correspondente — visível
   * no extrato e corrigível por estorno. Na ordem inversa, uma falha deixaria a
   * conta paga sem registro no caixa: um buraco silencioso no livro, que só
   * apareceria na conferência de fechamento sem explicação.
   *
   * Fora de transação de propósito: o caixa abre a sua própria (`withTenantTx`),
   * e aninhar transações de dois donos diferentes acopla o rollback de um ao
   * outro.
   */
  async pay(user: AuthUser, id: string, dto: PayExpenseDto) {
    const atual = await this.tenant.withTenantTx(() => this.repo.findById(id));
    if (!atual) throw new NotFoundException('Despesa não encontrada.');
    if (atual.status !== 'active') {
      throw new ConflictException('Despesa cancelada.');
    }
    if (atual.paid_at) throw new ConflictException('Despesa já paga.');

    const valor = round2(dto.amount ?? toNum(atual.amount));
    if (valor <= 0) {
      // Conta "a confirmar" (valor 0) precisa do valor na hora de pagar: sem ele
      // o caixa registraria uma saída de zero.
      throw new BadRequestException(
        'Informe o valor pago — esta despesa está sem valor definido.',
      );
    }
    const forma = (dto.method ?? 'dinheiro') as PaymentMethod;

    const lancamento = await this.cashier.registrarSaidaDeDespesa(user, {
      amount: valor,
      method: forma,
      description: atual.description,
      deviceId: dto.deviceId ?? null,
      entryId: dto.cashEntryId,
    });

    const paga = await this.tenant.withTenantTx(() =>
      this.repo.setPayment(id, {
        paid_at: dto.paidAt ? new Date(dto.paidAt) : new Date(),
        paid_amount: valor,
        paid_method: forma,
        cash_entry_id: lancamento.id,
      }),
    );

    await this.audit.log(user.tenantId, user.userId, 'expense_pay', id, {
      amount: valor,
      method: forma,
      cashEntryId: lancamento.id,
    });
    return paga;
  }

  /**
   * Desfaz a baixa e ESTORNA o lançamento no caixa.
   *
   * O estorno vem primeiro pelo mesmo raciocínio do `pay`: é preferível um
   * lançamento estornado com a conta ainda paga (inconsistência visível, e
   * repetir a operação conserta) a uma conta em aberto com dinheiro ainda
   * contado como saído.
   */
  async unpay(user: AuthUser, id: string) {
    const atual = await this.tenant.withTenantTx(() => this.repo.findById(id));
    if (!atual) throw new NotFoundException('Despesa não encontrada.');
    if (!atual.paid_at) throw new ConflictException('Despesa não está paga.');

    if (atual.cash_entry_id) {
      await this.cashier.estornarSaidaDeDespesa(user, atual.cash_entry_id);
    }

    const emAberto = await this.tenant.withTenantTx(() =>
      this.repo.setPayment(id, {
        paid_at: null,
        paid_amount: null,
        paid_method: null,
        cash_entry_id: null,
      }),
    );
    await this.audit.log(user.tenantId, user.userId, 'expense_unpay', id, {
      cashEntryId: atual.cash_entry_id,
    });
    return emAberto;
  }

  /** Cancela a conta. Sem hard delete (regra 6) — preserva o histórico. */
  async cancel(user: AuthUser, id: string) {
    await this.tenant.withTenantTx(async () => {
      const atual = await this.repo.findById(id);
      if (!atual) throw new NotFoundException('Despesa não encontrada.');
      if (atual.paid_at) {
        throw new ConflictException(
          'Despesa já paga. Desfaça o pagamento antes de cancelar.',
        );
      }
      await this.repo.update(id, { status: 'canceled' });
    });
    await this.audit.log(user.tenantId, user.userId, 'expense_cancel', id);
  }

  // ===================== Esteira de recorrência =====================
  /**
   * Materializa as próximas ocorrências de uma regra.
   *
   * Linhas reais (e não ocorrências virtuais calculadas na leitura) porque o app
   * é offline-first: o motor de sync sabe sincronizar LINHA. Ocorrência virtual
   * viraria um caso especial no sync, e não daria para corrigir o valor de um
   * mês só.
   *
   * Idempotente: o unique parcial `(tenant_id, recurrence_id, occurrence_on)` +
   * `skipDuplicates` fazem uma segunda execução não duplicar nada.
   */
  private async materializar(tenantId: string, recurrenceId: string) {
    const regra = await this.repo.findRecurrence(recurrenceId);
    if (!regra || regra.status !== 'active') return;

    const datas = proximasOcorrencias({
      frequency: regra.frequency as Frequency,
      dayOfMonth: regra.day_of_month,
      monthOfYear: regra.month_of_year,
      startsOn: regra.starts_on,
      endsOn: regra.ends_on,
      desde: regra.generated_through ?? regra.starts_on,
      quantidade: MESES_DE_ESTEIRA,
    });
    if (datas.length === 0) return;

    const linhas: NewExpenseData[] = datas.map((data) => ({
      description: regra.description,
      amount: regra.amount,
      due_date: data,
      category_id: regra.category_id,
      recurrence_id: regra.id,
      occurrence_on: data,
      notes: regra.notes,
      // Autoria da REGRA, não de quem disparou a geração: o job roda sem usuário
      // logado, e atribuir as ocorrências a quem montou a recorrência é o que
      // faz sentido no histórico.
      created_by: regra.created_by,
    }));
    await this.repo.createMany(tenantId, linhas);
    await this.repo.updateRecurrence(regra.id, {
      generated_through: datas[datas.length - 1],
    });
  }

  /**
   * Estende UMA regra — porta usada pelo job diário, que já entrou no tenant via
   * `runWithTenant`. Mantém a janela de 12 meses andando sozinha com o tempo.
   */
  async estenderRegra(tenantId: string, recurrenceId: string): Promise<void> {
    await this.tenant.withTenantTx(() =>
      this.materializar(tenantId, recurrenceId),
    );
  }

  /** Horizonte que a esteira persegue: hoje + (janela − 1) meses. */
  static horizonteDaEsteira(hoje = new Date()): Date {
    const limite = new Date(hoje);
    limite.setUTCMonth(limite.getUTCMonth() + MESES_DE_ESTEIRA - 1);
    return limite;
  }

  // ===================== Categorias =====================
  async listCategories(user: AuthUser, includeDisabled = false) {
    return this.tenant.withTenantTx(async () => {
      await this.garantirCategorias(user.tenantId);
      return this.repo.listCategories({ includeDisabled });
    });
  }

  async createCategory(user: AuthUser, dto: CreateExpenseCategoryDto) {
    const criada = await this.tenant.withTenantTx(async () => {
      try {
        return await this.repo.createCategory(user.tenantId, {
          id: dto.id,
          name: dto.name.trim(),
          icon: dto.icon ?? 'outros',
          color: dto.color ?? '#6B7280',
        });
      } catch (e) {
        if (isUniqueViolation(e)) {
          throw new ConflictException(
            `Já existe uma categoria "${dto.name.trim()}".`,
          );
        }
        throw e;
      }
    });
    await this.audit.log(
      user.tenantId,
      user.userId,
      'expense_category_create',
      criada.id,
      { name: criada.name },
    );
    return criada;
  }

  async updateCategory(
    user: AuthUser,
    id: string,
    dto: UpdateExpenseCategoryDto,
  ) {
    const atualizada = await this.tenant.withTenantTx(async () => {
      const atual = await this.repo.findCategory(id);
      if (!atual) throw new NotFoundException('Categoria não encontrada.');
      try {
        return await this.repo.updateCategory(id, {
          name: dto.name?.trim(),
          icon: dto.icon,
          color: dto.color,
          status: dto.status,
        });
      } catch (e) {
        if (isUniqueViolation(e)) {
          throw new ConflictException('Já existe uma categoria com esse nome.');
        }
        throw e;
      }
    });
    await this.audit.log(
      user.tenantId,
      user.userId,
      'expense_category_update',
      id,
      { campos: Object.keys(dto) },
    );
    return atualizada;
  }

  // ===================== Sync pull (offline) =====================
  /**
   * Página de mudanças para o pull do `sync`. A whitelist local impede que a
   * entidade vinda da query vire nome de tabela arbitrário — o `sync` valida no
   * `PULL_ROUTES`, e aqui reforçamos (defesa em profundidade, como no caixa).
   */
  listChangedSince(
    entity: string,
    cursor: { ts: string; id: string } | null,
    limit: number,
  ): Promise<ChangedSincePage> {
    const permitidas: ExpensesSyncEntity[] = [
      'expense',
      'expense_category',
      'expense_recurrence',
    ];
    if (!permitidas.includes(entity as ExpensesSyncEntity)) {
      throw new BadRequestException(`Entidade desconhecida: ${entity}`);
    }
    return this.tenant.withTenantTx(() =>
      this.repo.listChangedSince(
        entity as ExpensesSyncEntity,
        cursor,
        clampChangedSinceLimit(limit),
      ),
    );
  }

  /** Garante que a categoria informada existe e pertence ao tenant (via RLS). */
  private async validarCategoria(id?: string): Promise<void> {
    if (!id) return;
    const cat = await this.repo.findCategory(id);
    if (!cat) throw new BadRequestException('Categoria inválida.');
  }
}
