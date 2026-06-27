import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { TenantContext } from '../../common/database/tenant-context';

/** Chaves de ordenação aceitas pela lista de itens. */
export type ItemSort =
  | 'name_asc'
  | 'name_desc'
  | 'price_desc'
  | 'price_asc'
  | 'stock_desc'
  | 'stock_asc'
  | 'recent';

export interface ItemFilter {
  q?: string;
  kind?: 'product' | 'service';
  category?: string;
  /** Filtro por estado: 'active' (padrão), 'archived', ou 'all'. */
  active: 'active' | 'archived' | 'all';
  lowStock?: boolean;
  /** Ordenação (default 'name_asc'). */
  sort?: ItemSort;
  skip: number;
  take: number;
}

/**
 * Mapa de ordenação → `orderBy` do Prisma. Sempre com `id` como desempate final
 * para que a paginação por skip/take seja ESTÁVEL (sem itens repetidos/pulados
 * quando há empates na chave primária, ex.: vários preços nulos/iguais).
 * Preço pode ser nulo → `nulls: 'last'` mantém itens sem preço no fim.
 */
const ITEM_ORDER_BY: Record<
  ItemSort,
  Prisma.inventory_itemOrderByWithRelationInput[]
> = {
  name_asc: [{ name: 'asc' }, { id: 'asc' }],
  name_desc: [{ name: 'desc' }, { id: 'asc' }],
  price_desc: [{ sale_price: { sort: 'desc', nulls: 'last' } }, { id: 'asc' }],
  price_asc: [{ sale_price: { sort: 'asc', nulls: 'last' } }, { id: 'asc' }],
  stock_desc: [{ current_stock: 'desc' }, { id: 'asc' }],
  stock_asc: [{ current_stock: 'asc' }, { id: 'asc' }],
  recent: [{ created_at: 'desc' }, { id: 'asc' }],
};

type DecimalIn = Prisma.Decimal | number;

export interface ItemData {
  name?: string;
  kind?: 'product' | 'service';
  duration_minutes?: number | null;
  sku?: string | null;
  manufacturer_code?: string | null;
  barcode?: string | null;
  category?: string | null;
  brand?: string | null;
  unit?: string | null;
  sale_price?: DecimalIn | null;
  cost_price?: DecimalIn | null;
  margin_pct?: DecimalIn | null;
  current_stock?: DecimalIn;
  min_stock?: DecimalIn | null;
  attributes?: Prisma.InputJsonValue;
}

/**
 * Único ponto que toca `inventory_item`. Sempre via `tenant.getClient()`
 * (cliente tx-scoped sob RLS); o service abre o `withTenantTx`/`runWithTenant`.
 * Nunca recebe tenant_id do cliente — vem do CLS/JWT.
 */
@Injectable()
export class InventoryRepository {
  constructor(private readonly tenant: TenantContext) {}

  private activeWhere(active: 'active' | 'archived' | 'all') {
    if (active === 'all') return {};
    return { is_active: active === 'active' };
  }

  createItem(tenantId: string, data: ItemData) {
    const db = this.tenant.getClient();
    return db.inventory_item.create({
      data: { tenant_id: tenantId, ...data } as Prisma.inventory_itemUncheckedCreateInput,
    });
  }

  findItemById(id: string) {
    const db = this.tenant.getClient();
    return db.inventory_item.findUnique({ where: { id } });
  }

  /** Itens vivos (não deletados) por id — para resolver preço corrente em lote. */
  findItemsByIds(ids: string[]) {
    const db = this.tenant.getClient();
    return db.inventory_item.findMany({
      where: { id: { in: ids }, deleted_at: null },
    });
  }

  async listItems(filter: ItemFilter) {
    const db = this.tenant.getClient();
    const where: Prisma.inventory_itemWhereInput = {
      deleted_at: null,
      ...this.activeWhere(filter.active),
      ...(filter.kind ? { kind: filter.kind } : {}),
      ...(filter.category
        ? { category: { equals: filter.category, mode: 'insensitive' } }
        : {}),
      ...(filter.lowStock
        ? {
            min_stock: { not: null },
            current_stock: { lte: db.inventory_item.fields.min_stock },
          }
        : {}),
      ...(filter.q
        ? {
            OR: [
              { name: { contains: filter.q, mode: 'insensitive' } },
              { sku: { contains: filter.q, mode: 'insensitive' } },
              { barcode: { contains: filter.q, mode: 'insensitive' } },
              { manufacturer_code: { contains: filter.q, mode: 'insensitive' } },
            ],
          }
        : {}),
    };
    const [items, total] = await Promise.all([
      db.inventory_item.findMany({
        where,
        orderBy: ITEM_ORDER_BY[filter.sort ?? 'name_asc'],
        skip: filter.skip,
        take: filter.take,
      }),
      db.inventory_item.count({ where }),
    ]);
    return { items, total };
  }

  /** Primeiro item NÃO excluído cujo barcode|manufacturer_code|sku == code (ativo ou não). */
  findByCode(code: string) {
    const db = this.tenant.getClient();
    return db.inventory_item.findFirst({
      where: {
        deleted_at: null,
        OR: [{ barcode: code }, { manufacturer_code: code }, { sku: code }],
      },
    });
  }

  /** Existe item NÃO excluído (ativo ou não) com este SKU exato? Tenant-scoped por RLS. */
  async skuExists(sku: string): Promise<boolean> {
    const db = this.tenant.getClient();
    return (await db.inventory_item.count({ where: { sku, deleted_at: null } })) > 0;
  }

  updateItem(id: string, data: ItemData) {
    const db = this.tenant.getClient();
    return db.inventory_item.update({
      where: { id },
      data: { ...data, updated_at: new Date() } as Prisma.inventory_itemUncheckedUpdateInput,
    });
  }

  setActive(id: string, isActive: boolean) {
    const db = this.tenant.getClient();
    return db.inventory_item.update({
      where: { id },
      data: { is_active: isActive, updated_at: new Date() },
    });
  }

  softDelete(id: string) {
    const db = this.tenant.getClient();
    return db.inventory_item.update({
      where: { id },
      data: { deleted_at: new Date(), updated_at: new Date() },
    });
  }

  adjustStock(id: string, newStock: DecimalIn) {
    const db = this.tenant.getClient();
    return db.inventory_item.update({
      where: { id },
      data: { current_stock: newStock, updated_at: new Date() },
    });
  }

  // ---- diário de estoque (stock_movement) ----
  createStockMovement(
    tenantId: string,
    data: {
      inventory_item_id: string;
      stock_delta: Prisma.Decimal | number;
      reason: 'os_consumption' | 'os_reversal';
      ref_type: string;
      ref_id: string;
      ref_item_id: string | null;
      created_by: string | null;
    },
  ) {
    const db = this.tenant.getClient();
    return db.stock_movement.create({
      data: {
        tenant_id: tenantId,
        ...data,
      } as Prisma.stock_movementUncheckedCreateInput,
    });
  }

  /**
   * Consumo já registrado para uma linha de origem (ex.: item de OS):
   * -Σ(stock_delta) dos movimentos dessa linha. Consumo reduz o saldo
   * (stock_delta negativo), então a soma negada dá o consumido positivo.
   * Tenant-scoped por RLS.
   */
  async sumConsumedByRefItem(refItemId: string): Promise<number> {
    const db = this.tenant.getClient();
    const agg = await db.stock_movement.aggregate({
      where: { ref_item_id: refItemId },
      _sum: { stock_delta: true },
    });
    const sum = agg._sum.stock_delta;
    return sum == null ? 0 : -(typeof sum === 'number' ? sum : sum.toNumber());
  }

  // ---- métricas (agregações sob RLS — sem WHERE tenant manual) ----
  /** Itens vivos abaixo do mínimo (current_stock < min_stock, min definido). */
  private belowMinWhere(): Prisma.inventory_itemWhereInput {
    const db = this.tenant.getClient();
    return {
      deleted_at: null,
      is_active: true,
      kind: 'product',
      min_stock: { not: null },
      current_stock: { lt: db.inventory_item.fields.min_stock },
    };
  }

  countBelowMin() {
    const db = this.tenant.getClient();
    return db.inventory_item.count({ where: this.belowMinWhere() });
  }

  /** Amostra de itens abaixo do mínimo (para a lista curta do dashboard). */
  sampleBelowMin(take: number) {
    const db = this.tenant.getClient();
    return db.inventory_item.findMany({
      where: this.belowMinWhere(),
      orderBy: [{ current_stock: 'asc' }, { id: 'asc' }],
      take,
      select: {
        id: true,
        name: true,
        sku: true,
        current_stock: true,
        min_stock: true,
      },
    });
  }

  /** Contagem de itens ativos por tipo (product|service). */
  countActive(kind: 'product' | 'service') {
    const db = this.tenant.getClient();
    return db.inventory_item.count({
      where: { deleted_at: null, is_active: true, kind },
    });
  }

  /**
   * Valor em estoque (Σ current_stock × cost_price). Prisma não soma produto de
   * colunas — query agregada crua, tenant-scoped por RLS.
   */
  async stockValue(): Promise<number> {
    const db = this.tenant.getClient();
    const rows = await db.$queryRaw<Array<{ value: number | null }>>(Prisma.sql`
      SELECT COALESCE(SUM(current_stock * COALESCE(cost_price, 0)), 0) AS value
      FROM inventory_item
      WHERE deleted_at IS NULL AND is_active = true AND kind = 'product'
    `);
    return Number(rows[0]?.value ?? 0);
  }

  /** Colunas do relatório de posição (compartilhadas por listForReport/Page). */
  private static readonly REPORT_SELECT = {
    id: true,
    name: true,
    sku: true,
    current_stock: true,
    min_stock: true,
    cost_price: true,
    sale_price: true,
  } as const;

  /** WHERE do relatório de posição: produtos ativos vivos (+ busca opcional). */
  private reportWhere(q?: string): Prisma.inventory_itemWhereInput {
    return {
      deleted_at: null,
      is_active: true,
      kind: 'product',
      ...(q
        ? {
            OR: [
              { name: { contains: q, mode: 'insensitive' } },
              { sku: { contains: q, mode: 'insensitive' } },
            ],
          }
        : {}),
    };
  }

  /** Linhas do relatório de posição (export): TODOS os produtos ativos. */
  listForReport(q?: string) {
    const db = this.tenant.getClient();
    return db.inventory_item.findMany({
      where: this.reportWhere(q),
      orderBy: [{ name: 'asc' }, { id: 'asc' }],
      select: InventoryRepository.REPORT_SELECT,
    });
  }

  /** Uma página do relatório de posição (tela) + total p/ o paginador. */
  async listForReportPage(p: { skip: number; take: number; q?: string }) {
    const db = this.tenant.getClient();
    const where = this.reportWhere(p.q);
    const [items, total] = await Promise.all([
      db.inventory_item.findMany({
        where,
        orderBy: [{ name: 'asc' }, { id: 'asc' }],
        skip: p.skip,
        take: p.take,
        select: InventoryRepository.REPORT_SELECT,
      }),
      db.inventory_item.count({ where }),
    ]);
    return { items, total };
  }
}
