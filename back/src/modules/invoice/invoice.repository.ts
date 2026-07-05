import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { TenantContext } from '../../common/database/tenant-context';
import type { InvoiceStatus } from './dto/invoice.dto';

export interface InvoiceLineData {
  kind: 'product' | 'service';
  name: string;
  quantity: number;
  unit_price: number;
  total: number;
}

export interface CreateInvoiceData {
  tenant_id: string;
  document_type: string;
  environment: string;
  order_id: string | null;
  sale_id: string | null;
  order_number: string | null;
  customer_id: string | null;
  customer_name: string | null;
  customer_document: string | null;
  service_amount: number;
  product_amount: number;
  total_amount: number;
  issued_by: string | null;
}

export interface InvoiceEventData {
  kind: string;
  message?: string | null;
  statusSnapshot?: string | null;
}

/**
 * Único ponto que toca `invoice`/`invoice_line`/`invoice_event` (tenant, RLS) e a
 * tabela global `invoice_webhook_event`. Tabelas de tenant via `tenant.getClient()`
 * (RLS aplicada); tabela global e a função SECURITY DEFINER via `PrismaService`.
 */
@Injectable()
export class InvoiceRepository {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tenant: TenantContext,
  ) {}

  // ---- tabelas de tenant (RLS) ----
  createWithLines(data: CreateInvoiceData, lines: InvoiceLineData[]) {
    const db = this.tenant.getClient();
    return db.invoice.create({
      data: {
        ...data,
        lines: {
          create: lines.map((l) => ({
            tenant_id: data.tenant_id,
            kind: l.kind,
            name: l.name,
            quantity: l.quantity,
            unit_price: l.unit_price,
            total: l.total,
          })),
        },
      },
    });
  }

  findById(id: string) {
    const db = this.tenant.getClient();
    return db.invoice.findUnique({ where: { id } });
  }

  findByIdWithLines(id: string) {
    const db = this.tenant.getClient();
    return db.invoice.findUnique({
      where: { id },
      include: { lines: { orderBy: { created_at: 'asc' } } },
    });
  }

  listLines(invoiceId: string) {
    const db = this.tenant.getClient();
    return db.invoice_line.findMany({
      where: { invoice_id: invoiceId },
      orderBy: { created_at: 'asc' },
    });
  }

  listEvents(invoiceId: string) {
    const db = this.tenant.getClient();
    return db.invoice_event.findMany({
      where: { invoice_id: invoiceId },
      orderBy: { created_at: 'desc' },
    });
  }

  countAuthorizedByOrder(orderId: string) {
    const db = this.tenant.getClient();
    return db.invoice.count({
      where: {
        order_id: orderId,
        status: { in: ['draft', 'processing', 'authorized'] },
      },
    });
  }

  /** Notas ativas (rascunho/processando/autorizada) de uma venda. */
  countAuthorizedBySale(saleId: string) {
    const db = this.tenant.getClient();
    return db.invoice.count({
      where: {
        sale_id: saleId,
        status: { in: ['draft', 'processing', 'authorized'] },
      },
    });
  }

  listInvoices(filters: {
    status?: InvoiceStatus;
    orderId?: string;
    saleId?: string;
    skip: number;
    take: number;
  }) {
    const db = this.tenant.getClient();
    const where: Prisma.invoiceWhereInput = {};
    if (filters.status) where.status = filters.status;
    if (filters.orderId) where.order_id = filters.orderId;
    if (filters.saleId) where.sale_id = filters.saleId;
    return Promise.all([
      db.invoice.findMany({
        where,
        orderBy: { created_at: 'desc' },
        skip: filters.skip,
        take: filters.take,
      }),
      db.invoice.count({ where }),
    ]);
  }

  updateInvoice(id: string, data: Prisma.invoiceUncheckedUpdateInput) {
    const db = this.tenant.getClient();
    return db.invoice.update({
      where: { id },
      data: { ...data, updated_at: new Date() },
    });
  }

  /** Cria um evento na timeline fiscal. Usa o client tx-scoped (mesma tx do chamador). */
  createEvent(tenantId: string, invoiceId: string, data: InvoiceEventData) {
    const db = this.tenant.getClient();
    return db.invoice_event.create({
      data: {
        tenant_id: tenantId,
        invoice_id: invoiceId,
        kind: data.kind,
        message: data.message ?? null,
        status_snapshot: data.statusSnapshot ?? null,
      },
    });
  }

  // ---- tabela global (sem RLS) — idempotência de webhook ----
  insertWebhookEvent(externalEventId: string, type: string, payload: Prisma.InputJsonValue) {
    return this.prisma.invoice_webhook_event.create({
      data: { external_event_id: externalEventId, type, payload },
    });
  }
  markWebhookProcessed(id: string) {
    return this.prisma.invoice_webhook_event.update({
      where: { id },
      data: { processed_at: new Date() },
    });
  }
  findWebhookEventByExternalId(externalEventId: string) {
    return this.prisma.invoice_webhook_event.findUnique({
      where: { external_event_id: externalEventId },
    });
  }

  // ---- resolver controlado SECURITY DEFINER (sem contexto de JWT) ----
  async resolveByExternalId(
    externalId: string,
  ): Promise<{ tenantId: string; invoiceId: string } | null> {
    const rows = await this.prisma.$queryRaw<
      Array<{ tenant_id: string; invoice_id: string }>
    >`SELECT tenant_id, invoice_id FROM invoice_resolve_by_external_id(${externalId})`;
    const row = rows[0];
    return row ? { tenantId: row.tenant_id, invoiceId: row.invoice_id } : null;
  }
}
