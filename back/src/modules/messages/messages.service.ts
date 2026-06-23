import { BadRequestException, Injectable } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import type { AuthUser } from '../../common/auth/auth.types';
import { TenantContext } from '../../common/database/tenant-context';
import { NotificationsService } from '../notifications/notifications.service';
import { MessagesRepository } from './messages.repository';

export interface CreateConversationInput {
  refType: string;
  refId: string;
  title?: string;
  /** Rótulo legível da origem (snapshot), ex.: número da OS 'OS-0001'. */
  refLabel?: string;
}

/** Nome do evento de domínio emitido a cada nova mensagem (ouvido pelo realtime). */
export const MESSAGE_CREATED_EVENT = 'message.created';

/** Payload do evento `message.created` (push em tempo real via WebSocket). */
export interface MessageCreatedEvent {
  tenantId: string;
  conversationId: string;
  message: {
    sender: string;
    authorName: string | null;
    body: string;
    createdAt: Date;
  };
}

/**
 * Módulo de mensagens genérico: conversas/mensagens com contexto via ref_type/ref_id
 * (hoje só 'os', mas serve a qualquer módulo). "Aponta, não invade": quem precisa de
 * uma conversa chama este service público com o id da sua entidade (ref_id) — nunca
 * toca as tabelas conversation/message diretamente.
 */
@Injectable()
export class MessagesService {
  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: MessagesRepository,
    private readonly notifications: NotificationsService,
    private readonly events: EventEmitter2,
  ) {}

  /**
   * Emite o evento de domínio de nova mensagem (push em tempo real). Chamado FORA
   * de qualquer transação de banco (o listener do realtime não deve segurar o pool).
   * best-effort: falha de emissão nunca quebra o fluxo de mensagem.
   */
  private emitMessageCreated(
    tenantId: string,
    conversationId: string,
    msg: { sender: string; author_name: string | null; body: string; created_at: Date },
  ) {
    const payload: MessageCreatedEvent = {
      tenantId,
      conversationId,
      message: {
        sender: msg.sender,
        authorName: msg.author_name,
        body: msg.body,
        createdAt: msg.created_at,
      },
    };
    this.events.emit(MESSAGE_CREATED_EVENT, payload);
  }

  /**
   * Valida que uma conversa pertence ao tenant (fluxos com tenant explícito, ex.:
   * autorização de sala WebSocket do staff). Tenant via `runWithTenant` (RLS).
   */
  async conversationBelongsToTenant(
    tenantId: string,
    conversationId: string,
  ): Promise<boolean> {
    return this.tenant.runWithTenant(tenantId, async () => {
      const conv = await this.repo.findConversationById(conversationId);
      return !!conv;
    });
  }

  /**
   * Idempotente em (refType, refId): se já existe uma conversa para o contexto,
   * retorna-a; senão cria. Usado pelo OS ao abrir uma OS (tenant explícito —
   * roda em sua própria tx via runWithTenant, fora da tx da OS).
   */
  async createConversation(tenantId: string, input: CreateConversationInput) {
    return this.tenant.runWithTenant(tenantId, async () => {
      const existing = await this.repo.findConversationByRef(
        tenantId,
        input.refType,
        input.refId,
      );
      if (existing) return existing;
      return this.repo.createConversation(tenantId, {
        refType: input.refType,
        refId: input.refId,
        title: input.title?.trim() || null,
        refLabel: input.refLabel?.trim() || null,
      });
    });
  }

  /** Resolve a conversa de um contexto (tenant explícito — fluxos públicos/jobs). */
  async findByRef(tenantId: string, refType: string, refId: string) {
    return this.tenant.runWithTenant(tenantId, () =>
      this.repo.findConversationByRef(tenantId, refType, refId),
    );
  }

  /**
   * Inbox: todas as conversas do tenant (mais recente no topo) + prévia da última
   * mensagem (corpo, remetente e se já foi lida). O `last_message_read` só faz
   * sentido quando a última mensagem é do staff (recibo de leitura estilo WhatsApp:
   * o cliente já viu a resposta).
   */
  async listConversations(
    user: AuthUser,
    query: { q?: string; page?: number; pageSize?: number } = {},
  ) {
    const page = query.page ?? 1;
    const pageSize = query.pageSize ?? 30;
    const { items, total } = await this.tenant.withTenantTx(() =>
      this.repo.listConversations(user.tenantId, {
        q: query.q?.trim() || undefined,
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
    );
    const mapped = items.map((c) => {
      const last = c.messages?.[0];
      return {
        id: c.id,
        title: c.title,
        ref_label: c.ref_label,
        ref_type: c.ref_type,
        ref_id: c.ref_id,
        staff_unread: c.staff_unread,
        last_message_at: c.last_message_at,
        last_message: last?.body ?? null,
        last_message_sender: last?.sender ?? null,
        last_message_read: last ? last.read_at != null : false,
      };
    });
    return { items: mapped, total, page, pageSize };
  }

  /**
   * O cliente abriu o link público e viu a conversa: marca as mensagens do staff
   * como lidas (alimenta o recibo de leitura no inbox). Tenant explícito (fluxo
   * público, sem CLS) — roda em sua própria tx via runWithTenant.
   */
  async markStaffMessagesRead(tenantId: string, convId: string) {
    return this.tenant.runWithTenant(tenantId, () =>
      this.repo.markStaffMessagesRead(convId),
    );
  }

  /**
   * Thread completa. Ao abrir, o staff "leu": zera staff_unread e marca como lidas
   * as mensagens pendentes do cliente.
   */
  async getThread(user: AuthUser, convId: string) {
    return this.tenant.withTenantTx(async () => {
      const conversation = await this.repo.getConversationOrThrow(convId);
      await this.repo.resetStaffUnread(convId);
      await this.repo.markMessagesRead(convId);
      const messages = await this.repo.listMessages(convId);
      return { conversation: { ...conversation, staff_unread: 0 }, messages };
    });
  }

  /**
   * Mensagem do staff. author_name = 'Equipe' (o AccessToken não carrega o nome do
   * usuário); createdBy = userId. NÃO incrementa staff_unread (o staff está lendo).
   */
  async postStaffMessage(user: AuthUser, convId: string, body: string) {
    const text = body?.trim();
    if (!text) throw new BadRequestException('Mensagem não pode ser vazia.');
    const message = await this.tenant.withTenantTx(async () => {
      await this.repo.getConversationOrThrow(convId);
      const created = await this.repo.addMessage(user.tenantId, convId, {
        sender: 'staff',
        authorName: 'Equipe',
        body: text,
        createdBy: user.userId,
      });
      await this.repo.touchConversation(convId, { lastMessageAt: new Date() });
      return created;
    });
    // Push em tempo real — FORA da tx (o cliente público vê a resposta na hora).
    this.emitMessageCreated(user.tenantId, convId, message);
    return message;
  }

  /** Zera só o contador de não-lidas do staff (marcação explícita de "lido"). */
  async markRead(user: AuthUser, convId: string) {
    await this.tenant.withTenantTx(async () => {
      await this.repo.getConversationOrThrow(convId);
      await this.repo.resetStaffUnread(convId);
      await this.repo.markMessagesRead(convId);
    });
    return { id: convId, read: true };
  }

  /**
   * Mensagem do cliente (lado público — a ser chamada pelo endpoint público da Fase 5).
   * tenant explícito + runWithTenant (sem CLS no fluxo público). Incrementa
   * staff_unread e dispara uma notificação tenant-wide. A notificação é criada FORA
   * da tx da mensagem (NotificationsService.notify abre sua própria tx via
   * runWithTenant; aninhar transações esgotaria o pool).
   */
  async postCustomerMessage(
    tenantId: string,
    conversationId: string,
    body: string,
    authorName?: string,
  ) {
    const text = body?.trim();
    if (!text) throw new BadRequestException('Mensagem não pode ser vazia.');
    const message = await this.tenant.runWithTenant(tenantId, async () => {
      const conversation = await this.repo.getConversationOrThrow(conversationId);
      // Sem nome digitado: atribui ao cliente da OS (o título da conversa é o
      // nome do cliente). Assim a mensagem é creditada sem o cliente digitar nada.
      const resolvedName = authorName?.trim() || conversation.title || null;
      const created = await this.repo.addMessage(tenantId, conversationId, {
        sender: 'customer',
        authorName: resolvedName,
        body: text,
      });
      await this.repo.touchConversation(conversationId, {
        lastMessageAt: new Date(),
        incStaffUnread: true,
      });
      return created;
    });
    // Notificação FORA da tx acima (própria tx). O título carrega o nome do
    // cliente (snapshot do autor da mensagem) para o staff identificar a origem
    // sem abrir a conversa; o corpo é o texto da mensagem.
    const senderName = message.author_name?.trim();
    await this.notifications.notify(tenantId, {
      type: 'message',
      title: senderName
        ? `Nova mensagem de ${senderName}`
        : 'Nova mensagem do cliente',
      body: text.slice(0, 80),
      refType: 'message',
      refId: conversationId,
    });
    // Push em tempo real — staff vê a mensagem do cliente na hora.
    this.emitMessageCreated(tenantId, conversationId, message);
    return message;
  }
}
