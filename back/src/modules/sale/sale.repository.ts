import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import {
  queryChangedSince,
  type ChangeCursor,
  type ChangedSincePage,
} from '../../common/database/changed-since';
import { TenantContext } from '../../common/database/tenant-context';

type DecimalIn = Prisma.Decimal | number;

/** Tabelas do módulo replicadas para o offline (whitelist do pull de sync). */
export type SaleSyncEntity = 'sale' | 'sale_item';

/**
 * Coluna de cursor por entidade. `sale_item` só tem `created_at` — e isso é
 * correto, não uma limitação: a linha do item é IMUTÁVEL (nasce com a venda e
 * nunca é editada; cancelar mexe no `status` da venda, não nos itens). Paginar
 * por `created_at` cobre toda mudança que pode existir nela.
 */
const SYNC_ENTITY_COLUMN: Record<SaleSyncEntity, 'updated_at' | 'created_at'> = {
  sale: 'updated_at',
  sale_item: 'created_at',
};

export interface CreateSaleData {
  /**
   * Preserva o uuid gerado no cliente (venda criada offline). Ausente = o banco
   * gera. Sem isto o replay criaria uma venda com id novo e o aparelho ficaria
   * com uma órfã que nunca casa com a do servidor.
   */
  id?: string;
  number: string;
  customer_id: string | null;
  customer_name: string | null;
  status: string;
  /** Valor A PAGAR (já com desconto aplicado). */
  total: DecimalIn;
  /** Desconto concedido (registro; não entra no total). */
  discount?: DecimalIn;
  created_by: string | null;
}

export interface CreateSaleItemData {
  kind: 'product' | 'service';
  inventory_item_id: string | null;
  name: string;
  quantity: DecimalIn;
  unit_price: DecimalIn;
  subtotal: DecimalIn;
}

export interface FiscalSnapshotFields {
  fiscal_status: string | null;
  fiscal_external_id: string | null;
  fiscal_emitted_at: Date | null;
}

export interface SaleListFilter {
  status?: string;
  customerId?: string;
  /** Busca por número da venda OU nome do cliente (snapshot). */
  q?: string;
  /** Recorte por `created_at` (histórico por período). */
  from?: Date;
  to?: Date;
  skip: number;
  take: number;
}

/**
 * Único ponto que toca `sale` / `sale_item`. Sempre via `tenant.getClient()`
 * (cliente tx-scoped sob RLS); o service abre o `withTenantTx`/`runWithTenant`.
 * Nunca recebe tenant_id do cliente — vem do CLS/JWT.
 */
@Injectable()
export class SaleRepository {
  constructor(private readonly tenant: TenantContext) {}

  /** Maior sufixo numérico de `number` (VND-NNNN) do tenant; 0 se nenhum. */
  async maxSaleNumber(): Promise<number> {
    const db = this.tenant.getClient();
    const rows = await db.$queryRaw<Array<{ max: number | null }>>`
      SELECT MAX(NULLIF(regexp_replace(number, '[^0-9]', '', 'g'), '')::int) AS max
      FROM sale
    `;
    return rows[0]?.max ?? 0;
  }

  createSale(tenantId: string, data: CreateSaleData) {
    const db = this.tenant.getClient();
    return db.sale.create({
      data: { tenant_id: tenantId, ...data } as Prisma.saleUncheckedCreateInput,
    });
  }

  addItem(tenantId: string, saleId: string, data: CreateSaleItemData) {
    const db = this.tenant.getClient();
    return db.sale_item.create({
      data: {
        tenant_id: tenantId,
        sale_id: saleId,
        ...data,
      } as Prisma.sale_itemUncheckedCreateInput,
    });
  }

  findSaleById(id: string) {
    const db = this.tenant.getClient();
    return db.sale.findUnique({
      where: { id },
      include: { items: { orderBy: { created_at: 'asc' } } },
    });
  }

  async listSales(filter: SaleListFilter) {
    const db = this.tenant.getClient();
    const where: Prisma.saleWhereInput = {
      ...(filter.status ? { status: filter.status } : {}),
      ...(filter.customerId ? { customer_id: filter.customerId } : {}),
      ...(filter.from || filter.to
        ? {
            created_at: {
              ...(filter.from ? { gte: filter.from } : {}),
              ...(filter.to ? { lte: filter.to } : {}),
            },
          }
        : {}),
      ...(filter.q
        ? {
            OR: [
              { number: { contains: filter.q, mode: 'insensitive' } },
              { customer_name: { contains: filter.q, mode: 'insensitive' } },
            ],
          }
        : {}),
    };
    const [items, total] = await Promise.all([
      db.sale.findMany({
        where,
        orderBy: [{ created_at: 'desc' }, { id: 'desc' }],
        skip: filter.skip,
        take: filter.take,
        include: { items: { orderBy: { created_at: 'asc' } } },
      }),
      db.sale.count({ where }),
    ]);
    return { items, total };
  }

  /** Cancelamento lógico (nunca hard delete). */
  cancelSale(
    id: string,
    data: { canceled_by: string; canceled_reason: string | null },
  ) {
    const db = this.tenant.getClient();
    return db.sale.update({
      where: { id },
      data: {
        status: 'canceled',
        canceled_at: new Date(),
        ...data,
        updated_at: new Date(),
      },
    });
  }

  /** Linhas atuais da venda (para reconciliar estoque antes de substituí-las). */
  listItems(saleId: string) {
    const db = this.tenant.getClient();
    return db.sale_item.findMany({ where: { sale_id: saleId } });
  }

  /**
   * Apaga as linhas da venda. Linha de item é parte MUTÁVEL do documento, não
   * entidade com histórico — a OS faz o mesmo (`deleteItem`). O que nunca é
   * apagado é a venda (cancelamento é lógico).
   */
  deleteItems(saleId: string) {
    const db = this.tenant.getClient();
    return db.sale_item.deleteMany({ where: { sale_id: saleId } });
  }

  /** Total/desconto recalculados no servidor após editar as linhas. */
  setTotals(id: string, data: { total: DecimalIn; discount: DecimalIn }) {
    const db = this.tenant.getClient();
    return db.sale.update({
      where: { id },
      data: { ...data, updated_at: new Date() },
    });
  }

  /**
   * Vendas de um cliente, mais recente primeiro — alimenta o histórico da ficha
   * dele. Inclui canceladas: o histórico mostra o que aconteceu, e a tela marca
   * o status.
   */
  listSalesByCustomer(customerId: string) {
    const db = this.tenant.getClient();
    return db.sale.findMany({
      where: { customer_id: customerId },
      orderBy: { created_at: 'desc' },
    });
  }

  /**
   * Reatribui a venda a outro cliente (ponteiro + snapshot do nome). Só isto: o
   * dinheiro da venda nunca é editado aqui.
   */
  setCustomer(
    id: string,
    data: { customer_id: string | null; customer_name: string | null },
  ) {
    const db = this.tenant.getClient();
    return db.sale.update({
      where: { id },
      data: { ...data, updated_at: new Date() },
    });
  }

  /** Snapshot do status fiscal devolvido pelo Fiscal (só p/ exibir; Fiscal é dono). */
  setFiscalSnapshot(id: string, fields: FiscalSnapshotFields) {
    const db = this.tenant.getClient();
    return db.sale.update({
      where: { id },
      data: { ...fields, updated_at: new Date() },
    });
  }

  // ---- métricas / valores (seam público — consumido por report/caixa) ----
  /** Total de uma venda ATIVA (0 se inexistente/cancelada). */
  async saleTotal(id: string): Promise<number> {
    const db = this.tenant.getClient();
    const row = await db.sale.findFirst({
      where: { id, status: 'active' },
      select: { total: true },
    });
    return row ? toNum(row.total) : 0;
  }

  /** Totais por id (batch) de vendas ATIVAS — mapa id → total. */
  async saleTotals(ids: string[]): Promise<Map<string, number>> {
    const db = this.tenant.getClient();
    const rows = await db.sale.findMany({
      where: { id: { in: ids }, status: 'active' },
      select: { id: true, total: true },
    });
    return new Map(rows.map((r) => [r.id, toNum(r.total)]));
  }

  /**
   * Linhas de vendas ATIVAS no range [from, to] (mais recentes no topo) — alimenta
   * a lente "Vendas" do relatório (read-only). Tenant-scoped por RLS.
   */
  listForReport(p: { from: Date; to: Date }) {
    const db = this.tenant.getClient();
    return db.sale.findMany({
      where: { status: 'active', created_at: { gte: p.from, lte: p.to } },
      orderBy: [{ created_at: 'desc' }, { id: 'desc' }],
      select: {
        id: true,
        number: true,
        customer_name: true,
        total: true,
        created_at: true,
      },
    });
  }

  /**
   * Faturamento de vendas ATIVAS por dia-calendário (servidor) no range, pela
   * data de criação. Alimenta a composição "faturamento = OS + venda". RLS.
   */
  revenueByDay(p: { from: Date; to: Date }) {
    const db = this.tenant.getClient();
    return db.$queryRaw<
      Array<{ day: string; revenue: number | null; count: bigint }>
    >(Prisma.sql`
      SELECT to_char(date_trunc('day', created_at), 'YYYY-MM-DD') AS day,
             SUM(total) AS revenue,
             COUNT(*)   AS count
      FROM sale
      WHERE status = 'active'
        AND created_at >= ${p.from} AND created_at <= ${p.to}
      GROUP BY 1
      ORDER BY 1
    `);
  }

  /** Faturamento (Σ total) e nº de vendas ATIVAS no range [from, to]. */
  revenueAgg(p: { from: Date; to: Date }) {
    const db = this.tenant.getClient();
    return db.sale.aggregate({
      where: {
        status: 'active',
        created_at: { gte: p.from, lte: p.to },
      },
      _sum: { total: true },
      _count: { _all: true },
    });
  }

  // ===================== Sync pull (offline) =====================
  /**
   * Página de mudanças de `sale`/`sale_item` desde o cursor. Sync pull — ver
   * `common/database/changed-since.ts`. A tabela vem de [SaleSyncEntity]
   * (whitelist fixa), nunca de string do request: `queryChangedSince` embute o
   * identificador via `Prisma.raw`, que não escapa.
   */
  listChangedSince(
    table: SaleSyncEntity,
    cursor: ChangeCursor | null,
    limit: number,
  ): Promise<ChangedSincePage> {
    const db = this.tenant.getClient();
    return queryChangedSince(db, table, SYNC_ENTITY_COLUMN[table], cursor, limit);
  }
}

const toNum = (d: Prisma.Decimal | number | null | undefined): number =>
  d == null ? 0 : typeof d === 'number' ? d : d.toNumber();
