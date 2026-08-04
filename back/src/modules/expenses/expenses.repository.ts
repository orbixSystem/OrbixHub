import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { TenantContext } from '../../common/database/tenant-context';
import {
  ChangeCursor,
  ChangedSincePage,
  queryChangedSince,
} from '../../common/database/changed-since';
import type { Frequency, PaymentMethod } from './expenses.config';

type DecimalIn = Prisma.Decimal | number;

/** Entidades do módulo expostas ao pull de sync offline. */
export type ExpensesSyncEntity =
  | 'expense'
  | 'expense_category'
  | 'expense_recurrence';

export interface NewExpenseData {
  /** Uuid vindo do cliente (replay offline) — opcional; INSERT puro. */
  id?: string;
  description: string;
  amount: DecimalIn;
  due_date: Date;
  category_id: string | null;
  recurrence_id: string | null;
  occurrence_on: Date | null;
  notes: string | null;
  created_by: string;
  /** Parcelamento — as três juntas ou nenhuma (CHECK `expense_installment_chk`). */
  installment_no?: number | null;
  installment_total?: number | null;
  installment_group_id?: string | null;
  supplier_name?: string | null;
  supplier_doc?: string | null;
}

export interface ExpensePatch {
  description?: string;
  amount?: DecimalIn;
  due_date?: Date;
  category_id?: string | null;
  notes?: string | null;
  status?: 'active' | 'canceled';
  supplier_name?: string | null;
  supplier_doc?: string | null;
}

export interface PaymentPatch {
  paid_at: Date | null;
  paid_amount: DecimalIn | null;
  paid_method: PaymentMethod | null;
  cash_entry_id: string | null;
}

export interface NewRecurrenceData {
  id?: string;
  description: string;
  amount: DecimalIn;
  category_id: string | null;
  frequency: Frequency;
  day_of_month: number;
  month_of_year: number | null;
  method: PaymentMethod | null;
  notes: string | null;
  starts_on: Date;
  ends_on: Date | null;
  created_by: string;
}

/**
 * Único ponto que toca `expense` / `expense_category` / `expense_recurrence`.
 * Sempre via `tenant.getClient()` (cliente tx-scoped sob RLS); o service abre o
 * `withTenantTx`. Nunca recebe tenant_id do cliente — vem do CLS.
 */
@Injectable()
export class ExpensesRepository {
  constructor(
    private readonly tenant: TenantContext,
    /**
     * SÓ para a função `SECURITY DEFINER` do job (varredura entre tenants), que
     * por definição roda sem tenant no CLS. Nenhuma tabela RLS é acessada por
     * aqui — para elas vale a regra: sempre `tenant.getClient()`.
     */
    private readonly prisma: PrismaService,
  ) {}

  /**
   * Regras que ainda não alcançaram o horizonte, de TODOS os tenants. Devolve só
   * ponteiros; quem lê a regra é o job, já dentro de `runWithTenant`.
   */
  findRecurrencesToExtendGlobal(ate: Date) {
    return this.prisma.$queryRaw<
      Array<{ tenant_id: string; recurrence_id: string }>
    >`SELECT tenant_id, recurrence_id FROM expenses_find_recurrences_to_extend(${ate}::date)`;
  }

  // ===================== Contas =====================
  /**
   * Contas de um mês + as VENCIDAS em aberto de meses anteriores.
   *
   * O arrasto das vencidas é regra de produto: uma conta de agosto não paga
   * precisa continuar visível em setembro. Deixá-la só no mês em que venceu
   * esconderia justamente o que exige ação.
   */
  listByMonth(p: { de: Date; ate: Date }) {
    const db = this.tenant.getClient();
    return db.expense.findMany({
      where: {
        status: 'active',
        OR: [
          { due_date: { gte: p.de, lt: p.ate } },
          { due_date: { lt: p.de }, paid_at: null },
        ],
      },
      orderBy: [{ due_date: 'asc' }, { description: 'asc' }],
    });
  }

  findById(id: string) {
    const db = this.tenant.getClient();
    return db.expense.findUnique({ where: { id } });
  }

  /** A despesa cuja baixa gerou este lançamento do caixa (caminho de volta). */
  findByCashEntry(cashEntryId: string) {
    const db = this.tenant.getClient();
    return db.expense.findFirst({ where: { cash_entry_id: cashEntryId } });
  }

  /**
   * As parcelas de um grupo, na ordem. O detalhe mostra "2 de 6" e o total da
   * dívida, que é a SOMA das irmãs — não há coluna de total, de propósito.
   */
  listInstallmentGroup(groupId: string) {
    const db = this.tenant.getClient();
    return db.expense.findMany({
      where: { installment_group_id: groupId, status: 'active' },
      orderBy: { installment_no: 'asc' },
    });
  }

  /** Regras citadas por um conjunto de contas (para a tela dizer "próxima em…"). */
  listRecurrencesByIds(ids: string[]) {
    if (ids.length === 0) return Promise.resolve([]);
    const db = this.tenant.getClient();
    return db.expense_recurrence.findMany({ where: { id: { in: ids } } });
  }

  create(tenantId: string, data: NewExpenseData) {
    const db = this.tenant.getClient();
    return db.expense.create({ data: { tenant_id: tenantId, ...data } });
  }

  /**
   * Insere várias ocorrências de uma vez (esteira). `skipDuplicates` cobre o
   * unique parcial `(tenant_id, recurrence_id, occurrence_on)`: rodar o gerador
   * duas vezes não duplica o aluguel de setembro.
   */
  createMany(tenantId: string, rows: NewExpenseData[]) {
    const db = this.tenant.getClient();
    return db.expense.createMany({
      data: rows.map((r) => ({ tenant_id: tenantId, ...r })),
      skipDuplicates: true,
    });
  }

  update(id: string, data: ExpensePatch) {
    const db = this.tenant.getClient();
    return db.expense.update({
      where: { id },
      data: { ...data, updated_at: new Date() },
    });
  }

  /** Grava (ou desfaz) o pagamento. `paid_at: null` = volta para em aberto. */
  setPayment(id: string, data: PaymentPatch) {
    const db = this.tenant.getClient();
    return db.expense.update({
      where: { id },
      data: { ...data, updated_at: new Date() },
    });
  }

  // ===================== Categorias =====================
  listCategories(p: { includeDisabled?: boolean } = {}) {
    const db = this.tenant.getClient();
    return db.expense_category.findMany({
      where: p.includeDisabled ? {} : { status: 'active' },
      orderBy: [{ status: 'asc' }, { name: 'asc' }],
    });
  }

  findCategory(id: string) {
    const db = this.tenant.getClient();
    return db.expense_category.findUnique({ where: { id } });
  }

  createCategory(
    tenantId: string,
    data: {
      id?: string;
      name: string;
      icon: string;
      color: string;
      tracks_supplier: boolean;
    },
  ) {
    const db = this.tenant.getClient();
    return db.expense_category.create({ data: { tenant_id: tenantId, ...data } });
  }

  updateCategory(
    id: string,
    data: {
      name?: string;
      icon?: string;
      color?: string;
      tracks_supplier?: boolean;
      status?: 'active' | 'disabled';
    },
  ) {
    const db = this.tenant.getClient();
    return db.expense_category.update({
      where: { id },
      data: { ...data, updated_at: new Date() },
    });
  }

  /**
   * Semeia as categorias padrão do tenant, ignorando as que já existem.
   *
   * Chamado na primeira listagem em vez de no registro do tenant: assim o módulo
   * `auth` não precisa conhecer `expenses` (regra 1). `skipDuplicates` torna a
   * chamada repetida inofensiva.
   */
  seedCategories(
    tenantId: string,
    rows: Array<{
      name: string;
      icon: string;
      color: string;
      tracks_supplier: boolean;
    }>,
  ) {
    const db = this.tenant.getClient();
    return db.expense_category.createMany({
      data: rows.map((r) => ({ tenant_id: tenantId, ...r })),
      skipDuplicates: true,
    });
  }

  countCategories() {
    const db = this.tenant.getClient();
    return db.expense_category.count();
  }

  // ===================== Recorrências =====================
  createRecurrence(tenantId: string, data: NewRecurrenceData) {
    const db = this.tenant.getClient();
    return db.expense_recurrence.create({
      data: { tenant_id: tenantId, ...data },
    });
  }

  findRecurrence(id: string) {
    const db = this.tenant.getClient();
    return db.expense_recurrence.findUnique({ where: { id } });
  }

  /** Regras ativas que ainda podem gerar ocorrências — insumo do job diário. */
  listRecurrenciesToExtend(ate: Date) {
    const db = this.tenant.getClient();
    return db.expense_recurrence.findMany({
      where: {
        status: 'active',
        OR: [{ generated_through: null }, { generated_through: { lt: ate } }],
        AND: [{ OR: [{ ends_on: null }, { ends_on: { gte: new Date() } }] }],
      },
    });
  }

  updateRecurrence(
    id: string,
    data: {
      description?: string;
      amount?: DecimalIn;
      category_id?: string | null;
      day_of_month?: number;
      month_of_year?: number | null;
      method?: PaymentMethod | null;
      notes?: string | null;
      ends_on?: Date | null;
      generated_through?: Date | null;
      status?: 'active' | 'disabled';
    },
  ) {
    const db = this.tenant.getClient();
    return db.expense_recurrence.update({
      where: { id },
      data: { ...data, updated_at: new Date() },
    });
  }

  // ===================== Sync pull (offline) =====================
  listChangedSince(
    table: ExpensesSyncEntity,
    cursor: ChangeCursor | null,
    limit: number,
  ): Promise<ChangedSincePage> {
    const db = this.tenant.getClient();
    return queryChangedSince(db, table, 'updated_at', cursor, limit);
  }
}
