import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { TenantContext } from '../../common/database/tenant-context';

type DecimalIn = Prisma.Decimal | number;

export interface OrderListFilter {
  q?: string;
  status?: string;
  customerId?: string;
  skip: number;
  take: number;
}

export interface CreateOrderData {
  number: string;
  customer_id: string;
  customer_name: string;
  subject_id: string | null;
  subject_label: string | null;
  status: string;
  opened_by: string | null;
  assigned_to: string | null;
  complaint: string | null;
  diagnosis: string | null;
  scheduled_start: Date | null;
  scheduled_end: Date | null;
}

export interface UpdateOrderData {
  complaint?: string | null;
  diagnosis?: string | null;
  scheduled_start?: Date | null;
  scheduled_end?: Date | null;
  assigned_to?: string | null;
  discount?: DecimalIn;
}

export interface StatusFields {
  status?: string;
  started_at?: Date | null;
  finished_at?: Date | null;
  closed_at?: Date | null;
  stock_applied?: boolean;
}

export interface CreateItemData {
  order_id: string;
  kind: 'product' | 'service';
  inventory_item_id: string | null;
  name: string;
  quantity: DecimalIn;
  unit_price: DecimalIn;
  discount: DecimalIn;
  total: DecimalIn;
}

export interface UpdateItemData {
  name?: string;
  quantity?: DecimalIn;
  unit_price?: DecimalIn;
  discount?: DecimalIn;
  total?: DecimalIn;
}

/**
 * Único ponto que toca `service_order`/`service_order_item`. Sempre via
 * `tenant.getClient()` (cliente tx-scoped sob RLS); o service abre o
 * `withTenantTx`. Nunca recebe tenant_id do cliente — vem do CLS/JWT.
 */
@Injectable()
export class OsRepository {
  constructor(private readonly tenant: TenantContext) {}

  createOrder(tenantId: string, data: CreateOrderData) {
    const db = this.tenant.getClient();
    return db.service_order.create({
      data: {
        tenant_id: tenantId,
        ...data,
      } as Prisma.service_orderUncheckedCreateInput,
    });
  }

  findOrderById(id: string) {
    const db = this.tenant.getClient();
    return db.service_order.findUnique({
      where: { id },
      include: { items: { orderBy: { created_at: 'asc' } } },
    });
  }

  async listOrders(filter: OrderListFilter) {
    const db = this.tenant.getClient();
    const where: Prisma.service_orderWhereInput = {
      deleted_at: null,
      ...(filter.status ? { status: filter.status } : {}),
      ...(filter.customerId ? { customer_id: filter.customerId } : {}),
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
      db.service_order.findMany({
        where,
        orderBy: { created_at: 'desc' },
        skip: filter.skip,
        take: filter.take,
      }),
      db.service_order.count({ where }),
    ]);
    return { items, total };
  }

  /** Maior sufixo numérico de `number` (OS-NNNN) do tenant; 0 se nenhum. Tenant-scoped por RLS. */
  async maxOrderNumber(): Promise<number> {
    const db = this.tenant.getClient();
    const rows = await db.$queryRaw<Array<{ max: number | null }>>`
      SELECT MAX(NULLIF(regexp_replace(number, '[^0-9]', '', 'g'), '')::int) AS max
      FROM service_order
    `;
    return rows[0]?.max ?? 0;
  }

  updateOrder(id: string, data: UpdateOrderData) {
    const db = this.tenant.getClient();
    return db.service_order.update({
      where: { id },
      data: { ...data, updated_at: new Date() },
    });
  }

  setStatusFields(id: string, fields: StatusFields) {
    const db = this.tenant.getClient();
    return db.service_order.update({
      where: { id },
      data: { ...fields, updated_at: new Date() },
    });
  }

  softDelete(id: string) {
    const db = this.tenant.getClient();
    return db.service_order.update({
      where: { id },
      data: { deleted_at: new Date(), updated_at: new Date() },
    });
  }

  setTotal(id: string, total: DecimalIn) {
    const db = this.tenant.getClient();
    return db.service_order.update({
      where: { id },
      data: { total, updated_at: new Date() },
    });
  }

  // ---- itens ----
  addItem(tenantId: string, data: CreateItemData) {
    const db = this.tenant.getClient();
    return db.service_order_item.create({
      data: {
        tenant_id: tenantId,
        ...data,
      } as Prisma.service_order_itemUncheckedCreateInput,
    });
  }

  findItemById(itemId: string) {
    const db = this.tenant.getClient();
    return db.service_order_item.findUnique({ where: { id: itemId } });
  }

  updateItem(itemId: string, data: UpdateItemData) {
    const db = this.tenant.getClient();
    return db.service_order_item.update({ where: { id: itemId }, data });
  }

  deleteItem(itemId: string) {
    const db = this.tenant.getClient();
    return db.service_order_item.delete({ where: { id: itemId } });
  }

  listItems(orderId: string) {
    const db = this.tenant.getClient();
    return db.service_order_item.findMany({
      where: { order_id: orderId },
      orderBy: { created_at: 'asc' },
    });
  }
}
