import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { TenantContext } from '../../common/database/tenant-context';
import { IamService } from '../iam/iam.service';
import { MessagesService } from '../messages/messages.service';
import { OsRepository } from './os.repository';
import { OsStatus } from './dto/order.dto';

/** ref_type do contexto de conversa de uma OS (módulo genérico `messages`). */
const OS_REF_TYPE = 'os';

/** Rótulos PT-BR dos status (espelha STATUS_LABELS do OsService). */
const STATUS_LABELS: Record<string, string> = {
  aberta: 'OS aberta',
  aguardando_aprovacao: 'Aguardando aprovação',
  aprovada: 'Orçamento aprovado',
  em_execucao: 'Em execução',
  concluida: 'Serviço concluído',
  entregue: 'Veículo entregue',
  cancelada: 'OS cancelada',
};

interface ResolvedToken {
  tenantId: string;
  orderId: string;
}

/**
 * Acompanhamento público da OS (página de tracking + chat do cliente), SEM auth.
 *
 * Toda resolução de tenant/OS vem do `public_token` via a função `SECURITY DEFINER`
 * `os_resolve_by_public_token` — NUNCA confiando em input do cliente (regra de ouro
 * de fluxos públicos). O resto roda em `runWithTenant(tenantId, ...)` (tenant
 * explícito, sem CLS de JWT). O payload é DELIBERADAMENTE mínimo: nunca expõe
 * itens, preços, totais, telefone do cliente, queixa nem notas internas (o
 * diagnóstico, sim — é a informação que o cliente quer ver).
 */
@Injectable()
export class OsPublicService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tenant: TenantContext,
    private readonly repo: OsRepository,
    private readonly messages: MessagesService,
    private readonly iam: IamService,
  ) {}

  /**
   * Resolve o token público → { tenantId, orderId } via função SECURITY DEFINER,
   * pelo cliente base (SEM contexto de tenant — a função roda como app_owner).
   * Token inválido / OS deletada → 404.
   */
  private async resolveToken(token: string): Promise<ResolvedToken> {
    if (!token || !/^[0-9a-f-]{36}$/i.test(token)) {
      throw new NotFoundException('Acompanhamento não encontrado.');
    }
    const rows = await this.prisma.$queryRaw<
      Array<{ tenant_id: string; order_id: string }>
    >`SELECT tenant_id, order_id FROM os_resolve_by_public_token(${token}::uuid)`;
    const row = rows[0];
    if (!row) throw new NotFoundException('Acompanhamento não encontrado.');
    return { tenantId: row.tenant_id, orderId: row.order_id };
  }

  /**
   * Payload público read-only: status + previsão + diagnóstico + fotos + timeline
   * (só eventos visible_public, mais recente no topo) + dados da empresa. NÃO inclui
   * itens, preços, totais, queixa, telefone nem notas internas.
   */
  async getPublicTrack(token: string) {
    const { tenantId, orderId } = await this.resolveToken(token);
    // Nome da empresa: tabela global `tenant` (sem RLS) — leitura direta pelo client base.
    const company = await this.prisma.tenant.findUnique({
      where: { id: tenantId },
      select: { name: true },
    });

    const { assignedTo, ...payload } = await this.tenant.runWithTenant(
      tenantId,
      async () => {
        const order = await this.repo.findOrderById(orderId);
        if (!order || order.deleted_at) {
          throw new NotFoundException('Acompanhamento não encontrado.');
        }
        const [events, photos] = await Promise.all([
          this.repo.listEvents(orderId),
          this.repo.listPhotos(orderId),
        ]);
        const status = order.status as OsStatus;
        return {
          number: order.number,
          status,
          statusLabel: STATUS_LABELS[status] ?? status,
          diagnosis: order.diagnosis ?? null,
          subjectLabel: order.subject_label,
          scheduledEnd: order.scheduled_end,
          photos: photos.map((p) => ({ url: p.url, caption: p.caption })),
          timeline: events
            .filter((e) => e.visible_public)
            .map((e) => ({
              kind: e.kind,
              message: e.message,
              statusSnapshot: e.status_snapshot,
              createdAt: e.created_at,
            })),
          company: company ? { name: company.name } : undefined,
          // mantido só p/ resolver o nome FORA da tx (desestruturado abaixo).
          assignedTo: order.assigned_to,
        };
      },
    );

    // Nome do responsável resolvido AO VIVO (troca de mecânico reflete sozinha)
    // via service público do IAM — FORA da tx acima (resolveMemberName abre a
    // própria via runWithTenant; aninhar esgotaria o pool). "Aponta, não invade":
    // a OS guarda só o user_id; o nome vem do módulo dono (IAM).
    const responsibleName = assignedTo
      ? await this.iam.resolveMemberName(tenantId, assignedTo)
      : null;

    return { ...payload, responsibleName };
  }

  /**
   * Resolve o token público → { tenantId, conversationId } da conversa da OS.
   * Usado pela camada de realtime (WebSocket) para autorizar a sala de um cliente
   * público SEM auth — a sala vem do token resolvido no servidor, nunca de input
   * do cliente. Token inválido → null (não lança).
   */
  async resolveConversationByToken(
    token: string,
  ): Promise<{ tenantId: string; conversationId: string } | null> {
    try {
      const { tenantId, orderId } = await this.resolveToken(token);
      const conversationId = await this.resolveConversationId(tenantId, orderId);
      return { tenantId, conversationId };
    } catch {
      return null;
    }
  }

  /** Resolve (ou cria) a conversa da OS para um tenant já resolvido. */
  private async resolveConversationId(
    tenantId: string,
    orderId: string,
  ): Promise<string> {
    const existing = await this.messages.findByRef(tenantId, OS_REF_TYPE, orderId);
    if (existing) return existing.id;
    const created = await this.messages.createConversation(tenantId, {
      refType: OS_REF_TYPE,
      refId: orderId,
    });
    return created.id;
  }

  /** Página padrão do chat público (rota polled a cada 15s — nunca sem limite). */
  private static readonly PUBLIC_THREAD_PAGE = 50;

  /**
   * Mensagens do chat (lado cliente), ordem cronológica — PAGINADA por cursor:
   * sem `before` = as 50 mais recentes; com `before` (ISO da mais antiga
   * carregada) = página anterior.
   */
  async getPublicMessages(token: string, before?: string) {
    const cursor = before ? new Date(before) : undefined;
    if (cursor && Number.isNaN(cursor.getTime())) {
      throw new BadRequestException('Cursor `before` inválido.');
    }
    const take = OsPublicService.PUBLIC_THREAD_PAGE;
    const { tenantId, orderId } = await this.resolveToken(token);
    const conversationId = await this.resolveConversationId(tenantId, orderId);
    const page = await this.tenant.runWithTenant(tenantId, () =>
      this.listMessages(conversationId, { before: cursor, take: take + 1 }),
    );
    const messages = page.slice(0, take).reverse(); // asc p/ exibição
    if (!cursor) {
      // O cliente está vendo a conversa: marca as respostas do staff como
      // lidas (recibo de leitura no inbox). Fora da tx acima.
      await this.messages.markStaffMessagesRead(tenantId, conversationId);
    }
    // Shape mantido como ARRAY (compat com o app público atual). O cliente
    // infere "há mais antigas" quando a página vem cheia (length == 50).
    return messages.map((m) => ({
      sender: m.sender,
      authorName: m.author_name,
      body: m.body,
      createdAt: m.created_at,
      // Recibo de leitura: a oficina já leu esta mensagem do cliente?
      readAt: m.read_at,
    }));
  }

  private listMessages(
    conversationId: string,
    opts: { before?: Date; take: number },
  ) {
    const db = this.tenant.getClient();
    return db.message.findMany({
      where: {
        conversation_id: conversationId,
        ...(opts.before ? { created_at: { lt: opts.before } } : {}),
      },
      orderBy: { created_at: 'desc' },
      take: opts.take,
    });
  }

  /**
   * Mensagem do cliente pelo link público. Resolve OS → conversa e delega ao
   * MessagesService.postCustomerMessage (incrementa staff_unread + cria notificação).
   */
  async postPublicMessage(token: string, body: string, authorName?: string) {
    const text = body?.trim();
    if (!text) throw new BadRequestException('A mensagem não pode ser vazia.');
    if (text.length > 2000) {
      throw new BadRequestException('Mensagem muito longa (máx. 2000).');
    }
    const { tenantId, orderId } = await this.resolveToken(token);
    const conversationId = await this.resolveConversationId(tenantId, orderId);
    const message = await this.messages.postCustomerMessage(
      tenantId,
      conversationId,
      text,
      authorName,
    );
    return {
      sender: message.sender,
      authorName: message.author_name,
      body: message.body,
      createdAt: message.created_at,
    };
  }
}
