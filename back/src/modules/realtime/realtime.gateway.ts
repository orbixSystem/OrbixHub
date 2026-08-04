import { Logger } from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import {
  MessageBody,
  ConnectedSocket,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import type { Server, Socket } from 'socket.io';
import { AccessTokenService } from '../../common/auth/jwt.service';
import {
  OS_CHANGED_EVENT,
  type OsChangedEvent,
} from '../os/os.events';
import {
  MESSAGE_CREATED_EVENT,
  MessageCreatedEvent,
  MessagesService,
} from '../messages/messages.service';
import { OsPublicService } from '../os/os-public.service';

const convRoom = (conversationId: string) => `conv:${conversationId}`;
const tenantRoom = (tenantId: string) => `tenant:${tenantId}`;

/**
 * Gateway de tempo real (socket.io). Faz push de novas mensagens para duas salas:
 * - `conv:<conversationId>` — cliente público (link de acompanhamento) e a thread
 *   aberta no staff. A sala vem SEMPRE resolvida no servidor (token público ou
 *   conversa validada no tenant do JWT) — nunca de input cru do cliente.
 * - `tenant:<tenantId>` — inbox do staff (atualiza a lista/contadores a cada msg).
 *
 * Não toca o banco diretamente: ouve o evento de domínio `message.created`
 * (emitido pelo MessagesService FORA da tx) e reemite via socket. CORS reflete a
 * origem (mesma app); os dados já são gated por token/JWT no momento do subscribe.
 */
@WebSocketGateway({ cors: { origin: true, credentials: true } })
export class RealtimeGateway {
  private readonly logger = new Logger(RealtimeGateway.name);

  @WebSocketServer() server!: Server;

  constructor(
    private readonly osPublic: OsPublicService,
    private readonly messages: MessagesService,
    private readonly tokens: AccessTokenService,
  ) {}

  /**
   * Cliente público (sem auth) entra na sala da sua OS via o TOKEN do link. O
   * servidor resolve token → conversa (SECURITY DEFINER); token inválido → ack erro.
   */
  @SubscribeMessage('subscribe:public')
  async subscribePublic(
    @MessageBody() data: { token?: string },
    @ConnectedSocket() client: Socket,
  ): Promise<{ ok: boolean }> {
    const token = data?.token?.trim();
    if (!token) return { ok: false };
    const resolved = await this.osPublic.resolveConversationByToken(token);
    if (!resolved) return { ok: false };
    await client.join(convRoom(resolved.conversationId));
    return { ok: true };
  }

  /**
   * Staff (com JWT) entra na sala do seu tenant (inbox) e, se informar uma conversa
   * válida do tenant, também na sala da conversa (thread aberta). Token inválido →
   * ack erro.
   */
  @SubscribeMessage('subscribe:staff')
  async subscribeStaff(
    @MessageBody() data: { accessToken?: string; conversationId?: string },
    @ConnectedSocket() client: Socket,
  ): Promise<{ ok: boolean }> {
    const accessToken = data?.accessToken?.trim();
    if (!accessToken) return { ok: false };
    let tenantId: string;
    try {
      tenantId = this.tokens.verify(accessToken).tid;
    } catch {
      return { ok: false };
    }
    if (!tenantId) return { ok: false };
    await client.join(tenantRoom(tenantId));

    const conversationId = data?.conversationId?.trim();
    if (conversationId) {
      const belongs = await this.messages.conversationBelongsToTenant(
        tenantId,
        conversationId,
      );
      if (belongs) await client.join(convRoom(conversationId));
    }
    return { ok: true };
  }

  /**
   * Push: a OS mudou → sala do TENANT (todas as telas de staff abertas).
   *
   * Vai só para o tenant, não para a sala pública: o link do cliente é assunto
   * separado e ainda não assina isto. O payload é mínimo (id + o que mudou) —
   * quem recebe recarrega pela API, para não existir uma segunda fonte de verdade
   * viajando pelo socket.
   */
  @OnEvent(OS_CHANGED_EVENT)
  handleOsChanged(evt: OsChangedEvent) {
    if (!this.server) return;
    this.server
        .to(tenantRoom(evt.tenantId))
        .emit('os', { orderId: evt.orderId, kind: evt.kind });
  }

  /** Push: nova mensagem → sala da conversa (cliente/thread) + sala do tenant (inbox). */
  @OnEvent(MESSAGE_CREATED_EVENT)
  handleMessageCreated(evt: MessageCreatedEvent) {
    if (!this.server) return;
    const payload = { conversationId: evt.conversationId, ...evt.message };
    this.server.to(convRoom(evt.conversationId)).emit('message', payload);
    this.server.to(tenantRoom(evt.tenantId)).emit('message', payload);
  }
}
