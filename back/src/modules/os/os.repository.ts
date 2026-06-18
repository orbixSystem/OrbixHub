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

export interface CreateTemplateItemData {
  kind: 'product' | 'service';
  inventory_item_id: string | null;
  name: string;
  quantity: DecimalIn;
  unit_price: DecimalIn | null;
}

export interface CreatePhotoData {
  order_id: string;
  storage_key: string;
  url: string;
  caption: string | null;
  uploaded_by: string | null;
}

export interface CreateEventData {
  kind: 'created' | 'status_change' | 'note' | 'photo';
  message?: string | null;
  statusSnapshot?: string | null;
  photoId?: string | null;
  visiblePublic: boolean;
  createdBy?: string | null;
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

  // ---- eventos (timeline) ----
  /** Cria um evento na timeline. Usa o cliente tx-scoped — roda na MESMA tx do chamador. */
  createEvent(tenantId: string, orderId: string, data: CreateEventData) {
    const db = this.tenant.getClient();
    return db.service_order_event.create({
      data: {
        tenant_id: tenantId,
        order_id: orderId,
        kind: data.kind,
        message: data.message ?? null,
        status_snapshot: data.statusSnapshot ?? null,
        photo_id: data.photoId ?? null,
        visible_public: data.visiblePublic,
        created_by: data.createdBy ?? null,
      } as Prisma.service_order_eventUncheckedCreateInput,
    });
  }

  /** Timeline da OS — mais recente no topo (created_at DESC). */
  listEvents(orderId: string) {
    const db = this.tenant.getClient();
    return db.service_order_event.findMany({
      where: { order_id: orderId },
      orderBy: { created_at: 'desc' },
    });
  }

  // ---- fotos ----
  /** Cria a linha da foto. Cliente tx-scoped — roda na MESMA tx do chamador. */
  addPhoto(tenantId: string, data: CreatePhotoData) {
    const db = this.tenant.getClient();
    return db.service_order_photo.create({
      data: {
        tenant_id: tenantId,
        ...data,
      } as Prisma.service_order_photoUncheckedCreateInput,
    });
  }

  findPhotoById(id: string) {
    const db = this.tenant.getClient();
    return db.service_order_photo.findUnique({ where: { id } });
  }

  /** Hard delete da linha (fotos não são registro histórico — o evento na timeline fica). */
  deletePhoto(id: string) {
    const db = this.tenant.getClient();
    return db.service_order_photo.delete({ where: { id } });
  }

  listPhotos(orderId: string) {
    const db = this.tenant.getClient();
    return db.service_order_photo.findMany({
      where: { order_id: orderId },
      orderBy: { created_at: 'desc' },
    });
  }

  // ---- templates de serviço ----
  createTemplate(
    tenantId: string,
    data: { name: string; description: string | null },
  ) {
    const db = this.tenant.getClient();
    return db.service_order_template.create({
      data: {
        tenant_id: tenantId,
        name: data.name,
        description: data.description,
      } as Prisma.service_order_templateUncheckedCreateInput,
    });
  }

  findTemplateById(id: string) {
    const db = this.tenant.getClient();
    return db.service_order_template.findUnique({
      where: { id },
      include: { items: { orderBy: { created_at: 'asc' } } },
    });
  }

  listTemplates() {
    const db = this.tenant.getClient();
    return db.service_order_template.findMany({
      where: { deleted_at: null },
      orderBy: { name: 'asc' },
      include: { items: { orderBy: { created_at: 'asc' } } },
    });
  }

  updateTemplate(
    id: string,
    data: { name?: string; description?: string | null },
  ) {
    const db = this.tenant.getClient();
    return db.service_order_template.update({
      where: { id },
      data: { ...data, updated_at: new Date() },
    });
  }

  softDeleteTemplate(id: string) {
    const db = this.tenant.getClient();
    return db.service_order_template.update({
      where: { id },
      data: { deleted_at: new Date(), updated_at: new Date() },
    });
  }

  addTemplateItem(
    tenantId: string,
    templateId: string,
    data: CreateTemplateItemData,
  ) {
    const db = this.tenant.getClient();
    return db.service_order_template_item.create({
      data: {
        tenant_id: tenantId,
        template_id: templateId,
        ...data,
      } as Prisma.service_order_template_itemUncheckedCreateInput,
    });
  }

  /** Apaga todos os itens do template (usado no replace ao atualizar). */
  deleteTemplateItems(templateId: string) {
    const db = this.tenant.getClient();
    return db.service_order_template_item.deleteMany({
      where: { template_id: templateId },
    });
  }

  listTemplateItems(templateId: string) {
    const db = this.tenant.getClient();
    return db.service_order_template_item.findMany({
      where: { template_id: templateId },
      orderBy: { created_at: 'asc' },
    });
  }

  // ---- histórico (SubjectHistoryProvider) ----
  /** OS de um subject (veículo), exclui deletadas. Mais recente no topo. */
  listOrdersBySubject(subjectId: string) {
    const db = this.tenant.getClient();
    return db.service_order.findMany({
      where: { subject_id: subjectId, deleted_at: null },
      orderBy: { created_at: 'desc' },
    });
  }

  /** OS de um cliente, exclui deletadas. Mais recente no topo. */
  listOrdersByCustomer(customerId: string) {
    const db = this.tenant.getClient();
    return db.service_order.findMany({
      where: { customer_id: customerId, deleted_at: null },
      orderBy: { created_at: 'desc' },
    });
  }
}
