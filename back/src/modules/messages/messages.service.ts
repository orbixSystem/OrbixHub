import { BadRequestException, Injectable } from '@nestjs/common';
import type { AuthUser } from '../../common/auth/auth.types';
import { TenantContext } from '../../common/database/tenant-context';
import { NotificationsService } from '../notifications/notifications.service';
import { MessagesRepository } from './messages.repository';

export interface CreateConversationInput {
  refType: string;
  refId: string;
  title?: string;
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
  ) {}

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
      });
    });
  }

  /** Resolve a conversa de um contexto (tenant explícito — fluxos públicos/jobs). */
  async findByRef(tenantId: string, refType: string, refId: string) {
    return this.tenant.runWithTenant(tenantId, () =>
      this.repo.findConversationByRef(tenantId, refType, refId),
    );
  }

  /** Inbox: todas as conversas do tenant (mais recente no topo) + última mensagem. */
  async listConversations(user: AuthUser) {
    return this.tenant.withTenantTx(() =>
      this.repo.listConversations(user.tenantId),
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
    return this.tenant.withTenantTx(async () => {
      await this.repo.getConversationOrThrow(convId);
      const message = await this.repo.addMessage(user.tenantId, convId, {
        sender: 'staff',
        authorName: 'Equipe',
        body: text,
        createdBy: user.userId,
      });
      await this.repo.touchConversation(convId, { lastMessageAt: new Date() });
      return message;
    });
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
    // Notificação FORA da tx acima (própria tx).
    await this.notifications.notify(tenantId, {
      type: 'message',
      title: 'Nova mensagem do cliente',
      body: text.slice(0, 80),
      refType: 'message',
      refId: conversationId,
    });
    return message;
  }
}
