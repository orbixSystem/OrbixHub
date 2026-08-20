import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { TenantContext } from '../../common/database/tenant-context';
import {
  ChangeCursor,
  ChangedSincePage,
  queryChangedSince,
} from '../../common/database/changed-since';

type DecimalIn = Prisma.Decimal | number;

/** Entidades do módulo os expostas ao pull de sync offline. */
export type OsSyncEntity =
  | 'service_order'
  | 'service_order_item'
  | 'service_order_event'
  | 'service_order_photo'
  | 'service_order_template';

/**
 * `service_order_event`/`service_order_photo` são append-only → cursor por
 * `created_at`; o resto (tem trigger de `updated_at` — migration 0031) usa
 * `updated_at`.
 */
const SYNC_ENTITY_COLUMN: Record<OsSyncEntity, 'updated_at' | 'created_at'> = {
  service_order: 'updated_at',
  service_order_item: 'updated_at',
  service_order_event: 'created_at',
  service_order_photo: 'created_at',
  service_order_template: 'updated_at',
};

/**
 * Ordenação da lista de OS (`created_at`). Cada chave tem um desempate estável
 * por `id` para paginação consistente. `recent` é o default.
 */
const OS_ORDER_BY: Record<
  string,
  Prisma.service_orderOrderByWithRelationInput[]
> = {
  recent: [{ created_at: 'desc' }, { id: 'desc' }],
  oldest: [{ created_at: 'asc' }, { id: 'asc' }],
  number_asc: [{ number: 'asc' }, { id: 'asc' }],
  number_desc: [{ number: 'desc' }, { id: 'desc' }],
  customer_asc: [{ customer_name: 'asc' }, { id: 'asc' }],
  customer_desc: [{ customer_name: 'desc' }, { id: 'desc' }],
  total_desc: [{ total: 'desc' }, { id: 'desc' }],
  total_asc: [{ total: 'asc' }, { id: 'asc' }],
  status: [{ status: 'asc' }, { id: 'asc' }],
};

/**
 * Mesma ordenação, mas as variantes de data usam `opened_at` (a data exibida no
 * relatório de OS é a de abertura), com desempate estável por `id`.
 */
const OS_REPORT_ORDER_BY: Record<
  string,
  Prisma.service_orderOrderByWithRelationInput[]
> = {
  ...OS_ORDER_BY,
  recent: [{ opened_at: 'desc' }, { id: 'desc' }],
  oldest: [{ opened_at: 'asc' }, { id: 'asc' }],
};

export interface OrderListFilter {
  q?: string;
  status?: string;
  /** Filtro por VÁRIOS status reais (ex.: o grupo "em andamento" do front
   * simplificado) — quando presente, prevalece sobre `status`. */
  statuses?: string[];
  customerId?: string;
  sort?: string;
  skip: number;
  take: number;
}

export interface TemplateListFilter {
  q?: string;
  skip: number;
  take: number;
}

export interface CreateOrderData {
  /** Uuid vindo do cliente (replay offline) — opcional; INSERT puro (S9: sem upsert). */
  id?: string;
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
  /** Desconto do cabeçalho informado já na abertura (default 0 no banco). */
  discount?: DecimalIn;
}

export interface UpdateOrderData {
  complaint?: string | null;
  diagnosis?: string | null;
  scheduled_start?: Date | null;
  scheduled_end?: Date | null;
  assigned_to?: string | null;
  discount?: DecimalIn;
}

export interface FiscalSnapshotFields {
  fiscal_status: string | null;
  fiscal_external_id: string | null;
  fiscal_emitted_at: Date | null;
}

export interface StatusFields {
  status?: string;
  started_at?: Date | null;
  finished_at?: Date | null;
  closed_at?: Date | null;
  stock_applied?: boolean;
}

export interface CreateItemData {
  /** Uuid vindo do cliente (replay offline) — opcional; INSERT puro (S9: sem upsert). */
  id?: string;
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

export interface UpdateItemScheduleData {
  assigned_to?: string | null;
  scheduled_start?: Date | null;
  estimated_duration?: number | null;
  scheduled_end?: Date | null;
}

export interface AgendaFilter {
  from: Date;
  to: Date;
  assignedTo?: string;
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
      ...(filter.statuses?.length
        ? { status: { in: filter.statuses } }
        : filter.status
          ? { status: filter.status }
          : {}),
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
        orderBy: OS_ORDER_BY[filter.sort ?? 'recent'] ?? OS_ORDER_BY.recent,
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

  /**
   * Marca a OS como fiado declarado.
   *
   * `updated_at` é tocado de propósito: o pull de sync avança pelo cursor
   * (`updated_at`, id) — ver `changed-since.ts`. Gravar só `fiado_at` deixaria a
   * declaração invisível para os outros aparelhos do tenant, que continuariam
   * mostrando o título fora do Fiado até algum outro campo mudar.
   */
  setFiadoAt(id: string, at: Date) {
    const db = this.tenant.getClient();
    return db.service_order.update({
      where: { id },
      data: { fiado_at: at, updated_at: new Date() },
    });
  }

  /** Snapshot do status fiscal devolvido pelo Fiscal (só p/ exibir; Fiscal é dono). */
  setFiscalSnapshot(id: string, fields: FiscalSnapshotFields) {
    const db = this.tenant.getClient();
    return db.service_order.update({
      where: { id },
      data: { ...fields, updated_at: new Date() },
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

  updateItemSchedule(itemId: string, data: UpdateItemScheduleData) {
    const db = this.tenant.getClient();
    return db.service_order_item.update({ where: { id: itemId }, data });
  }

  /** Verifica sobreposição de agenda para um técnico (conflito de horário). */
  async findConflicts(
    assignedTo: string,
    start: Date,
    end: Date,
    excludeItemId?: string,
  ) {
    const db = this.tenant.getClient();
    return db.service_order_item.findMany({
      where: {
        assigned_to: assignedTo,
        id: excludeItemId ? { not: excludeItemId } : undefined,
        scheduled_start: { not: null, lt: end },
        scheduled_end: { not: null, gt: start },
      },
      select: { id: true, name: true, order_id: true, scheduled_start: true, scheduled_end: true },
    });
  }

  /**
   * OSes cuja janela de serviço CRUZA o período — alimenta a agenda.
   *
   * A regra é de SOBREPOSIÇÃO, não de início dentro do período. Antes o filtro
   * era `scheduled_start` dentro do range: um carro que entra dia 10 e sai dia
   * 15 aparecia só no dia 10 e sumia da agenda nos outros cinco — justamente
   * os dias em que ele está na oficina.
   *
   * E `scheduled_end` não é mais obrigatório. Ele é opcional no cadastro da OS
   * (as duas datas são), então exigir fim não-nulo escondia da agenda toda OS
   * com só a data de entrada — o caso mais comum de quem preenche rápido. Sem
   * fim, a OS é tratada como um PONTO no tempo (aparece no dia do início).
   */
  async getScheduledOrders(filter: AgendaFilter) {
    const db = this.tenant.getClient();
    return db.service_order.findMany({
      where: {
        // Começou antes do fim do período…
        scheduled_start: { not: null, lt: filter.to },
        // …e ainda não tinha terminado quando o período começou.
        OR: [
          { scheduled_end: { gte: filter.from } },
          { scheduled_end: null, scheduled_start: { gte: filter.from } },
        ],
        ...(filter.assignedTo ? { assigned_to: filter.assignedTo } : {}),
      },
      select: {
        id: true,
        number: true,
        status: true,
        customer_name: true,
        subject_label: true,
        assigned_to: true,
        scheduled_start: true,
        scheduled_end: true,
        complaint: true,
      },
      orderBy: { scheduled_start: 'asc' },
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

  /** Fotos da OS + nº de comentários por foto (badge nas miniaturas do front). */
  async listPhotos(orderId: string) {
    const db = this.tenant.getClient();
    const photos = await db.service_order_photo.findMany({
      where: { order_id: orderId },
      orderBy: { created_at: 'desc' },
    });
    if (photos.length === 0) return [];
    const byPhoto = await this.commentCountsByIds(photos.map((p) => p.id));
    return photos.map((p) => ({
      ...p,
      comment_count: byPhoto.get(p.id) ?? 0,
    }));
  }

  /** Nº de comentários por foto, em lote (sem relação no schema — FK vive no banco). */
  async commentCountsByIds(photoIds: string[]): Promise<Map<string, number>> {
    if (photoIds.length === 0) return new Map();
    const db = this.tenant.getClient();
    const counts = await db.service_order_photo_comment.groupBy({
      by: ['photo_id'],
      where: { photo_id: { in: photoIds } },
      _count: { _all: true },
    });
    return new Map(counts.map((c) => [c.photo_id, c._count._all]));
  }

  // ---- comentários das fotos (thread staff + cliente) ----

  listPhotoComments(photoId: string) {
    const db = this.tenant.getClient();
    return db.service_order_photo_comment.findMany({
      where: { photo_id: photoId },
      orderBy: { created_at: 'asc' },
    });
  }

  addPhotoComment(
    tenantId: string,
    data: {
      photoId: string;
      authorKind: 'staff' | 'customer';
      authorUserId?: string | null;
      authorName?: string | null;
      body: string;
    },
  ) {
    const db = this.tenant.getClient();
    return db.service_order_photo_comment.create({
      data: {
        tenant_id: tenantId,
        photo_id: data.photoId,
        author_kind: data.authorKind,
        author_user_id: data.authorUserId ?? null,
        author_name: data.authorName ?? null,
        body: data.body,
      },
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

  async listTemplates(filter: TemplateListFilter) {
    const db = this.tenant.getClient();
    const where: Prisma.service_order_templateWhereInput = {
      deleted_at: null,
      ...(filter.q
        ? {
            OR: [
              { name: { contains: filter.q, mode: 'insensitive' } },
              { description: { contains: filter.q, mode: 'insensitive' } },
            ],
          }
        : {}),
    };
    const [items, total] = await Promise.all([
      db.service_order_template.findMany({
        where,
        orderBy: [{ name: 'asc' }, { id: 'asc' }],
        include: { items: { orderBy: { created_at: 'asc' } } },
        skip: filter.skip,
        take: filter.take,
      }),
      db.service_order_template.count({ where }),
    ]);
    return { items, total };
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

  /** Itens de VÁRIOS templates em 1 query (sync pull — evita N+1 por página). */
  listTemplateItemsByTemplateIds(templateIds: string[]) {
    const db = this.tenant.getClient();
    return db.service_order_template_item.findMany({
      where: { template_id: { in: templateIds } },
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

  // ---- métricas (agregações sob RLS — sem WHERE tenant manual) ----
  /**
   * Filtro-base das agregações: OS vivas (deleted_at NULL) abertas no range
   * [from, to] (por `opened_at`), opcionalmente escopadas a um técnico.
   */
  private metricsWhere(p: MetricsRange): Prisma.service_orderWhereInput {
    return {
      deleted_at: null,
      opened_at: { gte: p.from, lte: p.to },
      ...(p.assignedTo ? { assigned_to: p.assignedTo } : {}),
    };
  }

  /** COUNT(*) por status no range. */
  groupByStatus(p: MetricsRange) {
    const db = this.tenant.getClient();
    return db.service_order.groupBy({
      by: ['status'],
      where: this.metricsWhere(p),
      _count: { _all: true },
    });
  }

  /**
   * Faturamento (Σ total) e nº de OS concluída+entregue no range. Restringe ao
   * mesmo range/escopo das demais agregações (por `opened_at`).
   */
  revenueAgg(p: MetricsRange) {
    const db = this.tenant.getClient();
    return db.service_order.aggregate({
      where: {
        ...this.metricsWhere(p),
        status: { in: ['concluida', 'entregue'] },
      },
      _sum: { total: true },
      _count: { _all: true },
    });
  }

  /** OS em execução no range/escopo. */
  countInExecution(p: MetricsRange) {
    const db = this.tenant.getClient();
    return db.service_order.count({
      where: { ...this.metricsWhere(p), status: 'em_execucao' },
    });
  }

  /**
   * OS atrasadas: `scheduled_end` < agora e status fora de
   * concluida/entregue/cancelada. Independe do range (atraso é "estado agora"),
   * mas respeita o escopo de técnico.
   */
  countOverdue(p: MetricsRange) {
    const db = this.tenant.getClient();
    return db.service_order.count({
      where: {
        deleted_at: null,
        scheduled_end: { lt: new Date() },
        status: { notIn: ['concluida', 'entregue', 'cancelada'] },
        ...(p.assignedTo ? { assigned_to: p.assignedTo } : {}),
      },
    });
  }

  /**
   * Tempo médio de ciclo (finished_at - started_at) em ms, sobre OS concluídas no
   * range com ambos os timestamps. Tenant-scoped por RLS (sem WHERE tenant).
   */
  async avgCycleMs(p: MetricsRange): Promise<number | null> {
    const db = this.tenant.getClient();
    const assignedClause = p.assignedTo
      ? Prisma.sql`AND assigned_to = ${p.assignedTo}::uuid`
      : Prisma.sql``;
    const rows = await db.$queryRaw<Array<{ avg_ms: number | null }>>(Prisma.sql`
      SELECT AVG(EXTRACT(EPOCH FROM (finished_at - started_at)) * 1000) AS avg_ms
      FROM service_order
      WHERE deleted_at IS NULL
        AND opened_at >= ${p.from} AND opened_at <= ${p.to}
        AND status IN ('concluida','entregue')
        AND started_at IS NOT NULL AND finished_at IS NOT NULL
        ${assignedClause}
    `);
    const v = rows[0]?.avg_ms;
    return v == null ? null : Number(v);
  }

  // ---- Fase 2: lentes de faturamento / equipe / top-itens (sob RLS) ----
  /**
   * Faturamento por dia-calendário (servidor) das OS concluídas/entregues no
   * range, agrupado pela DATA DE CONCLUSÃO (COALESCE(finished_at, closed_at)).
   * Retorna também a contagem por dia. Tenant-scoped por RLS.
   */
  revenueByDay(p: MetricsRange) {
    const db = this.tenant.getClient();
    return db.$queryRaw<
      Array<{ day: string; revenue: number | null; count: bigint }>
    >(Prisma.sql`
      SELECT to_char(date_trunc('day', COALESCE(finished_at, closed_at)), 'YYYY-MM-DD') AS day,
             SUM(total) AS revenue,
             COUNT(*)   AS count
      FROM service_order
      WHERE deleted_at IS NULL
        AND status IN ('concluida','entregue')
        AND COALESCE(finished_at, closed_at) IS NOT NULL
        AND COALESCE(finished_at, closed_at) >= ${p.from}
        AND COALESCE(finished_at, closed_at) <= ${p.to}
      GROUP BY 1
      ORDER BY 1
    `);
  }

  /**
   * Faturamento + contagem por status, sobre OS concluídas/entregues no range
   * (data de conclusão). Alimenta `byStatus` da série de faturamento.
   */
  revenueByStatus(p: MetricsRange) {
    const db = this.tenant.getClient();
    return db.$queryRaw<
      Array<{ status: string; revenue: number | null; count: bigint }>
    >(Prisma.sql`
      SELECT status, SUM(total) AS revenue, COUNT(*) AS count
      FROM service_order
      WHERE deleted_at IS NULL
        AND status IN ('concluida','entregue')
        AND COALESCE(finished_at, closed_at) IS NOT NULL
        AND COALESCE(finished_at, closed_at) >= ${p.from}
        AND COALESCE(finished_at, closed_at) <= ${p.to}
      GROUP BY status
    `);
  }

  /**
   * Rendimento por responsável (`assigned_to`) das OS abertas no range:
   * total de OS, concluídas (concluida+entregue), faturamento das concluídas e
   * ciclo médio (finished_at-started_at, ms). NULL → linha com assigned_to NULL.
   */
  teamPerformance(p: MetricsRange) {
    const db = this.tenant.getClient();
    return db.$queryRaw<
      Array<{
        assigned_to: string | null;
        orders: bigint;
        completed: bigint;
        revenue: number | null;
        avg_cycle_ms: number | null;
      }>
    >(Prisma.sql`
      SELECT assigned_to,
             COUNT(*) AS orders,
             COUNT(*) FILTER (WHERE status IN ('concluida','entregue')) AS completed,
             SUM(total) FILTER (WHERE status IN ('concluida','entregue')) AS revenue,
             AVG(EXTRACT(EPOCH FROM (finished_at - started_at)) * 1000)
               FILTER (WHERE status IN ('concluida','entregue')
                         AND started_at IS NOT NULL AND finished_at IS NOT NULL) AS avg_cycle_ms
      FROM service_order
      WHERE deleted_at IS NULL
        AND opened_at >= ${p.from} AND opened_at <= ${p.to}
      GROUP BY assigned_to
    `);
  }

  /**
   * Top de itens (`service_order_item`) das OS abertas no range: agrega por item
   * (chave name+kind+inventory_item_id), Σ quantidade, Σ total da linha e nº de OS
   * distintas. `kind` filtra produto/serviço quando dado. Ordena por receita desc.
   */
  topItems(p: MetricsRange & { kind?: string; limit: number }) {
    const db = this.tenant.getClient();
    const kindClause = p.kind
      ? Prisma.sql`AND i.kind = ${p.kind}`
      : Prisma.sql``;
    return db.$queryRaw<
      Array<{
        name: string;
        kind: string;
        inventory_item_id: string | null;
        qty: number | null;
        revenue: number | null;
        orders: bigint;
      }>
    >(Prisma.sql`
      SELECT i.name,
             i.kind,
             i.inventory_item_id,
             SUM(i.quantity)         AS qty,
             SUM(i.total)            AS revenue,
             COUNT(DISTINCT i.order_id) AS orders
      FROM service_order_item i
      JOIN service_order o ON o.id = i.order_id
      WHERE o.deleted_at IS NULL
        AND o.opened_at >= ${p.from} AND o.opened_at <= ${p.to}
        ${kindClause}
      GROUP BY i.name, i.kind, i.inventory_item_id
      ORDER BY revenue DESC NULLS LAST
      LIMIT ${p.limit}
    `);
  }

  /** Linhas detalhadas do relatório (Fase 2): OS no range/escopo + status opcional. */
  listForReport(p: MetricsRange & { status?: string }) {
    const db = this.tenant.getClient();
    return db.service_order.findMany({
      where: {
        ...this.metricsWhere(p),
        ...(p.status ? { status: p.status } : {}),
      },
      orderBy: { opened_at: 'desc' },
      select: {
        id: true,
        number: true,
        customer_name: true,
        status: true,
        assigned_to: true,
        total: true,
        opened_at: true,
        started_at: true,
        finished_at: true,
      },
    });
  }

  /**
   * Linhas do relatório de OS PAGINADAS (tela): OS no range/escopo + status +
   * busca (nº/cliente) opcionais, ordenadas por `sort` (default `recent`).
   * Retorna a página + total para o scroll infinito. Tenant-scoped por RLS.
   */
  async listForReportPage(
    p: MetricsRange & {
      status?: string;
      q?: string;
      sort?: string;
      skip: number;
      take: number;
    },
  ) {
    const db = this.tenant.getClient();
    const where: Prisma.service_orderWhereInput = {
      ...this.metricsWhere(p),
      ...(p.status ? { status: p.status } : {}),
      ...(p.q
        ? {
            OR: [
              { number: { contains: p.q, mode: 'insensitive' } },
              { customer_name: { contains: p.q, mode: 'insensitive' } },
            ],
          }
        : {}),
    };
    const [rows, total] = await Promise.all([
      db.service_order.findMany({
        where,
        orderBy:
          OS_REPORT_ORDER_BY[p.sort ?? 'recent'] ?? OS_REPORT_ORDER_BY.recent,
        skip: p.skip,
        take: p.take,
        select: {
          id: true,
          number: true,
          customer_name: true,
          status: true,
          assigned_to: true,
          total: true,
          opened_at: true,
          started_at: true,
          finished_at: true,
        },
      }),
      db.service_order.count({ where }),
    ]);
    return { rows, total };
  }

  /**
   * TODAS as linhas do relatório de OS (export COMPLETO) — mesmos filtros do
   * `listForReportPage` (range/escopo + status + busca + ordenação), porém SEM
   * paginação. Alimenta o export server-side (CSV/PDF do relatório inteiro que o
   * usuário está vendo, respeitando os filtros ativos). Tenant-scoped por RLS.
   */
  listAllForReport(
    p: MetricsRange & { status?: string; q?: string; sort?: string },
  ) {
    const db = this.tenant.getClient();
    const where: Prisma.service_orderWhereInput = {
      ...this.metricsWhere(p),
      ...(p.status ? { status: p.status } : {}),
      ...(p.q
        ? {
            OR: [
              { number: { contains: p.q, mode: 'insensitive' } },
              { customer_name: { contains: p.q, mode: 'insensitive' } },
            ],
          }
        : {}),
    };
    return db.service_order.findMany({
      where,
      orderBy:
        OS_REPORT_ORDER_BY[p.sort ?? 'recent'] ?? OS_REPORT_ORDER_BY.recent,
      select: {
        id: true,
        number: true,
        customer_name: true,
        status: true,
        assigned_to: true,
        total: true,
        opened_at: true,
        started_at: true,
        finished_at: true,
      },
    });
  }

  // ---- sync pull (offline) ----
  /**
   * Página de mudanças de uma entidade do módulo os desde o cursor. Sync pull
   * — ver `common/database/changed-since.ts`.
   */
  listChangedSince(
    table: OsSyncEntity,
    cursor: ChangeCursor | null,
    limit: number,
  ): Promise<ChangedSincePage> {
    const db = this.tenant.getClient();
    return queryChangedSince(db, table, SYNC_ENTITY_COLUMN[table], cursor, limit);
  }
}

/** Range + escopo resolvido para as agregações de métrica. */
export interface MetricsRange {
  from: Date;
  to: Date;
  assignedTo?: string;
}
