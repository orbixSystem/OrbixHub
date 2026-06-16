import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { TenantContext } from '../../common/database/tenant-context';

export interface ItemFilter {
  q?: string;
  kind?: 'product' | 'service';
  category?: string;
  status: 'active' | 'archived' | 'all';
  lowStock?: boolean;
  skip: number;
  take: number;
}

export interface ItemData {
  kind?: string;
  name?: string;
  code?: string | null;
  barcode?: string | null;
  category?: string | null;
  unit?: string;
  sale_price_cents?: number;
  cost_price_cents?: number | null;
  margin_percent?: Prisma.Decimal | number | null;
  sellable?: boolean;
  track_stock?: boolean;
  min_qty?: Prisma.Decimal | number | null;
  duration_minutes?: number | null;
  brand?: string | null;
}

/**
 * Único ponto que toca `inventory_item`/`inventory_movement`. Sempre via
 * `tenant.getClient()` (tx-scoped sob RLS); o service abre o `withTenantTx`.
 */
@Injectable()
export class InventoryRepository {
  constructor(private readonly tenant: TenantContext) {}

  private statusWhere(status: 'active' | 'archived' | 'all') {
    if (status === 'all') return {};
    return { status };
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

  async listItems(filter: ItemFilter) {
    const db = this.tenant.getClient();
    const where: Prisma.inventory_itemWhereInput = {
      ...this.statusWhere(filter.status),
      ...(filter.kind ? { kind: filter.kind } : {}),
      ...(filter.category ? { category: { equals: filter.category, mode: 'insensitive' } } : {}),
      ...(filter.lowStock
        ? { track_stock: true, min_qty: { not: null }, stock_qty: { lte: db.inventory_item.fields.min_qty } }
        : {}),
      ...(filter.q
        ? {
            OR: [
              { name: { contains: filter.q, mode: 'insensitive' } },
              { code: { contains: filter.q, mode: 'insensitive' } },
              { barcode: { contains: filter.q, mode: 'insensitive' } },
            ],
          }
        : {}),
    };
    const [items, total] = await Promise.all([
      db.inventory_item.findMany({ where, orderBy: { name: 'asc' }, skip: filter.skip, take: filter.take }),
      db.inventory_item.count({ where }),
    ]);
    return { items, total };
  }

  updateItem(id: string, data: ItemData) {
    const db = this.tenant.getClient();
    return db.inventory_item.update({
      where: { id },
      data: { ...data, updated_at: new Date() } as Prisma.inventory_itemUncheckedUpdateInput,
    });
  }

  setItemStatus(id: string, status: 'active' | 'archived') {
    const db = this.tenant.getClient();
    return db.inventory_item.update({ where: { id }, data: { status, updated_at: new Date() } });
  }

  /** Cria o movimento E atualiza o saldo cacheado do item — mesma tx. */
  async createMovement(
    tenantId: string,
    itemId: string,
    data: {
      type: string;
      quantity: number;
      balance_after: number;
      reason: string | null;
      ref_type: string | null;
      ref_id: string | null;
      note: string | null;
      created_by: string | null;
    },
  ) {
    const db = this.tenant.getClient();
    const movement = await db.inventory_movement.create({
      data: { tenant_id: tenantId, item_id: itemId, ...data },
    });
    await db.inventory_item.update({
      where: { id: itemId },
      data: { stock_qty: data.balance_after, updated_at: new Date() },
    });
    return movement;
  }

  listMovements(itemId: string, take = 100) {
    const db = this.tenant.getClient();
    return db.inventory_movement.findMany({
      where: { item_id: itemId },
      orderBy: { created_at: 'desc' },
      take,
    });
  }

  searchForPicker(q: string | undefined, kind: 'product' | 'service' | undefined, take = 20) {
    const db = this.tenant.getClient();
    return db.inventory_item.findMany({
      where: {
        status: 'active',
        ...(kind ? { kind } : {}),
        ...(q ? { OR: [{ name: { contains: q, mode: 'insensitive' } }, { code: { contains: q, mode: 'insensitive' } }] } : {}),
      },
      orderBy: { name: 'asc' },
      take,
    });
  }
}
