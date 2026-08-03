import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { TenantContext } from '../../common/database/tenant-context';

type DecimalIn = Prisma.Decimal | number;

export interface CreateSaleData {
  number: string;
  customer_id: string | null;
  customer_name: string | null;
  status: string;
  total: DecimalIn;
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
}

const toNum = (d: Prisma.Decimal | number | null | undefined): number =>
  d == null ? 0 : typeof d === 'number' ? d : d.toNumber();
