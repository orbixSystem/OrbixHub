import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { TenantContext } from '../../common/database/tenant-context';

export interface ItemFilter {
  q?: string;
  kind?: 'product' | 'service';
  category?: string;
  /** Filtro por estado: 'active' (padrão), 'archived', ou 'all'. */
  active: 'active' | 'archived' | 'all';
  lowStock?: boolean;
  skip: number;
  take: number;
}

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
        orderBy: { name: 'asc' },
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
}
