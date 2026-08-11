import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { TenantContext } from '../../common/database/tenant-context';
import {
  ChangeCursor,
  ChangedSincePage,
  queryChangedSince,
} from '../../common/database/changed-since';
import type {
  EntryCategory,
  EntryDirection,
  PaymentMethod,
  SaleKind,
} from './cashier.config';

type DecimalIn = Prisma.Decimal | number;

/** Entidades do módulo cashier expostas ao pull de sync offline. */
export type CashierSyncEntity =
  | 'cash_session'
  | 'cash_entry'
  | 'cash_expense_template'
  | 'receivable_installment';

/** Modelo de despesa fixa a inserir. `amount: 0` = "o valor varia". */
export interface NewTemplateData {
  /** Uuid vindo do cliente (replay offline) — opcional; INSERT puro. */
  id?: string;
  name: string;
  amount: DecimalIn;
  category: 'despesa' | 'sangria';
  method: PaymentMethod | null;
  created_by: string;
}

/** Campos editáveis de um modelo (inclui `status` para desativar). */
export interface TemplatePatch {
  name?: string;
  amount?: DecimalIn;
  category?: 'despesa' | 'sangria';
  method?: PaymentMethod | null;
  status?: 'active' | 'disabled';
}

export interface NewEntryData {
  /** Uuid vindo do cliente (replay offline) — opcional; INSERT puro (S9: sem upsert). */
  id?: string;
  cash_session_id: string;
  direction: EntryDirection;
  amount: DecimalIn;
  method: PaymentMethod;
  category: EntryCategory;
  sale_kind: SaleKind | null;
  sale_id: string | null;
  description: string | null;
  created_by: string;
}

export interface EntryFilter {
  sessionId?: string;
  /** Busca textual na descrição (número da OS/venda, nome do cliente). */
  q?: string;
  direction?: EntryDirection;
  method?: string;
  category?: string;
  saleKind?: string;
  saleId?: string;
  from?: Date;
  to?: Date;
  skip: number;
  take: number;
}

/**
 * Único ponto que toca `cash_session` / `cash_entry`. Sempre via
 * `tenant.getClient()` (cliente tx-scoped sob RLS); o service abre o
 * `withTenantTx`/`runWithTenant`. Nunca recebe tenant_id do cliente — vem do CLS.
 */
@Injectable()
export class CashierRepository {
  constructor(private readonly tenant: TenantContext) {}

  // ===================== Sessões =====================
  createSession(
    tenantId: string,
    data: {
      /** Uuid vindo do cliente (replay offline) — opcional; INSERT puro (S9: sem upsert). */
      id?: string;
      opened_by: string;
      opening_amount: DecimalIn;
      notes: string | null;
      device_id?: string | null;
    },
  ) {
    const db = this.tenant.getClient();
    return db.cash_session.create({
      data: { tenant_id: tenantId, status: 'open', ...data },
    });
  }

  /**
   * Sessão aberta do PONTO de caixa `deviceId` (dispositivo/terminal). `deviceId`
   * ausente/`null` é o ponto legado (NULL). O filtro Prisma `device_id: null | uuid`
   * já compila para `device_id IS NULL` / `device_id = $1` — equivalente a
   * `IS NOT DISTINCT FROM` para este caso (comparação contra valor fixo, nunca
   * NULL-vs-NULL ambíguo), casando com o índice parcial `uq_cash_session_open_device`.
   */
  findOpenSession(deviceId?: string | null) {
    const db = this.tenant.getClient();
    return db.cash_session.findFirst({
      where: { status: 'open', device_id: deviceId ?? null },
    });
  }

  findSessionById(id: string) {
    const db = this.tenant.getClient();
    return db.cash_session.findUnique({ where: { id } });
  }

  closeSession(
    id: string,
    data: {
      closed_by: string;
      closing_amount_counted: DecimalIn;
      closing_amount_expected: DecimalIn;
      difference: DecimalIn;
      notes: string | null;
    },
  ) {
    const db = this.tenant.getClient();
    return db.cash_session.update({
      where: { id },
      data: {
        ...data,
        status: 'closed',
        closed_at: new Date(),
        updated_at: new Date(),
      },
    });
  }

  /**
   * Histórico de sessões, opcionalmente restrito a um PONTO de caixa e/ou
   * status. `deviceId` ausente ⇒ sem restrição de ponto (todo o tenant); para
   * alcançar o ponto legado (device_id NULL) o caller passa `deviceId: null`
   * explicitamente — por isso a distinção entre `undefined` e `null` importa.
   */
  async listSessions(p: {
    skip: number;
    take: number;
    deviceId?: string | null;
    status?: 'open' | 'closed';
  }) {
    const db = this.tenant.getClient();
    const where = {
      ...(p.deviceId !== undefined ? { device_id: p.deviceId } : {}),
      ...(p.status ? { status: p.status } : {}),
    };
    const [items, total] = await Promise.all([
      db.cash_session.findMany({
        where,
        orderBy: [{ opened_at: 'desc' }, { id: 'desc' }],
        skip: p.skip,
        take: p.take,
      }),
      db.cash_session.count({ where }),
    ]);
    return { items, total };
  }

  // ===================== Lançamentos =====================
  createEntry(tenantId: string, data: NewEntryData) {
    const db = this.tenant.getClient();
    return db.cash_entry.create({
      data: { tenant_id: tenantId, ...data },
    });
  }

  findEntryById(id: string) {
    const db = this.tenant.getClient();
    return db.cash_entry.findUnique({ where: { id } });
  }

  /**
   * Atualiza campos NÃO-financeiros do lançamento (o que ele diz). Valor, forma
   * e direção nunca passam por aqui — ver `correctEntry` no service.
   */
  updateEntry(
    id: string,
    data: { description?: string | null; category?: string },
  ) {
    const db = this.tenant.getClient();
    return db.cash_entry.update({
      where: { id },
      data: { ...data, updated_at: new Date() },
    });
  }

  markReversed(
    id: string,
    data: { reversed_by: string; reversal_reason: string },
  ) {
    const db = this.tenant.getClient();
    return db.cash_entry.update({
      where: { id },
      data: { ...data, reversed_at: new Date() },
    });
  }

  private entryWhere(filter: EntryFilter): Prisma.cash_entryWhereInput {
    return {
      ...(filter.sessionId ? { cash_session_id: filter.sessionId } : {}),
      ...(filter.direction ? { direction: filter.direction } : {}),
      ...(filter.method ? { method: filter.method } : {}),
      ...(filter.category ? { category: filter.category } : {}),
      ...(filter.saleKind ? { sale_kind: filter.saleKind } : {}),
      ...(filter.saleId ? { sale_id: filter.saleId } : {}),
      ...(filter.q
        ? { description: { contains: filter.q, mode: 'insensitive' as const } }
        : {}),
      ...(filter.from || filter.to
        ? {
            created_at: {
              ...(filter.from ? { gte: filter.from } : {}),
              ...(filter.to ? { lte: filter.to } : {}),
            },
          }
        : {}),
    };
  }

  async listEntries(filter: EntryFilter) {
    const db = this.tenant.getClient();
    const where = this.entryWhere(filter);
    const [items, total] = await Promise.all([
      db.cash_entry.findMany({
        where,
        orderBy: [{ created_at: 'desc' }, { id: 'desc' }],
        skip: filter.skip,
        take: filter.take,
      }),
      db.cash_entry.count({ where }),
    ]);
    return { items, total };
  }

  /** Entries (não estornadas) de uma venda — para o resumo de pagamento. */
  listEntriesForSale(saleId: string) {
    const db = this.tenant.getClient();
    return db.cash_entry.findMany({
      where: { sale_id: saleId, reversed_at: null },
      orderBy: [{ created_at: 'asc' }, { id: 'asc' }],
    });
  }

  // ===================== Agregações =====================
  /** Σ recebido (direction 'in', não estornado) de uma venda. */
  async sumPaidForSale(saleId: string): Promise<number> {
    const db = this.tenant.getClient();
    const agg = await db.cash_entry.aggregate({
      where: { sale_id: saleId, direction: 'in', reversed_at: null },
      _sum: { amount: true },
    });
    return toNum(agg._sum.amount);
  }

  /** Σ recebido por venda (batch) — mapa sale_id → pago. */
  async sumPaidForSales(saleIds: string[]): Promise<Map<string, number>> {
    const db = this.tenant.getClient();
    const rows = await db.cash_entry.groupBy({
      by: ['sale_id'],
      where: { sale_id: { in: saleIds }, direction: 'in', reversed_at: null },
      _sum: { amount: true },
    });
    const map = new Map<string, number>();
    for (const r of rows) {
      if (r.sale_id) map.set(r.sale_id, toNum(r._sum.amount));
    }
    return map;
  }

  /**
   * Totais de DINHEIRO de uma sessão (não estornado), por direção — base do
   * `expected` no fechamento com countCashOnly.
   */
  async sessionCashTotals(
    sessionId: string,
  ): Promise<{ cashIn: number; cashOut: number }> {
    const db = this.tenant.getClient();
    const rows = await db.cash_entry.groupBy({
      by: ['direction'],
      where: {
        cash_session_id: sessionId,
        method: 'dinheiro',
        reversed_at: null,
      },
      _sum: { amount: true },
    });
    let cashIn = 0;
    let cashOut = 0;
    for (const r of rows) {
      if (r.direction === 'in') cashIn = toNum(r._sum.amount);
      else cashOut = toNum(r._sum.amount);
    }
    return { cashIn, cashOut };
  }

  /** Totais de uma sessão por (método, direção) — informativo no fechamento. */
  sessionTotalsByMethod(sessionId: string) {
    const db = this.tenant.getClient();
    return db.cash_entry.groupBy({
      by: ['method', 'direction'],
      where: { cash_session_id: sessionId, reversed_at: null },
      _sum: { amount: true },
    });
  }

  // ----- resumo por período (base dos relatórios) -----
  private periodWhere(p: {
    from?: Date;
    to?: Date;
  }): Prisma.cash_entryWhereInput {
    return {
      reversed_at: null,
      ...(p.from || p.to
        ? {
            created_at: {
              ...(p.from ? { gte: p.from } : {}),
              ...(p.to ? { lte: p.to } : {}),
            },
          }
        : {}),
    };
  }

  summaryByMethod(p: { from?: Date; to?: Date }) {
    const db = this.tenant.getClient();
    return db.cash_entry.groupBy({
      by: ['method', 'direction'],
      where: this.periodWhere(p),
      _sum: { amount: true },
    });
  }

  summaryByCategory(p: { from?: Date; to?: Date }) {
    const db = this.tenant.getClient();
    return db.cash_entry.groupBy({
      by: ['category', 'direction'],
      where: this.periodWhere(p),
      _sum: { amount: true },
    });
  }

  summaryByOrigin(p: { from?: Date; to?: Date }) {
    const db = this.tenant.getClient();
    return db.cash_entry.groupBy({
      by: ['sale_kind', 'direction'],
      where: this.periodWhere(p),
      _sum: { amount: true },
    });
  }

  // ============ Despesas fixas (modelos de lançamento) ============
  /**
   * Modelos ATIVOS, mais usados primeiro não — por nome, que é o que o operador
   * procura visualmente numa fileira curta de atalhos.
   */
  listTemplates(p: { includeDisabled?: boolean } = {}) {
    const db = this.tenant.getClient();
    return db.cash_expense_template.findMany({
      where: p.includeDisabled ? {} : { status: 'active' },
      orderBy: [{ status: 'asc' }, { name: 'asc' }],
    });
  }

  findTemplate(id: string) {
    const db = this.tenant.getClient();
    return db.cash_expense_template.findUnique({ where: { id } });
  }

  /** Busca por nome entre os ATIVOS (mesma regra do unique parcial). */
  findActiveTemplateByName(name: string) {
    const db = this.tenant.getClient();
    return db.cash_expense_template.findFirst({
      where: {
        status: 'active',
        name: { equals: name.trim(), mode: 'insensitive' },
      },
    });
  }

  createTemplate(tenantId: string, data: NewTemplateData) {
    const db = this.tenant.getClient();
    return db.cash_expense_template.create({
      data: { tenant_id: tenantId, ...data },
    });
  }

  updateTemplate(id: string, data: TemplatePatch) {
    const db = this.tenant.getClient();
    return db.cash_expense_template.update({
      where: { id },
      data: { ...data, updated_at: new Date() },
    });
  }

  // ===================== Sync pull (offline) =====================
  /**
   * Página de mudanças de `cash_session`/`cash_entry` desde o cursor (ambas
   * com `updated_at` — migration 0031). Sync pull — ver
   * `common/database/changed-since.ts`.
   */
  listChangedSince(
    table: CashierSyncEntity,
    cursor: ChangeCursor | null,
    limit: number,
  ): Promise<ChangedSincePage> {
    const db = this.tenant.getClient();
    return queryChangedSince(db, table, 'updated_at', cursor, limit);
  }
}

const toNum = (d: Prisma.Decimal | number | null | undefined): number =>
  d == null ? 0 : typeof d === 'number' ? d : d.toNumber();
