import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { TenantContext } from '../../common/database/tenant-context';
import {
  ChangeCursor,
  ChangedSincePage,
  queryChangedSince,
} from '../../common/database/changed-since';

/** Entidades do módulo messages expostas ao pull de sync offline (só leitura). */
export type MessagesSyncEntity = 'conversation' | 'message';

/**
 * `conversation` e `message` não têm `updated_at` próprio — ambas viajam pelo
 * `created_at` (imutável): a conversa nasce uma vez e as mensagens são
 * append-only, como `service_order_event`/`service_order_photo` no módulo os.
 * (Mudanças de `last_message_at`/`staff_unread`/`read_at` não re-emergem no pull;
 * o histórico offline é de LEITURA — enviar mensagem continua online.)
 */
const SYNC_ENTITY_COLUMN: Record<MessagesSyncEntity, 'updated_at' | 'created_at'> =
  {
    conversation: 'created_at',
    message: 'created_at',
  };

export interface CreateConversationData {
  refType: string;
  refId: string;
  title?: string | null;
  refLabel?: string | null;
  channel?: string;
}

export interface AddMessageData {
  sender: 'customer' | 'staff';
  authorName?: string | null;
  body: string;
  createdBy?: string | null;
  /** Resposta a outra mensagem (quote, estilo WhatsApp) — id da mensagem citada. */
  replyToId?: string | null;
  /** Foto da OS citada (ponteiro puro) + snapshot da url p/ a bolha. */
  photoId?: string | null;
  photoUrl?: string | null;
}

/** Preview de uma mensagem citada (reply-to). */
export interface PreviewRow {
  id: string;
  sender: string;
  author_name: string | null;
  body: string;
}

/**
 * Único ponto que toca `conversation` + `message` (tenant-scoped, RLS+FORCE). Sempre
 * via `tenant.getClient()` (cliente tx-scoped); o service abre o
 * `withTenantTx`/`runWithTenant`. tenant_id nunca vem do cliente — vem do CLS/JWT.
 */
@Injectable()
export class MessagesRepository {
  constructor(private readonly tenant: TenantContext) {}

  createConversation(tenantId: string, data: CreateConversationData) {
    const db = this.tenant.getClient();
    return db.conversation.create({
      data: {
        tenant_id: tenantId,
        ref_type: data.refType,
        ref_id: data.refId,
        title: data.title ?? null,
        ref_label: data.refLabel ?? null,
        channel: data.channel ?? 'public_link',
      },
    });
  }

  findConversationByRef(_tenantId: string, refType: string, refId: string) {
    const db = this.tenant.getClient();
    return db.conversation.findFirst({ where: { ref_type: refType, ref_id: refId } });
  }

  findConversationById(id: string) {
    const db = this.tenant.getClient();
    return db.conversation.findUnique({ where: { id } });
  }

  async getConversationOrThrow(id: string) {
    const conv = await this.findConversationById(id);
    if (!conv) throw new NotFoundException('Conversa não encontrada.');
    return conv;
  }

  /**
   * Inbox PAGINADO: conversas (mais recente por last_message_at) + última mensagem
   * embutida + busca opcional (título/rótulo). Retorna a página + total para o
   * scroll infinito. Desempate estável por `id`.
   */
  async listConversations(
    _tenantId: string,
    filter: { q?: string; skip: number; take: number },
  ) {
    const db = this.tenant.getClient();
    const where: Prisma.conversationWhereInput = filter.q
      ? {
          OR: [
            { title: { contains: filter.q, mode: 'insensitive' } },
            { ref_label: { contains: filter.q, mode: 'insensitive' } },
          ],
        }
      : {};
    const [items, total] = await Promise.all([
      db.conversation.findMany({
        where,
        orderBy: [
          { last_message_at: 'desc' },
          { created_at: 'desc' },
          { id: 'desc' },
        ],
        skip: filter.skip,
        take: filter.take,
        include: {
          messages: { orderBy: { created_at: 'desc' }, take: 1 },
        },
      }),
      db.conversation.count({ where }),
    ]);
    return { items, total };
  }

  addMessage(tenantId: string, convId: string, data: AddMessageData) {
    const db = this.tenant.getClient();
    return db.message.create({
      data: {
        tenant_id: tenantId,
        conversation_id: convId,
        sender: data.sender,
        author_name: data.authorName ?? null,
        body: data.body,
        created_by: data.createdBy ?? null,
        reply_to_id: data.replyToId ?? null,
        photo_id: data.photoId ?? null,
        photo_url: data.photoUrl ?? null,
      },
    });
  }

  /** True se a mensagem existe e pertence à conversa dada (valida citação). */
  async messageBelongsToConversation(messageId: string, convId: string) {
    const db = this.tenant.getClient();
    const found = await db.message.findFirst({
      where: { id: messageId, conversation_id: convId },
      select: { id: true },
    });
    return found != null;
  }

  /** Preview das mensagens citadas (reply-to): id → { sender, authorName, body }. */
  async previewByIds(ids: string[]) {
    if (ids.length === 0) return new Map<string, PreviewRow>();
    const db = this.tenant.getClient();
    const rows = await db.message.findMany({
      where: { id: { in: ids } },
      select: { id: true, sender: true, author_name: true, body: true },
    });
    return new Map<string, PreviewRow>(rows.map((r) => [r.id, r]));
  }

  /**
   * Página de mensagens por CURSOR (threads crescem para sempre — nunca sem
   * limite). Busca as `take` mais recentes antes de [before] (exclusivo), em
   * ordem DESC; o service reverte para asc e calcula hasMore pedindo take+1.
   */
  listMessagesPage(convId: string, opts: { before?: Date; take: number }) {
    const db = this.tenant.getClient();
    return db.message.findMany({
      where: {
        conversation_id: convId,
        ...(opts.before ? { created_at: { lt: opts.before } } : {}),
      },
      orderBy: { created_at: 'desc' },
      take: opts.take,
    });
  }

  touchConversation(
    convId: string,
    opts: { lastMessageAt: Date; incStaffUnread?: boolean },
  ) {
    const db = this.tenant.getClient();
    return db.conversation.update({
      where: { id: convId },
      data: {
        last_message_at: opts.lastMessageAt,
        ...(opts.incStaffUnread ? { staff_unread: { increment: 1 } } : {}),
      },
    });
  }

  resetStaffUnread(convId: string) {
    const db = this.tenant.getClient();
    return db.conversation.update({
      where: { id: convId },
      data: { staff_unread: 0 },
    });
  }

  /** Marca como lidas as mensagens do cliente ainda não lidas (staff abriu a thread). */
  markMessagesRead(convId: string) {
    const db = this.tenant.getClient();
    return db.message.updateMany({
      where: { conversation_id: convId, sender: 'customer', read_at: null },
      data: { read_at: new Date() },
    });
  }

  /** Marca como lidas as mensagens do staff ainda não lidas (cliente abriu o link). */
  markStaffMessagesRead(convId: string) {
    const db = this.tenant.getClient();
    return db.message.updateMany({
      where: { conversation_id: convId, sender: 'staff', read_at: null },
      data: { read_at: new Date() },
    });
  }

  // ---- sync pull (offline) ----
  /**
   * Página de mudanças de `conversation`/`message` desde o cursor. Sync pull
   * — ver `common/database/changed-since.ts`. Cliente tx-scoped sob RLS.
   */
  listChangedSince(
    table: MessagesSyncEntity,
    cursor: ChangeCursor | null,
    limit: number,
  ): Promise<ChangedSincePage> {
    const db = this.tenant.getClient();
    return queryChangedSince(db, table, SYNC_ENTITY_COLUMN[table], cursor, limit);
  }
}
