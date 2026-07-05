import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { TenantContext } from '../../common/database/tenant-context';
import type { PaymentMethod, SaleStatus } from './dto/sale.dto';

export interface SaleLineData {
  inventory_item_id: string | null;
  kind: 'product' | 'service';
  name: string;
  quantity: number;
  unit_price: number;
  discount: number;
  total: number;
}

export interface CreateSaleData {
  number: string;
  customerId: string | null;
  customerName: string | null;
  paymentMethod: PaymentMethod;
  discount: number;
  subtotal: number;
  total: number;
  soldBy: string | null;
  lines: SaleLineData[];
}

/**
 * Único ponto que toca `sale` + `sale_item` (tenant-scoped, RLS+FORCE). Sempre
 * via `tenant.getClient()`; o service abre o `withTenantTx`. tenant_id vem do
 * CLS/JWT, nunca do cliente.
 */
@Injectable()
export class SalesRepository {
  constructor(private readonly tenant: TenantContext) {}

  /** Próximo número sequencial (VD-0001) por tenant. Colisão é barrada pelo
   * índice único (tenant_id, number). */
  async nextNumber(): Promise<string> {
    const db = this.tenant.getClient();
    const count = await db.sale.count();
    return `VD-${(count + 1).toString().padStart(4, '0')}`;
  }

  async createWithItems(tenantId: string, data: CreateSaleData) {
    const db = this.tenant.getClient();
    return db.sale.create({
      data: {
        tenant_id: tenantId,
        number: data.number,
        customer_id: data.customerId,
        customer_name: data.customerName,
        payment_method: data.paymentMethod,
        discount: new Prisma.Decimal(data.discount),
        subtotal: new Prisma.Decimal(data.subtotal),
        total: new Prisma.Decimal(data.total),
        sold_by: data.soldBy,
        items: {
          create: data.lines.map((l) => ({
            tenant_id: tenantId,
            inventory_item_id: l.inventory_item_id,
            kind: l.kind,
            name: l.name,
            quantity: new Prisma.Decimal(l.quantity),
            unit_price: new Prisma.Decimal(l.unit_price),
            discount: new Prisma.Decimal(l.discount),
            total: new Prisma.Decimal(l.total),
          })),
        },
      },
      include: { items: true },
    });
  }

  findByIdWithItems(id: string) {
    const db = this.tenant.getClient();
    return db.sale.findUnique({ where: { id }, include: { items: true } });
  }

  listItems(saleId: string) {
    const db = this.tenant.getClient();
    return db.sale_item.findMany({ where: { sale_id: saleId } });
  }

  updateSale(id: string, data: Prisma.saleUpdateInput) {
    const db = this.tenant.getClient();
    return db.sale.update({ where: { id }, data });
  }

  async listSales(p: {
    status?: SaleStatus;
    customerId?: string;
    skip: number;
    take: number;
  }) {
    const db = this.tenant.getClient();
    const where: Prisma.saleWhereInput = {
      ...(p.status ? { status: p.status } : {}),
      ...(p.customerId ? { customer_id: p.customerId } : {}),
    };
    return Promise.all([
      db.sale.findMany({
        where,
        orderBy: { created_at: 'desc' },
        skip: p.skip,
        take: p.take,
        include: { items: true },
      }),
      db.sale.count({ where }),
    ]);
  }
}
