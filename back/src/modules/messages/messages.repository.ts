import { Injectable, NotFoundException } from '@nestjs/common';
import { TenantContext } from '../../common/database/tenant-context';

export interface CreateConversationData {
  refType: string;
  refId: string;
  title?: string | null;
  channel?: string;
}

export interface AddMessageData {
  sender: 'customer' | 'staff';
  authorName?: string | null;
  body: string;
  createdBy?: string | null;
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

  /** Inbox: conversas (mais recente por last_message_at) + última mensagem embutida. */
  async listConversations(_tenantId: string) {
    const db = this.tenant.getClient();
    return db.conversation.findMany({
      orderBy: [{ last_message_at: 'desc' }, { created_at: 'desc' }],
      include: {
        messages: { orderBy: { created_at: 'desc' }, take: 1 },
      },
    });
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
      },
    });
  }

  listMessages(convId: string) {
    const db = this.tenant.getClient();
    return db.message.findMany({
      where: { conversation_id: convId },
      orderBy: { created_at: 'asc' },
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
}
