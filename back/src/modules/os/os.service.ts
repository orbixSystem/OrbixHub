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

/**
 * Máquina de estados do workflow da OS (FSM pura). Cada chave lista os destinos
 * válidos; `entregue`/`cancelada` são terminais (sem destinos).
 */
const TRANSITIONS: Record<OsStatus, OsStatus[]> = {
  aberta: ['aguardando_aprovacao', 'em_execucao', 'cancelada'],
  aguardando_aprovacao: ['aprovada', 'aberta', 'cancelada'],
  aprovada: ['em_execucao', 'cancelada'],
  em_execucao: ['concluida', 'cancelada'],
  concluida: ['entregue'],
  entregue: [],
  cancelada: [],
};

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

  async updateOrder(user: AuthUser, id: string, dto: UpdateOrderDto) {
    const order = await this.tenant.withTenantTx(async () => {
      const existing = await this.repo.findOrderById(id);
      if (!existing || existing.deleted_at)
        throw new NotFoundException('OS não encontrada.');
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

    // Confere que a OS existe / não está deletada ANTES do upload (sua própria tx).
    await this.getOrderOrThrow(orderId);

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
        message: STATUS_LABELS[to],
        visiblePublic: true,
        createdBy: user.userId,
      });
    });
    await this.audit.log(user.tenantId, user.userId, 'os_status_change', id, {
      from,
      to,
    });

    // Baixa de estoque na conclusão — FORA de qualquer withTenantTx
    // (decrementStock abre sua própria tx via runWithTenant; aninhar esgota o pool).
    if (to === 'concluida' && !order.stock_applied) {
      await this.applyStock(user, id);
    }

    return this.getOrderOrThrow(id);
  }

  /**
   * Baixa de estoque dos itens-produto vinculados ao inventário (idempotente via
   * stock_applied). v1 best-effort: erro num item (ex.: estoque insuficiente) NÃO
   * bloqueia a conclusão — apenas loga um aviso. Roda fora de transação de banco.
   */
  private async applyStock(user: AuthUser, orderId: string) {
    const order = await this.getOrderOrThrow(orderId);
    if (order.stock_applied) return;
    for (const item of order.items) {
      if (item.kind !== 'product' || !item.inventory_item_id) continue;
      try {
        await this.inventory.decrementStock(
          user.tenantId,
          item.inventory_item_id,
          toNum(item.quantity),
        );
      } catch (e) {
        this.logger.warn(
          `Baixa de estoque falhou (OS ${orderId}, item ${item.id}): ${
            (e as Error).message
          }`,
        );
      }
    }
    await this.tenant.withTenantTx(() =>
      this.repo.setStatusFields(orderId, { stock_applied: true }),
    );
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
    return result;
  }

  async updateItem(
    user: AuthUser,
    orderId: string,
    itemId: string,
    dto: UpdateItemDto,
  ) {
    return this.tenant.withTenantTx(async () => {
      const order = await this.repo.findOrderById(orderId);
      if (!order || order.deleted_at)
        throw new NotFoundException('OS não encontrada.');
      const existing = await this.repo.findItemById(itemId);
      if (!existing || existing.order_id !== orderId)
        throw new NotFoundException('Item não encontrado.');

      const quantity =
        dto.quantity ?? toNum(existing.quantity);
      const unitPrice =
        dto.unitPrice ?? toNum(existing.unit_price);
      const discount = dto.discount ?? toNum(existing.discount);
      const total = Math.max(0, quantity * unitPrice - discount);

      const data: Record<string, unknown> = { total };
      if (dto.name !== undefined) data.name = dto.name.trim();
      if (dto.quantity !== undefined) data.quantity = dto.quantity;
      if (dto.unitPrice !== undefined) data.unit_price = dto.unitPrice;
      if (dto.discount !== undefined) data.discount = dto.discount;

      const item = await this.repo.updateItem(itemId, data);
      await this.recomputeTotal(orderId);
      return item;
    });
  }

  async deleteItem(user: AuthUser, orderId: string, itemId: string) {
    return this.tenant.withTenantTx(async () => {
      const order = await this.repo.findOrderById(orderId);
      if (!order || order.deleted_at)
        throw new NotFoundException('OS não encontrada.');
      const existing = await this.repo.findItemById(itemId);
      if (!existing || existing.order_id !== orderId)
        throw new NotFoundException('Item não encontrado.');
      await this.repo.deleteItem(itemId);
      await this.recomputeTotal(orderId);
      return { id: itemId, deleted: true };
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
