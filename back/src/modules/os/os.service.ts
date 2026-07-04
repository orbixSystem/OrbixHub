import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { Prisma } from '@prisma/client';
import type { AuthUser } from '../../common/auth/auth.types';
import { TenantContext } from '../../common/database/tenant-context';
import { AuditService } from '../../common/audit/audit.service';
import {
  STORAGE_PROVIDER,
  StorageProvider,
} from '../../common/storage/storage.provider';
import { CustomersService } from '../customers/customers.service';
import { InventoryService } from '../inventory/inventory.service';
import { MessagesService } from '../messages/messages.service';
import { OsRepository } from './os.repository';
import {
  ChangeStatusDto,
  CreateOrderDto,
  ListOrdersQueryDto,
  OsStatus,
  UpdateOrderDto,
} from './dto/order.dto';
import { CreateItemDto, UpdateItemDto } from './dto/item.dto';
import { CreateNoteDto } from './dto/note.dto';
import {
  CreateTemplateDto,
  TemplateItemDto,
  UpdateTemplateDto,
} from './dto/template.dto';
import type { CreateTemplateItemData } from './os.repository';

const DEFAULT_PAGE_SIZE = 20;

/** Subset do arquivo multer (memory storage) usado no upload de fotos. */
export interface UploadedImage {
  buffer: Buffer;
  mimetype: string;
  size: number;
  originalname?: string;
}

/** Rótulos PT-BR dos status (mensagem legível nos eventos de timeline). */
const STATUS_LABELS: Record<OsStatus, string> = {
  aberta: 'OS aberta',
  aguardando_aprovacao: 'Aguardando aprovação',
  aprovada: 'Orçamento aprovado',
  em_execucao: 'Em execução',
  concluida: 'Serviço concluído',
  entregue: 'Veículo entregue',
  cancelada: 'OS cancelada',
};

const toNum = (d: Prisma.Decimal | number | null | undefined): number =>
  d == null ? 0 : typeof d === 'number' ? d : d.toNumber();

/** Datas ISO → Date | null (undefined preserva "não mexer"). */
const toDate = (v: string | undefined): Date | null | undefined =>
  v === undefined ? undefined : v ? new Date(v) : null;

/** Data PT-BR (dd/MM/yyyy) para mensagens de timeline visíveis ao cliente. */
const formatBrDate = (d: Date): string => {
  const p = (n: number) => String(n).padStart(2, '0');
  return `${p(d.getDate())}/${p(d.getMonth() + 1)}/${d.getFullYear()}`;
};

/** Status em que a OS consome estoque (peça está/foi usada). */
const CONSUMING_STATUSES = new Set<OsStatus>([
  'em_execucao',
  'concluida',
  'entregue',
]);
const consumes = (status: string): boolean =>
  CONSUMING_STATUSES.has(status as OsStatus);

/**
 * Máquina de estados do workflow da OS (FSM pura). Cada chave lista os destinos
 * válidos; `entregue` é terminal (sem destinos). `cancelada` só sai via
 * "reabertura" (→ `aberta`), que é privilegiada (gated por `os.approve`).
 */
const TRANSITIONS: Record<OsStatus, OsStatus[]> = {
  aberta: ['aguardando_aprovacao', 'em_execucao', 'cancelada'],
  aguardando_aprovacao: ['aprovada', 'aberta', 'cancelada'],
  aprovada: ['em_execucao', 'cancelada'],
  em_execucao: ['concluida', 'cancelada'],
  concluida: ['entregue'],
  entregue: [],
  cancelada: ['aberta'],
};

/**
 * Estados terminais: a OS não aceita edição de conteúdo (itens, fotos, notas,
 * cabeçalho). `cancelada` volta a ser editável reabrindo-a (→ `aberta`);
 * `entregue` é final.
 */
const TERMINAL_STATUSES = new Set<OsStatus>(['cancelada', 'entregue']);

@Injectable()
export class OsService {
  private readonly logger = new Logger(OsService.name);

  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: OsRepository,
    private readonly audit: AuditService,
    private readonly customers: CustomersService,
    private readonly inventory: InventoryService,
    private readonly messages: MessagesService,
    @Inject(STORAGE_PROVIDER) private readonly storage: StorageProvider,
  ) {}

  /** Limite de tamanho do upload de foto (~8 MB). */
  private static readonly MAX_PHOTO_BYTES = 8 * 1024 * 1024;

  // ===================== Orders =====================
  async createOrder(user: AuthUser, dto: CreateOrderDto) {
    // "Aponta, não invade": resolve via service público + snapshot (não toca a tabela alheia).
    // Cada chamada ao CustomersService roda na PRÓPRIA withTenantTx — chame-as
    // SEQUENCIALMENTE e ANTES da tx da OS (nunca aninhe; aninhar esgota o pool).
    let customer: { id: string; name: string };
    let subjectId: string | null = null;
    let subjectLabel: string | null = null;

    if (dto.customerId) {
      // Caminho "cliente existente": ponteiro + snapshot.
      customer = await this.customers.getCustomer(user, dto.customerId);
      if (dto.subjectId) {
        const subject = await this.customers.getSubject(user, dto.subjectId);
        subjectId = subject.id;
        subjectLabel = subject.label || subject.identifier || null;
      }
    } else if (dto.newCustomerName?.trim()) {
      // Caminho "cliente novo na hora": cria o cliente (e o veículo) via service público.
      customer = await this.customers.createCustomer(user, {
        name: dto.newCustomerName.trim(),
        phone: dto.newCustomerPhone?.trim(),
      });
      const wantsSubject =
        !!dto.newSubjectIdentifier?.trim() ||
        (dto.newSubjectAttributes != null &&
          Object.keys(dto.newSubjectAttributes).length > 0);
      if (wantsSubject) {
        // Só cria o subject se o tenant usa objetos; senão a OS fica só com o cliente.
        const config = await this.customers.getConfig(user.tenantId);
        if (config.usaSubjects) {
          const subject = await this.customers.createSubject(user, customer.id, {
            identifier: dto.newSubjectIdentifier?.trim() || undefined,
            attributes: dto.newSubjectAttributes,
          });
          subjectId = subject.id;
          subjectLabel = subject.label || subject.identifier || null;
        } else {
          this.logger.warn(
            `OS criada sem veículo: tenant ${user.tenantId} não usa objetos (usaSubjects=false).`,
          );
        }
      }
    } else {
      throw new BadRequestException(
        'Informe um cliente existente ou os dados de um novo cliente (nome).',
      );
    }

    const order = await this.tenant.withTenantTx(async () => {
      const n = (await this.repo.maxOrderNumber()) + 1;
      const number = `OS-${String(n).padStart(4, '0')}`;
      const created = await this.repo.createOrder(user.tenantId, {
        number,
        customer_id: customer.id,
        customer_name: customer.name,
        subject_id: subjectId,
        subject_label: subjectLabel,
        status: 'aberta',
        opened_by: user.userId,
        assigned_to: dto.assignedTo ?? null,
        complaint: dto.complaint?.trim() || null,
        diagnosis: dto.diagnosis?.trim() || null,
        scheduled_start: dto.scheduledStart ? new Date(dto.scheduledStart) : null,
        scheduled_end: dto.scheduledEnd ? new Date(dto.scheduledEnd) : null,
      });
      // Evento de abertura — mesma tx (createEvent usa o cliente tx-scoped).
      await this.repo.createEvent(user.tenantId, created.id, {
        kind: 'created',
        message: 'OS aberta',
        statusSnapshot: 'aberta',
        visiblePublic: true,
        createdBy: user.userId,
      });
      return created;
    });
    // audit FORA do tx (audit.log abre sua própria transação; aninhar esgota o pool).
    await this.audit.log(user.tenantId, user.userId, 'os_create', order.id);

    // Cria a conversa (chat) da OS via service público do módulo genérico `messages`
    // ("aponta, não invade": passamos só o id da OS como ref_id; não tocamos a tabela).
    // SEQUENCIAL e FORA da tx da OS (createConversation abre a própria via
    // runWithTenant). best-effort: falha de mensageria NUNCA bloqueia a criação da OS.
    try {
      await this.messages.createConversation(user.tenantId, {
        refType: 'os',
        refId: order.id,
        title: order.customer_name,
        refLabel: order.number, // ex.: 'OS-0001' — distingue clientes homônimos
      });
    } catch (e) {
      this.logger.warn(
        `Falha ao criar conversa da OS ${order.id}: ${(e as Error).message}`,
      );
    }
    return order;
  }

  async listOrders(user: AuthUser, query: ListOrdersQueryDto) {
    const page = query.page ?? 1;
    const pageSize = query.pageSize ?? DEFAULT_PAGE_SIZE;
    const { items, total } = await this.tenant.withTenantTx(() =>
      this.repo.listOrders({
        q: query.q?.trim() || undefined,
        status: query.status,
        customerId: query.customerId,
        sort: query.sort,
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
    );
    return { items, total, page, pageSize };
  }

  async getOrderOrThrow(id: string) {
    return this.tenant.withTenantTx(async () => {
      const order = await this.repo.findOrderById(id);
      if (!order || order.deleted_at)
        throw new NotFoundException('OS não encontrada.');
      // Timeline (mais recente no topo) + fotos embutidas no detalhe — front pega em 1 chamada.
      const [events, photos] = await Promise.all([
        this.repo.listEvents(id),
        this.repo.listPhotos(id),
      ]);
      return { ...order, events, photos };
    });
  }

  /**
   * Cabeçalho da OS + itens para consumo por OUTRO módulo (ex.: `invoice`) via
   * service público — "aponta, não invade": o chamador guarda só o id e busca
   * aqui, sem tocar as tabelas da OS. Não inclui timeline/fotos (não são fiscais).
   */
  async getOrderWithItems(id: string) {
    return this.tenant.withTenantTx(async () => {
      const order = await this.repo.findOrderById(id);
      if (!order || order.deleted_at)
        throw new NotFoundException('OS não encontrada.');
      const items = await this.repo.listItems(id);
      return { order, items };
    });
  }

  async updateOrder(user: AuthUser, id: string, dto: UpdateOrderDto) {
    const order = await this.tenant.withTenantTx(async () => {
      const existing = await this.repo.findOrderById(id);
      if (!existing || existing.deleted_at)
        throw new NotFoundException('OS não encontrada.');
      this.assertEditable(existing);
      const data: Record<string, unknown> = {};
      if (dto.complaint !== undefined) data.complaint = dto.complaint.trim() || null;
      if (dto.diagnosis !== undefined) data.diagnosis = dto.diagnosis.trim() || null;
      if (dto.scheduledStart !== undefined)
        data.scheduled_start = toDate(dto.scheduledStart);
      if (dto.scheduledEnd !== undefined)
        data.scheduled_end = toDate(dto.scheduledEnd);
      if (dto.assignedTo !== undefined) data.assigned_to = dto.assignedTo;
      if (dto.discount !== undefined) data.discount = dto.discount;
      await this.repo.updateOrder(id, data);

      // Mudanças relevantes do serviço viram eventos VISÍVEIS ao cliente na
      // página pública de acompanhamento (mesma tx).
      if (dto.scheduledEnd !== undefined) {
        const newEnd = toDate(dto.scheduledEnd) ?? null;
        const oldEnd = existing.scheduled_end ?? null;
        if ((newEnd?.getTime() ?? null) !== (oldEnd?.getTime() ?? null)) {
          await this.repo.createEvent(user.tenantId, id, {
            kind: 'note',
            message: newEnd
              ? `Previsão de entrega: ${formatBrDate(newEnd)}`
              : 'Previsão de entrega removida',
            visiblePublic: true,
            createdBy: user.userId,
          });
        }
      }
      if (dto.diagnosis !== undefined) {
        const newDiag = dto.diagnosis.trim() || null;
        const oldDiag = existing.diagnosis ?? null;
        if (newDiag && newDiag !== oldDiag) {
          await this.repo.createEvent(user.tenantId, id, {
            kind: 'note',
            message: 'Diagnóstico atualizado',
            visiblePublic: true,
            createdBy: user.userId,
          });
        }
      }

      // Desconto do cabeçalho mudou → recalcula total.
      if (dto.discount !== undefined) await this.recomputeTotal(id);
      return this.repo.findOrderById(id);
    });
    await this.audit.log(user.tenantId, user.userId, 'os_update', id);
    return order;
  }

  async deleteOrder(user: AuthUser, id: string) {
    const result = await this.tenant.withTenantTx(async () => {
      const existing = await this.repo.findOrderById(id);
      if (!existing || existing.deleted_at)
        throw new NotFoundException('OS não encontrada.');
      return this.repo.softDelete(id);
    });
    await this.audit.log(user.tenantId, user.userId, 'os_delete', id);
    return result;
  }

  // ===================== Timeline / notas =====================
  /**
   * Adiciona uma nota manual à timeline da OS. `visiblePublic` (default false)
   * controla se a nota aparece na página pública de acompanhamento.
   */
  async createNote(user: AuthUser, orderId: string, dto: CreateNoteDto) {
    const event = await this.tenant.withTenantTx(async () => {
      const order = await this.repo.findOrderById(orderId);
      if (!order || order.deleted_at)
        throw new NotFoundException('OS não encontrada.');
      this.assertEditable(order);
      return this.repo.createEvent(user.tenantId, orderId, {
        kind: 'note',
        message: dto.message.trim(),
        visiblePublic: dto.visiblePublic ?? false,
        createdBy: user.userId,
      });
    });
    return event;
  }

  // ===================== Fotos =====================
  /**
   * Anexa uma foto à OS. Valida ordem + tipo/tamanho do arquivo, sobe o binário ao
   * storage **FORA de qualquer transação de banco** (regra de ouro), e só então
   * persiste a linha + um evento 'photo' na timeline (na mesma tx). Retorna a foto
   * com a URL pública.
   */
  async addPhoto(
    user: AuthUser,
    orderId: string,
    file: UploadedImage | undefined,
    caption?: string,
  ) {
    if (!file?.buffer) {
      throw new BadRequestException('Arquivo de imagem é obrigatório.');
    }
    if (!file.mimetype?.startsWith('image/')) {
      throw new BadRequestException('O arquivo deve ser uma imagem.');
    }
    if (file.size > OsService.MAX_PHOTO_BYTES) {
      throw new BadRequestException('Imagem muito grande (máx. 8 MB).');
    }

    // Confere que a OS existe / não está deletada / é editável ANTES do upload.
    const order = await this.getOrderOrThrow(orderId);
    this.assertEditable(order);

    // Chave única + extensão a partir do mimetype (genérica).
    const ext = (file.mimetype.split('/')[1] || 'bin').replace(
      /[^a-z0-9]/gi,
      '',
    );
    const key = `os/${orderId}/${randomUUID()}.${ext}`;

    // Upload do binário — FORA de transação de banco.
    await this.storage.put(key, file.buffer, file.mimetype);
    const url = this.storage.url(key);

    const photo = await this.tenant.withTenantTx(async () => {
      const created = await this.repo.addPhoto(user.tenantId, {
        order_id: orderId,
        storage_key: key,
        url,
        caption: caption?.trim() || null,
        uploaded_by: user.userId,
      });
      // Evento 'photo' na timeline (visível ao cliente) — mesma tx.
      await this.repo.createEvent(user.tenantId, orderId, {
        kind: 'photo',
        message: 'Foto adicionada',
        photoId: created.id,
        visiblePublic: true,
        createdBy: user.userId,
      });
      return created;
    });
    await this.audit.log(user.tenantId, user.userId, 'os_photo_add', orderId, {
      photoId: photo.id,
    });
    return photo;
  }

  /**
   * Remove uma foto da OS: busca a linha, apaga o binário no storage **fora da tx**,
   * depois deleta a linha (hard delete — não é registro histórico; o evento de
   * timeline permanece).
   */
  async deletePhoto(user: AuthUser, orderId: string, photoId: string) {
    const photo = await this.tenant.withTenantTx(async () => {
      const found = await this.repo.findPhotoById(photoId);
      if (!found || found.order_id !== orderId) {
        throw new NotFoundException('Foto não encontrada.');
      }
      return found;
    });

    // Remoção no storage — FORA de transação de banco. Best-effort: falha no
    // storage não impede a deleção da linha (loga um aviso).
    try {
      await this.storage.remove(photo.storage_key);
    } catch (e) {
      this.logger.warn(
        `Remoção do arquivo falhou (foto ${photoId}): ${(e as Error).message}`,
      );
    }

    await this.tenant.withTenantTx(() => this.repo.deletePhoto(photoId));
    await this.audit.log(user.tenantId, user.userId, 'os_photo_delete', orderId, {
      photoId,
    });
    return { id: photoId, deleted: true };
  }

  /**
   * Bloqueia edição de conteúdo quando a OS está num estado terminal
   * (`cancelada`/`entregue`). Cancelada pode voltar a ser editável reabrindo-a.
   */
  private assertEditable(order: { status: string }) {
    if (!TERMINAL_STATUSES.has(order.status as OsStatus)) return;
    if (order.status === 'cancelada') {
      throw new BadRequestException(
        'OS cancelada não pode ser alterada. Reabra a OS para editá-la.',
      );
    }
    throw new BadRequestException('OS entregue não pode ser alterada.');
  }

  // ===================== Workflow =====================
  async changeStatus(user: AuthUser, id: string, dto: ChangeStatusDto) {
    const to = dto.status;
    const order = await this.getOrderOrThrow(id);
    const from = order.status as OsStatus;

    if (from === to) throw new BadRequestException('A OS já está neste status.');
    if (!TRANSITIONS[from]?.includes(to)) {
      throw new BadRequestException(
        `Transição inválida: ${from} → ${to}.`,
      );
    }
    // Aprovar exige a permissão os.approve (owner/gerente têm; mecânico não).
    if (to === 'aprovada' && !(await this.userHasPermission(user, 'os.approve'))) {
      throw new ForbiddenException('Sem permissão para aprovar OS.');
    }
    // Reabrir (cancelada → aberta) é privilegiado — mesmo público de aprovar.
    const isReopen = from === 'cancelada' && to === 'aberta';
    if (isReopen && !(await this.userHasPermission(user, 'os.approve'))) {
      throw new ForbiddenException('Sem permissão para reabrir OS.');
    }

    const fields: {
      status: string;
      started_at?: Date;
      finished_at?: Date;
      closed_at?: Date;
    } = { status: to };
    if (to === 'em_execucao') fields.started_at = new Date();
    if (to === 'concluida') fields.finished_at = new Date();
    if (to === 'entregue') fields.closed_at = new Date();

    await this.tenant.withTenantTx(async () => {
      await this.repo.setStatusFields(id, fields);
      // Evento de mudança de status — mesma tx (visível na página pública).
      await this.repo.createEvent(user.tenantId, id, {
        kind: 'status_change',
        statusSnapshot: to,
        message: isReopen ? 'OS reaberta' : STATUS_LABELS[to],
        visiblePublic: true,
        createdBy: user.userId,
      });
    });
    await this.audit.log(user.tenantId, user.userId, 'os_status_change', id, {
      from,
      to,
    });

    // Baixa/estorno de estoque conforme o novo status (idempotente). Substitui o
    // antigo applyStock/stock_applied. FORA de withTenantTx (reconcile abre a
    // própria tx). best-effort: erro de estoque não desfaz a transição.
    const after = await this.getOrderOrThrow(id);
    await this.reconcileOrderStock(user, after);

    if (to === 'cancelada') {
      const devolvidos = after.items.filter(
        (i) => i.kind === 'product' && i.inventory_item_id,
      ).length;
      if (devolvidos > 0) {
        await this.audit.log(
          user.tenantId,
          user.userId,
          'os_stock_reconcile',
          id,
          { event: 'cancel_reversal', items: devolvidos },
        );
        // Nota interna na timeline (best-effort — não bloqueia).
        try {
          await this.tenant.withTenantTx(() =>
            this.repo.createEvent(user.tenantId, id, {
              kind: 'note',
              message: `Estoque estornado: ${devolvidos} item(ns) devolvido(s).`,
              visiblePublic: false,
              createdBy: user.userId,
            }),
          );
        } catch (e) {
          this.logger.warn(
            `Nota de estorno falhou (OS ${id}): ${(e as Error).message}`,
          );
        }
      }
    }

    return this.getOrderOrThrow(id);
  }

  /**
   * Reconcilia o estoque de TODAS as linhas-produto da OS para o alvo conforme o
   * status atual (consome → quantidade; senão → 0). Idempotente (delegado ao
   * inventory). Best-effort: erro num item (ex.: estoque insuficiente) NÃO
   * bloqueia a operação — apenas loga. Roda FORA de transação de banco
   * (reconcileConsumption abre a própria via runWithTenant).
   */
  private async reconcileOrderStock(
    user: AuthUser,
    order: {
      id: string;
      status: string;
      items: Array<{
        id: string;
        kind: string;
        inventory_item_id: string | null;
        quantity: Prisma.Decimal | number;
      }>;
    },
  ): Promise<void> {
    const target = consumes(order.status);
    for (const item of order.items) {
      if (item.kind !== 'product' || !item.inventory_item_id) continue;
      try {
        await this.inventory.reconcileConsumption(user.tenantId, {
          inventoryItemId: item.inventory_item_id,
          refType: 'service_order',
          refId: order.id,
          refItemId: item.id,
          targetQty: target ? toNum(item.quantity) : 0,
          createdBy: user.userId,
        });
      } catch (e) {
        this.logger.warn(
          `Reconciliação de estoque falhou (OS ${order.id}, item ${item.id}): ${
            (e as Error).message
          }`,
        );
      }
    }
  }

  // ===================== Items =====================
  async addItem(user: AuthUser, orderId: string, dto: CreateItemDto) {
    let name = dto.name?.trim() || '';
    let unitPrice = dto.unitPrice ?? 0;
    let kind: 'product' | 'service' = dto.kind;
    let inventoryItemId: string | null = null;

    if (dto.inventoryItemId) {
      // Snapshot a partir do item de estoque (service público — não toca a tabela alheia).
      const invItem = await this.inventory.getItem(dto.inventoryItemId);
      inventoryItemId = invItem.id;
      name = invItem.name;
      kind = (invItem.kind as 'product' | 'service') ?? dto.kind;
      if (dto.unitPrice === undefined) unitPrice = toNum(invItem.sale_price);
    } else if (!name) {
      throw new BadRequestException('Nome é obrigatório para item avulso.');
    }

    const quantity = dto.quantity ?? 1;
    const discount = dto.discount ?? 0;
    const total = Math.max(0, quantity * unitPrice - discount);

    const result = await this.tenant.withTenantTx(async () => {
      const order = await this.repo.findOrderById(orderId);
      if (!order || order.deleted_at)
        throw new NotFoundException('OS não encontrada.');
      this.assertEditable(order);
      const item = await this.repo.addItem(user.tenantId, {
        order_id: orderId,
        kind,
        inventory_item_id: inventoryItemId,
        name,
        quantity,
        unit_price: unitPrice,
        discount,
        total,
      });
      await this.recomputeTotal(orderId);
      return item;
    });
    // Se a OS já consome estoque, baixa a linha recém-criada (fora da tx).
    const orderAfterAdd = await this.getOrderOrThrow(orderId);
    if (consumes(orderAfterAdd.status)) {
      const created = orderAfterAdd.items.find((i) => i.id === result.id);
      if (created)
        await this.reconcileOrderStock(user, {
          ...orderAfterAdd,
          items: [created],
        });
    }
    return result;
  }

  async updateItem(
    user: AuthUser,
    orderId: string,
    itemId: string,
    dto: UpdateItemDto,
  ) {
    const item = await this.tenant.withTenantTx(async () => {
      const order = await this.repo.findOrderById(orderId);
      if (!order || order.deleted_at)
        throw new NotFoundException('OS não encontrada.');
      this.assertEditable(order);
      const existing = await this.repo.findItemById(itemId);
      if (!existing || existing.order_id !== orderId)
        throw new NotFoundException('Item não encontrado.');

      const quantity = dto.quantity ?? toNum(existing.quantity);
      const unitPrice = dto.unitPrice ?? toNum(existing.unit_price);
      const discount = dto.discount ?? toNum(existing.discount);
      const total = Math.max(0, quantity * unitPrice - discount);

      const data: Record<string, unknown> = { total };
      if (dto.name !== undefined) data.name = dto.name.trim();
      if (dto.quantity !== undefined) data.quantity = dto.quantity;
      if (dto.unitPrice !== undefined) data.unit_price = dto.unitPrice;
      if (dto.discount !== undefined) data.discount = dto.discount;

      const updated = await this.repo.updateItem(itemId, data);
      await this.recomputeTotal(orderId);
      return updated;
    });
    // Reconcilia o estoque da linha se a OS consome (fora da tx).
    const orderAfterUpd = await this.getOrderOrThrow(orderId);
    if (consumes(orderAfterUpd.status)) {
      const changed = orderAfterUpd.items.find((i) => i.id === itemId);
      if (changed)
        await this.reconcileOrderStock(user, {
          ...orderAfterUpd,
          items: [changed],
        });
    }
    return item;
  }

  async deleteItem(user: AuthUser, orderId: string, itemId: string) {
    const { removed, order } = await this.tenant.withTenantTx(async () => {
      const order = await this.repo.findOrderById(orderId);
      if (!order || order.deleted_at)
        throw new NotFoundException('OS não encontrada.');
      this.assertEditable(order);
      const existing = await this.repo.findItemById(itemId);
      if (!existing || existing.order_id !== orderId)
        throw new NotFoundException('Item não encontrado.');
      await this.repo.deleteItem(itemId);
      await this.recomputeTotal(orderId);
      return { removed: existing, order };
    });
    // Estorna o consumo da linha removida (alvo 0) se a OS consome (fora da tx).
    if (
      consumes(order.status) &&
      removed.kind === 'product' &&
      removed.inventory_item_id
    ) {
      try {
        await this.inventory.reconcileConsumption(user.tenantId, {
          inventoryItemId: removed.inventory_item_id,
          refType: 'service_order',
          refId: orderId,
          refItemId: itemId,
          targetQty: 0,
          createdBy: user.userId,
        });
      } catch (e) {
        this.logger.warn(
          `Estorno de estoque falhou (OS ${orderId}, item ${itemId}): ${
            (e as Error).message
          }`,
        );
      }
    }
    return { id: itemId, deleted: true };
  }

  // ===================== Templates de serviço =====================
  /**
   * Resolve os itens de um template (DTO → dados do repo). Para itens com
   * `inventoryItemId`, faz snapshot de nome/preço via `inventory.getItem`
   * (service público — não toca a tabela alheia). Cada getItem abre a PRÓPRIA
   * withTenantTx, então resolvemos SEQUENCIALMENTE e FORA de qualquer tx (aninhar
   * esgota o pool). Itens avulsos exigem `name`.
   */
  private async resolveTemplateItems(
    items: TemplateItemDto[],
  ): Promise<CreateTemplateItemData[]> {
    const resolved: CreateTemplateItemData[] = [];
    for (const dto of items) {
      let name = dto.name?.trim() || '';
      let unitPrice: number | null = dto.unitPrice ?? null;
      let kind: 'product' | 'service' = dto.kind;
      let inventoryItemId: string | null = null;

      if (dto.inventoryItemId) {
        const invItem = await this.inventory.getItem(dto.inventoryItemId);
        inventoryItemId = invItem.id;
        name = invItem.name;
        kind = (invItem.kind as 'product' | 'service') ?? dto.kind;
        if (dto.unitPrice === undefined) unitPrice = toNum(invItem.sale_price);
      } else if (!name) {
        throw new BadRequestException('Nome é obrigatório para item avulso.');
      }

      resolved.push({
        kind,
        inventory_item_id: inventoryItemId,
        name,
        quantity: dto.quantity ?? 1,
        unit_price: unitPrice,
      });
    }
    return resolved;
  }

  async createTemplate(user: AuthUser, dto: CreateTemplateDto) {
    // Snapshot dos itens FORA da tx do template (getItem abre a própria tx).
    const items = await this.resolveTemplateItems(dto.items ?? []);

    const template = await this.tenant.withTenantTx(async () => {
      const created = await this.repo.createTemplate(user.tenantId, {
        name: dto.name.trim(),
        description: dto.description?.trim() || null,
      });
      for (const item of items) {
        await this.repo.addTemplateItem(user.tenantId, created.id, item);
      }
      return this.repo.findTemplateById(created.id);
    });
    await this.audit.log(
      user.tenantId,
      user.userId,
      'os_template_create',
      template!.id,
    );
    const [enriched] = await this.enrichTemplates([template!]);
    return enriched;
  }

  /**
   * Enriquece templates com o preço CORRENTE do estoque e o total somado. Itens
   * vinculados ao estoque (`inventory_item_id`) refletem o nome/preço atual via
   * `inventory.getItemsByIds` (mesma lógica do `applyTemplate`); avulsos e itens
   * cujo estoque sumiu mantêm o snapshot gravado. `total` = Σ(quantidade × preço).
   * Roda FORA de qualquer tx (getItemsByIds abre a própria — não aninhar).
   */
  private async enrichTemplates<
    T extends {
      items: Array<{
        inventory_item_id: string | null;
        name: string;
        kind: string;
        quantity: Prisma.Decimal;
        unit_price: Prisma.Decimal | null;
      }>;
    },
  >(templates: T[]): Promise<Array<T & { total: string }>> {
    const ids = [
      ...new Set(
        templates
          .flatMap((t) => t.items)
          .map((i) => i.inventory_item_id)
          .filter((id): id is string => !!id),
      ),
    ];
    const live = await this.inventory.getItemsByIds(ids);
    const byId = new Map(live.map((it) => [it.id, it]));

    return templates.map((t) => {
      const items = t.items.map((it) => {
        const inv = it.inventory_item_id ? byId.get(it.inventory_item_id) : null;
        return inv
          ? {
              ...it,
              name: inv.name,
              kind: inv.kind,
              unit_price: inv.sale_price,
            }
          : it;
      });
      const total = items.reduce(
        (acc, it) => acc + Math.max(0, toNum(it.quantity) * toNum(it.unit_price)),
        0,
      );
      return { ...t, items, total: total.toFixed(2) };
    });
  }

  async listTemplates(_user: AuthUser) {
    const templates = await this.tenant.withTenantTx(() =>
      this.repo.listTemplates(),
    );
    return this.enrichTemplates(templates);
  }

  async getTemplate(_user: AuthUser, id: string) {
    const template = await this.tenant.withTenantTx(async () => {
      const found = await this.repo.findTemplateById(id);
      if (!found || found.deleted_at)
        throw new NotFoundException('Template não encontrado.');
      return found;
    });
    const [enriched] = await this.enrichTemplates([template]);
    return enriched;
  }

  async updateTemplate(user: AuthUser, id: string, dto: UpdateTemplateDto) {
    // Snapshot dos novos itens FORA da tx (getItem abre a própria tx).
    const items =
      dto.items !== undefined
        ? await this.resolveTemplateItems(dto.items)
        : undefined;

    const template = await this.tenant.withTenantTx(async () => {
      const existing = await this.repo.findTemplateById(id);
      if (!existing || existing.deleted_at)
        throw new NotFoundException('Template não encontrado.');
      const data: { name?: string; description?: string | null } = {};
      if (dto.name !== undefined) data.name = dto.name.trim();
      if (dto.description !== undefined)
        data.description = dto.description.trim() || null;
      if (Object.keys(data).length) await this.repo.updateTemplate(id, data);
      if (items !== undefined) {
        // Substituição integral dos itens.
        await this.repo.deleteTemplateItems(id);
        for (const item of items) {
          await this.repo.addTemplateItem(user.tenantId, id, item);
        }
      }
      return this.repo.findTemplateById(id);
    });
    await this.audit.log(user.tenantId, user.userId, 'os_template_update', id);
    const [enriched] = await this.enrichTemplates([template!]);
    return enriched;
  }

  async deleteTemplate(user: AuthUser, id: string) {
    const result = await this.tenant.withTenantTx(async () => {
      const existing = await this.repo.findTemplateById(id);
      if (!existing || existing.deleted_at)
        throw new NotFoundException('Template não encontrado.');
      return this.repo.softDeleteTemplate(id);
    });
    await this.audit.log(user.tenantId, user.userId, 'os_template_delete', id);
    return result;
  }

  /**
   * Aplica um template a uma OS: para cada item do template, insere um
   * `service_order_item` na OS. Itens com `inventory_item_id` re-fazem snapshot do
   * nome/preço ATUAL via `inventory.getItem` (preço corrente no momento de aplicar);
   * avulsos usam o nome/preço gravado no template. Recalcula o total e adiciona um
   * evento de nota na timeline (interno). Retorna a OS atualizada (com itens/eventos).
   */
  async applyTemplate(user: AuthUser, orderId: string, templateId: string) {
    // Carrega OS + template (cada um na própria tx) e re-snapshot dos itens de
    // estoque ANTES da tx de escrita (getItem abre a própria tx — não aninhar).
    const template = await this.getTemplate(user, templateId);
    // Garante OS existente / não deletada / editável antes do re-snapshot.
    const target = await this.getOrderOrThrow(orderId);
    this.assertEditable(target);

    // Resolve os itens a inserir (re-snapshot do preço atual quando vinculado ao estoque).
    const toInsert: Array<{
      kind: 'product' | 'service';
      inventory_item_id: string | null;
      name: string;
      quantity: number;
      unit_price: number;
    }> = [];
    for (const ti of template.items) {
      let name = ti.name;
      let unitPrice = toNum(ti.unit_price);
      let kind = ti.kind as 'product' | 'service';
      let inventoryItemId: string | null = ti.inventory_item_id;
      if (ti.inventory_item_id) {
        // Re-snapshot do preço/nome CORRENTE no momento de aplicar.
        const invItem = await this.inventory.getItem(ti.inventory_item_id);
        inventoryItemId = invItem.id;
        name = invItem.name;
        kind = (invItem.kind as 'product' | 'service') ?? kind;
        unitPrice = toNum(invItem.sale_price);
      }
      toInsert.push({
        kind,
        inventory_item_id: inventoryItemId,
        name,
        quantity: toNum(ti.quantity),
        unit_price: unitPrice,
      });
    }

    const updated = await this.tenant.withTenantTx(async () => {
      const existing = await this.repo.findOrderById(orderId);
      if (!existing || existing.deleted_at)
        throw new NotFoundException('OS não encontrada.');
      for (const it of toInsert) {
        const total = Math.max(0, it.quantity * it.unit_price);
        await this.repo.addItem(user.tenantId, {
          order_id: orderId,
          kind: it.kind,
          inventory_item_id: it.inventory_item_id,
          name: it.name,
          quantity: it.quantity,
          unit_price: it.unit_price,
          discount: 0,
          total,
        });
      }
      await this.recomputeTotal(orderId);
      await this.repo.createEvent(user.tenantId, orderId, {
        kind: 'note',
        message: `Template aplicado: ${template.name}`,
        visiblePublic: false,
        createdBy: user.userId,
      });
      return this.repo.findOrderById(orderId);
    });
    await this.audit.log(
      user.tenantId,
      user.userId,
      'os_template_apply',
      orderId,
      { templateId },
    );
    return updated;
  }

  // ===================== Agenda / Agendamento de itens =====================

  /**
   * Retorna os itens com agendamento no período informado, enriquecidos com
   * dados da OS (número, status, cliente). Chamado pelo ScheduleModule.
   */
  async getAgendaItems(
    user: AuthUser,
    opts: { from: Date; to: Date; assignedTo?: string },
  ) {
    return this.tenant.withTenantTx(() =>
      this.repo.getScheduledItems({
        from: opts.from,
        to: opts.to,
        assignedTo: opts.assignedTo,
      }),
    );
  }

  /**
   * Agenda/atribui um item de OS: define técnico, horário de início e duração
   * estimada. Calcula `scheduled_end = start + duration` e verifica conflito de
   * agenda para o técnico antes de persistir. Chamado pelo ScheduleModule.
   */
  async scheduleItem(
    user: AuthUser,
    orderId: string,
    itemId: string,
    opts: {
      assignedTo?: string | null;
      scheduledStart?: string | null;
      estimatedDuration?: number | null;
    },
  ) {
    return this.tenant.withTenantTx(async () => {
      const item = await this.repo.findItemById(itemId);
      if (!item || item.order_id !== orderId)
        throw new NotFoundException('Item não encontrado.');

      const start = opts.scheduledStart ? new Date(opts.scheduledStart) : null;
      const duration = opts.estimatedDuration ?? null;
      const end =
        start && duration ? new Date(start.getTime() + duration * 60_000) : null;
      const assignedTo =
        opts.assignedTo !== undefined ? opts.assignedTo : item.assigned_to;

      // Checagem de conflito: só quando há técnico + janela de tempo definidos.
      if (assignedTo && start && end) {
        const conflicts = await this.repo.findConflicts(assignedTo, start, end, itemId);
        if (conflicts.length > 0) {
          throw new BadRequestException(
            `Conflito de agenda: técnico já tem ${conflicts.length} item(ns) no mesmo horário.`,
          );
        }
      }

      return this.repo.updateItemSchedule(itemId, {
        assigned_to: opts.assignedTo,
        scheduled_start: start,
        estimated_duration: duration,
        scheduled_end: end,
      });
    });
  }

  /** Remove atribuição e agendamento de um item. Chamado pelo ScheduleModule. */
  async unscheduleItem(user: AuthUser, orderId: string, itemId: string) {
    return this.tenant.withTenantTx(async () => {
      const item = await this.repo.findItemById(itemId);
      if (!item || item.order_id !== orderId)
        throw new NotFoundException('Item não encontrado.');
      return this.repo.updateItemSchedule(itemId, {
        assigned_to: null,
        scheduled_start: null,
        estimated_duration: null,
        scheduled_end: null,
      });
    });
  }

  // ===================== Internos =====================
  /** Recalcula e persiste total = Σ(itens.total) − desconto do cabeçalho (≥0). Dentro de tx. */
  private async recomputeTotal(orderId: string) {
    const order = await this.repo.findOrderById(orderId);
    if (!order) return;
    const itemsTotal = order.items.reduce((acc, it) => acc + toNum(it.total), 0);
    const total = Math.max(0, itemsTotal - toNum(order.discount));
    await this.repo.setTotal(orderId, total);
  }

  /**
   * Resolve se o cargo do usuário tem uma permissão (role/role_permission/permission
   * são tabelas globais sem RLS — mesma consulta do PermissionsGuard).
   */
  private async userHasPermission(
    user: AuthUser,
    perm: string,
  ): Promise<boolean> {
    const db = this.tenant.getClient();
    const rows = await db.$queryRaw<Array<{ key: string }>>`
      SELECT p.key FROM role r
      JOIN role_permission rp ON rp.role_id = r.id
      JOIN permission p ON p.id = rp.permission_id
      WHERE r.key = ${user.role} AND p.key = ${perm}
      LIMIT 1
    `;
    return rows.length > 0;
  }
}
