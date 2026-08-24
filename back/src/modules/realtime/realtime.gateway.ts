import { Inject, Logger } from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import {
  MessageBody,
  ConnectedSocket,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import type { Server, Socket } from 'socket.io';
import { createHash, timingSafeEqual } from 'node:crypto';
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
import {
  SUPPORT_CHANGED_EVENT,
  type SupportChangedEvent,
} from '../support/support.events';
import { ENV } from '../../common/config/config.module';
import type { Env } from '../../common/config/env.schema';

/**
 * Origens permitidas para o socket, a MESMA lista do HTTP (`CORS_ORIGINS`).
 *
 * Lida de `process.env` porque o decorator roda antes de existir injeção — é o
 * mesmo caminho que o `main.ts` usa. Antes aqui era `origin: true`, que reflete
 * qualquer site; não vazava sozinho (toda sala exige token no `emit`, nunca
 * credencial de navegador), mas era política mais frouxa que a do HTTP sem
 * motivo. Cliente nativo não manda `Origin` e não é afetado.
 */
const ORIGENS = (process.env.CORS_ORIGINS ?? '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

/**
 * Tentativas de entrada FALHAS que uma conexão pode gastar antes de cair, e
 * quantas um IP pode gastar na janela.
 *
 * O throttler do HTTP não enxerga o socket: sem isto, `subscribe:*` era um
 * oráculo ilimitado — dava para tentar o token de serviço, ou o token de um
 * link público, milhares de vezes por segundo numa conexão só, de graça.
 *
 * Contagem em memória: hoje a API roda num processo só. Com mais de uma
 * instância isto vira Redis, como o throttler do HTTP já é.
 */
const MAX_FALHAS_POR_SOCKET = 10;
const MAX_FALHAS_POR_IP = 30;
const JANELA_MS = 60_000;

const convRoom = (conversationId: string) => `conv:${conversationId}`;
const tenantRoom = (tenantId: string) => `tenant:${tenantId}`;
/** Sala única do painel da Orbix — atravessa tenants, e por isso exige o token de serviço. */
const ORBIX_ROOM = 'orbix:suporte';

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
@WebSocketGateway({
  cors: { origin: ORIGENS.length ? ORIGENS : false, credentials: true },
})
export class RealtimeGateway {
  private readonly logger = new Logger(RealtimeGateway.name);

  /** Falhas por IP na janela corrente. Limpa sozinho quando a janela vira. */
  private readonly falhasPorIp = new Map<string, { n: number; ate: number }>();

  @WebSocketServer() server!: Server;

  constructor(
    private readonly osPublic: OsPublicService,
    private readonly messages: MessagesService,
    private readonly tokens: AccessTokenService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /**
   * O painel da Orbix entra na sala de suporte com o TOKEN DE SERVIÇO — o mesmo
   * de `ADMIN_API_TOKEN`. É a única sala que atravessa tenants, então a régua é
   * a credencial de máquina, nunca um JWT de usuário.
   *
   * Comparação em tempo constante: o tempo de resposta não pode virar oráculo
   * para adivinhar o token byte a byte.
   */
  @SubscribeMessage('subscribe:orbix')
  subscribeOrbix(
    @MessageBody() data: { token?: string },
    @ConnectedSocket() client: Socket,
  ): { ok: boolean } {
    if (this.excedeu(client)) return { ok: false };
    const esperado = this.env.ADMIN_API_TOKEN;
    const veio = data?.token ?? '';
    if (!esperado || !igualEmTempoConstante(veio, esperado)) {
      return this.falhou(client);
    }
    void client.join(ORBIX_ROOM);
    return { ok: true };
  }

  /**
   * Push: chamado de suporte mudou → sala do TENANT (app do cliente) e sala da
   * Orbix (painel). Os dois lados recebem o MESMO evento; cada um decide o que
   * recarregar — o payload é só id + o que mudou.
   */
  @OnEvent(SUPPORT_CHANGED_EVENT)
  handleSupportChanged(evt: SupportChangedEvent) {
    if (!this.server) return;
    const payload = {
      ticketId: evt.ticketId,
      kind: evt.kind,
      daOrbix: evt.daOrbix,
    };
    this.server.to(tenantRoom(evt.tenantId)).emit('support', payload);
    this.server
      .to(ORBIX_ROOM)
      .emit('support', { ...payload, tenantId: evt.tenantId });
  }

  /**
   * Cliente público (sem auth) entra na sala da sua OS via o TOKEN do link. O
   * servidor resolve token → conversa (SECURITY DEFINER); token inválido → ack erro.
   */
  @SubscribeMessage('subscribe:public')
  async subscribePublic(
    @MessageBody() data: { token?: string },
    @ConnectedSocket() client: Socket,
  ): Promise<{ ok: boolean }> {
    if (this.excedeu(client)) return { ok: false };
    const token = data?.token?.trim();
    if (!token) return this.falhou(client);
    const resolved = await this.osPublic.resolveConversationByToken(token);
    if (!resolved) return this.falhou(client);
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
    if (this.excedeu(client)) return { ok: false };
    const accessToken = data?.accessToken?.trim();
    if (!accessToken) return this.falhou(client);
    let tenantId: string;
    try {
      tenantId = this.tokens.verify(accessToken).tid;
    } catch {
      return this.falhou(client);
    }
    if (!tenantId) return this.falhou(client);
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

  // ---------------------------------------------------------- limite de erro

  /** Já gastou o que tinha? Então nem vale a pena comparar segredo. */
  private excedeu(client: Socket): boolean {
    const porSocket = (client.data.falhas as number | undefined) ?? 0;
    if (porSocket >= MAX_FALHAS_POR_SOCKET) return true;

    const reg = this.falhasPorIp.get(ipDe(client));
    return Boolean(reg && reg.ate > Date.now() && reg.n >= MAX_FALHAS_POR_IP);
  }

  /**
   * Conta a falha e responde a recusa. Estourou a cota do socket, ele CAI —
   * reconectar custa handshake, e é isso que transforma "tentativas infinitas
   * de graça" em algo que a cota por IP alcança.
   */
  private falhou(client: Socket): { ok: false } {
    const n = ((client.data.falhas as number | undefined) ?? 0) + 1;
    client.data.falhas = n;

    const ip = ipDe(client);
    const agora = Date.now();
    const reg = this.falhasPorIp.get(ip);
    if (reg && reg.ate > agora) reg.n += 1;
    else this.falhasPorIp.set(ip, { n: 1, ate: agora + JANELA_MS });

    if (n >= MAX_FALHAS_POR_SOCKET) {
      this.logger.warn(`[realtime] ${n} tentativas falhas de ${ip} — derrubando`);
      client.disconnect(true);
    }
    // A janela é curta e o mapa pequeno; a limpeza acompanha a escrita para não
    // depender de um job só para isto.
    if (this.falhasPorIp.size > 5_000) {
      for (const [k, v] of this.falhasPorIp) if (v.ate <= agora) this.falhasPorIp.delete(k);
    }
    return { ok: false };
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

/**
 * IP do cliente. Atrás do nginx, `X-Forwarded-For` chega como
 * `<cliente>, <proxy...>` — mas o cabeçalho que o cliente mandou fica NA
 * FRENTE, então o valor confiável é o ÚLTIMO, escrito pelo nosso proxy.
 * Confiar no primeiro deixaria qualquer um trocar de "IP" a cada tentativa.
 */
function ipDe(client: Socket): string {
  const xff = client.handshake.headers['x-forwarded-for'];
  const lista = Array.isArray(xff) ? xff.join(',') : (xff ?? '');
  const ultimo = lista.split(',').map((p) => p.trim()).filter(Boolean).at(-1);
  return ultimo || client.handshake.address || 'desconhecido';
}

/**
 * Comparação de segredo sem vazar tamanho nem posição da diferença pelo tempo.
 * `timingSafeEqual` exige buffers do mesmo tamanho, então o hash normaliza.
 */
function igualEmTempoConstante(a: string, b: string): boolean {
  const ha = createHash('sha256').update(a).digest();
  const hb = createHash('sha256').update(b).digest();
  return timingSafeEqual(ha, hb);
}
