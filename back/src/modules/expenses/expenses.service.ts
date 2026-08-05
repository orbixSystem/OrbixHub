import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { Prisma } from '@prisma/client';
import type { AuthUser } from '../../common/auth/auth.types';
import { AuditService } from '../../common/audit/audit.service';
import { TenantContext } from '../../common/database/tenant-context';
import { CashierService } from '../cashier/cashier.service';
import { CnpjGateway } from '../../common/cnpj/cnpj.gateway';
import { formatCnpj, isValidCnpj, normalizeCnpj } from '../auth/cnpj';
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
  datasDasParcelas,
  limitesDoMes,
  primeiraOcorrencia,
  proximasOcorrencias,
  ratearParcelas,
  round2,
} from './expenses.config';

/**
 * Categorias que todo tenant ganha no primeiro acesso ao módulo.
 *
 * `tracks_supplier` marca as que TÊM fornecedor do outro lado (peças, manutenção).
 * Aluguel, imposto e salário não têm — e é isso que tira o campo "fornecedor" do
 * caminho de quem está lançando a conta de luz.
 */
const CATEGORIAS_PADRAO = [
  { name: 'Aluguel', icon: 'aluguel', color: '#F97316', tracks_supplier: false },
  { name: 'Energia', icon: 'energia', color: '#EAB308', tracks_supplier: false },
  { name: 'Água', icon: 'agua', color: '#38BDF8', tracks_supplier: false },
  { name: 'Internet', icon: 'internet', color: '#8B5CF6', tracks_supplier: false },
  { name: 'Telefone', icon: 'telefone', color: '#06B6D4', tracks_supplier: false },
  { name: 'Impostos', icon: 'impostos', color: '#EF4444', tracks_supplier: false },
  { name: 'Fornecedor', icon: 'fornecedor', color: '#10B981', tracks_supplier: true },
  // Compra de mercadoria (peça, óleo, material de consumo) — semanal em oficina.
  // Separada de "Fornecedor", que é sobre QUEM cobra, não sobre o que foi comprado.
  { name: 'Produto', icon: 'produto', color: '#0EA5E9', tracks_supplier: true },
  { name: 'Salários', icon: 'salarios', color: '#3B82F6', tracks_supplier: false },
  { name: 'Manutenção', icon: 'manutencao', color: '#A16207', tracks_supplier: true },
  { name: 'Outros', icon: 'outros', color: '#6B7280', tracks_supplier: false },
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
    private readonly cnpj: CnpjGateway,
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
      Date.UTC(hoje.getFullYear(), hoje.getMonth(), hoje.getDate()),
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

    // As REGRAS citadas pelas contas do mês. Sem elas a tela não tem como dizer
    // "próxima em 10/09" ao dar baixa numa conta fixa: a próxima ocorrência é uma
    // linha de OUTRO mês, que não veio nesta listagem.
    const regrasCitadas = [
      ...new Set(visiveis.map((e) => e.recurrence_id).filter((v): v is string => !!v)),
    ];
    const recurrences = await this.tenant.withTenantTx(() =>
      this.repo.listRecurrencesByIds(regrasCitadas),
    );

    // Resumo dos GRUPOS de parcelamento citados no mês.
    //
    // O card mostra o valor da PARCELA (é o que se deve neste mês), mas quem olha
    // quer saber de quanto é a compra inteira — e isso não é derivável do mês: só
    // vêm as parcelas que vencem nele. Sem este resumo o card não pode dizer
    // "2/6 de R$ 900,00" sem inventar o total.
    const gruposCitados = [
      ...new Set(
        visiveis
          .map((e) => e.installment_group_id)
          .filter((v): v is string => !!v),
      ),
    ];
    const installmentGroups = await this.tenant.withTenantTx(async () => {
      const linhas = await this.repo.listByGroups(gruposCitados);
      const porGrupo = new Map<
        string,
        { groupId: string; total: number; count: number; paidCount: number }
      >();
      for (const l of linhas) {
        const g = l.installment_group_id as string;
        const atual =
          porGrupo.get(g) ?? { groupId: g, total: 0, count: 0, paidCount: 0 };
        atual.total = round2(atual.total + toNum(l.amount));
        atual.count += 1;
        if (l.paid_at) atual.paidCount += 1;
        porGrupo.set(g, atual);
      }
      return [...porGrupo.values()];
    });

    return {
      items: visiveis,
      categories: categorias,
      recurrences,
      installmentGroups,
      totalPrevisto: round2(totalPrevisto),
      totalPago: round2(totalPago),
      totalEmAberto: round2(totalEmAberto),
      totalVencido: round2(totalVencido),
    };
  }

  /**
   * Uma conta com o contexto que o detalhe mostra: a regra que a gerou e as
   * irmãs de parcelamento.
   *
   * Serve também o caminho **caixa → despesa**: o lançamento guarda
   * `sale_kind='expense'` + `sale_id` = o id desta conta, então o clique no
   * extrato chega aqui direto, sem busca por `cash_entry_id`.
   */
  async findOne(id: string) {
    return this.tenant.withTenantTx(async () => {
      const conta = await this.repo.findById(id);
      if (!conta) throw new NotFoundException('Despesa não encontrada.');
      const recurrence = conta.recurrence_id
        ? await this.repo.findRecurrence(conta.recurrence_id)
        : null;
      const parcelas = conta.installment_group_id
        ? await this.repo.listInstallmentGroup(conta.installment_group_id)
        : [];
      return { expense: conta, recurrence, parcelas };
    });
  }

  /**
   * Dados públicos da empresa pelo CNPJ, para preencher o fornecedor da conta.
   *
   * Rota própria do módulo em vez de reusar a de `customers`: `expenses` não pode
   * depender de o módulo de clientes estar habilitado no plano (regra 1). O
   * gateway em `common/cnpj` é o mesmo — a integração não é duplicada.
   */
  async lookupCnpj(raw: string) {
    const doc = normalizeCnpj(raw);
    if (!isValidCnpj(doc)) throw new BadRequestException('CNPJ inválido.');
    const empresa = await this.cnpj.fetch(doc);
    return { ...empresa, cnpj: formatCnpj(doc), doc };
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
    const fornecedor = this.normalizarFornecedor(dto);

    if (dto.parcelas && dto.recorrencia) {
      // O CHECK do banco barra, mas a mensagem dele não explica nada. Os dois
      // conceitos geram várias contas e por isso se confundem: parcela é fatia de
      // um total conhecido, recorrência é a mesma conta repetindo sem fim.
      throw new BadRequestException(
        'Escolha uma coisa só: parcelar o valor ou repetir todo mês.',
      );
    }
    if (dto.parcelas) {
      return this.criarParcelado(user, dto, {
        vencimento,
        total: valor,
        fornecedor,
      });
    }

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
          supplier_name: fornecedor.name,
          supplier_doc: fornecedor.doc,
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

  /**
   * Despesas do período agrupadas por CATEGORIA — porta pública consumida pelo
   * módulo `report`.
   *
   * Existe para o `report` NÃO tocar as tabelas `expense*` (regra 1): ele compõe
   * chamando este método, como já faz com OS, estoque e caixa.
   *
   * Recorta pelo VENCIMENTO e não pela data de pagamento: a pergunta que o
   * relatório responde é "quanto esse mês me custou", e uma conta de agosto paga
   * com atraso em setembro é custo de agosto. Por isso `pago` e `emAberto` do
   * mesmo período somam o `previsto` — são as duas partes dele, não recortes
   * diferentes.
   */
  async summaryByCategory(
    range: { from: Date; to: Date },
  ): Promise<{
    range: { from: string; to: string };
    rows: Array<{
      categoryId: string | null;
      categoryName: string;
      categoryColor: string | null;
      count: number;
      previsto: number;
      pago: number;
      emAberto: number;
      vencido: number;
    }>;
    totals: {
      count: number;
      previsto: number;
      pago: number;
      emAberto: number;
      vencido: number;
    };
  }> {
    const hoje = new Date();
    const hojeDia = new Date(
      Date.UTC(hoje.getFullYear(), hoje.getMonth(), hoje.getDate()),
    );

    const { itens, categorias } = await this.tenant.withTenantTx(async () => ({
      itens: await this.repo.listByDueRange({ de: range.from, ate: range.to }),
      categorias: await this.repo.listCategories({ includeDisabled: true }),
    }));

    const nomes = new Map(categorias.map((c) => [c.id, c]));
    const porCat = new Map<string, {
      categoryId: string | null;
      categoryName: string;
      categoryColor: string | null;
      count: number;
      previsto: number;
      pago: number;
      emAberto: number;
      vencido: number;
    }>();

    for (const e of itens) {
      // Chave vazia para as SEM categoria: elas existem (categoria é opcional) e
      // omiti-las faria a soma das linhas não fechar com o total.
      const chave = e.category_id ?? '';
      const cat = e.category_id ? nomes.get(e.category_id) : undefined;
      const linha =
        porCat.get(chave) ??
        {
          categoryId: e.category_id ?? null,
          categoryName: cat?.name ?? 'Sem categoria',
          categoryColor: cat?.color ?? null,
          count: 0,
          previsto: 0,
          pago: 0,
          emAberto: 0,
          vencido: 0,
        };
      const valor = toNum(e.amount);
      linha.count += 1;
      linha.previsto = round2(linha.previsto + valor);
      if (e.paid_at) {
        // O que REALMENTE saiu: juros e desconto fazem o pago divergir do
        // previsto, e o relatório de custo precisa do que saiu.
        linha.pago = round2(linha.pago + toNum(e.paid_amount ?? e.amount));
      } else {
        linha.emAberto = round2(linha.emAberto + valor);
        if (e.due_date < hojeDia) linha.vencido = round2(linha.vencido + valor);
      }
      porCat.set(chave, linha);
    }

    // Maior gasto primeiro: o relatório responde "para onde vai o dinheiro", e a
    // resposta é a primeira linha.
    const rows = [...porCat.values()].sort((a, b) => b.previsto - a.previsto);
    const totals = rows.reduce(
      (acc, r) => ({
        count: acc.count + r.count,
        previsto: round2(acc.previsto + r.previsto),
        pago: round2(acc.pago + r.pago),
        emAberto: round2(acc.emAberto + r.emAberto),
        vencido: round2(acc.vencido + r.vencido),
      }),
      { count: 0, previsto: 0, pago: 0, emAberto: 0, vencido: 0 },
    );

    return {
      range: {
        from: range.from.toISOString(),
        to: range.to.toISOString(),
      },
      rows,
      totals,
    };
  }

  /**
   * Fornecedor saneado: nome aparado e documento SÓ COM DÍGITOS.
   *
   * A máscara é da UI; gravar "12.345.678/0001-95" tornaria impossível agrupar as
   * contas de um mesmo fornecedor (a mesma empresa digitada duas vezes com
   * pontuação diferente viraria dois fornecedores). O CHECK do banco exige 11 ou
   * 14 dígitos, então validamos aqui para devolver mensagem que ajuda.
   */
  private normalizarFornecedor(dto: {
    supplierName?: string;
    supplierDoc?: string;
  }): { name: string | null; doc: string | null } {
    const name = dto.supplierName?.trim() || null;
    const cru = (dto.supplierDoc ?? '').replace(/\D/g, '');
    if (!cru) return { name, doc: null };
    if (cru.length !== 11 && cru.length !== 14) {
      throw new BadRequestException(
        'Documento do fornecedor deve ser um CPF (11 dígitos) ou CNPJ (14).',
      );
    }
    return { name, doc: cru };
  }

  /**
   * Compra parcelada: UMA dívida, N vencimentos mensais.
   *
   * O `amount` recebido é o **total**; quem rateia é aqui (`ratearParcelas`), em
   * centavos inteiros, com o resto na primeira. Deixar a divisão para o cliente
   * faria a soma das parcelas fechar diferente do total combinado com o
   * fornecedor — e a dívida cadastrada deixaria de ser a dívida real.
   *
   * Devolve a PRIMEIRA parcela: é a que a cliente acabou de cadastrar e a que a
   * tela precisa mostrar. As irmãs vêm na listagem dos meses seguintes.
   */
  private async criarParcelado(
    user: AuthUser,
    dto: CreateExpenseDto,
    ctx: {
      vencimento: Date;
      total: number;
      fornecedor: { name: string | null; doc: string | null };
    },
  ) {
    const n = dto.parcelas as number;
    if (ctx.total <= 0) {
      // Parcelar "valor a confirmar" não tem como: sem total não há o que dividir.
      throw new BadRequestException(
        'Informe o valor total para parcelar a despesa.',
      );
    }
    const ids = dto.installmentIds;
    if (ids && ids.length !== n) {
      throw new BadRequestException(
        `Esperava ${n} ids de parcela, recebi ${ids.length}.`,
      );
    }
    if (ids && new Set(ids).size !== ids.length) {
      throw new BadRequestException('Ids de parcela repetidos.');
    }

    const valores = ratearParcelas(ctx.total, n);
    const datas = datasDasParcelas(ctx.vencimento, n);

    const primeira = await this.tenant.withTenantTx(async () => {
      await this.validarCategoria(dto.categoryId);
      // Um grupo por parcelamento. Vem do cliente quando ele já criou as linhas
      // offline, para o espelho local e o servidor apontarem para o mesmo grupo
      // desde o primeiro instante.
      const grupo = dto.installmentGroupId ?? randomUUID();
      const linhas: NewExpenseData[] = valores.map((v, i) => ({
        id: ids?.[i],
        description: dto.description.trim(),
        amount: v,
        due_date: datas[i],
        category_id: dto.categoryId ?? null,
        recurrence_id: null,
        occurrence_on: null,
        notes: dto.notes?.trim() || null,
        created_by: user.userId,
        installment_no: i + 1,
        installment_total: n,
        installment_group_id: grupo,
        supplier_name: ctx.fornecedor.name,
        supplier_doc: ctx.fornecedor.doc,
      }));
      try {
        // `createMany` e não N `create`: uma ida ao banco, e o grupo nasce inteiro
        // ou não nasce — meia compra parcelada seria pior que erro.
        await this.repo.createMany(user.tenantId, linhas);
      } catch (e) {
        if (isUniqueViolation(e)) {
          throw new ConflictException('Registro já existe (id duplicado).');
        }
        throw e;
      }
      const doGrupo = await this.repo.listInstallmentGroup(grupo);
      return doGrupo[0];
    });

    await this.audit.log(
      user.tenantId,
      user.userId,
      'expense_create',
      primeira.id,
      {
        amount: ctx.total,
        dueDate: dto.dueDate,
        parcelas: n,
        installmentGroupId: primeira.installment_group_id,
      },
    );
    return primeira;
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
      const fornecedor = this.normalizarFornecedor(dto);
      return this.repo.update(id, {
        description: dto.description?.trim(),
        amount: dto.amount === undefined ? undefined : round2(dto.amount),
        due_date: dto.dueDate ? parseDia(dto.dueDate) : undefined,
        category_id: dto.limparCategoria ? null : dto.categoryId,
        notes: dto.notes === undefined ? undefined : dto.notes.trim() || null,
        supplier_name: dto.limparFornecedor ? null : fornecedor.name ?? undefined,
        supplier_doc: dto.limparFornecedor ? null : fornecedor.doc ?? undefined,
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
      // Marca a ORIGEM no lançamento para o clique no extrato abrir esta conta.
      // Antes ia nulo, e o vínculo existia só neste sentido (despesa → caixa) —
      // o caixa mostrava "Aluguel" sem caminho de volta.
      originId: id,
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
          tracks_supplier: dto.tracksSupplier ?? false,
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
          tracks_supplier: dto.tracksSupplier,
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
