import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { TenantContext } from '../../common/database/tenant-context';
import { IamService } from '../iam/iam.service';
import { MessagesService } from '../messages/messages.service';
import { OsRepository } from './os.repository';
import { OsStatus } from './dto/order.dto';
import { VocabularyService } from '../../verticals/vocabulary.service';

/** ref_type do contexto de conversa de uma OS (módulo genérico `messages`). */
const OS_REF_TYPE = 'os';

/**
 * PISO dos rótulos de status. O texto real vem do pacote da vertical do tenant
 * — e aqui isso importa mais que em qualquer outro lugar: esta é a tela que o
 * CLIENTE FINAL abre. Uma clínica de fisioterapia mandando "Veículo entregue"
 * para o paciente dela era o vazamento mais visível do sistema.
 */
const STATUS_LABELS_FALLBACK: Record<string, string> = {
  aberta: 'OS aberta',
  aguardando_aprovacao: 'Aguardando aprovação',
  aprovada: 'Orçamento aprovado',
  em_execucao: 'Em execução',
  concluida: 'Serviço concluído',
  entregue: 'Serviço entregue',
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
 * explícito, sem CLS de JWT). O payload é público mas controlado: expõe o
 * orçamento (itens, preços, totais) e o diagnóstico — informações que o
 * cliente precisa ver para aprovar. Nunca expõe telefone, queixa nem notas
 * internas.
 */
@Injectable()
export class OsPublicService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tenant: TenantContext,
    private readonly repo: OsRepository,
    private readonly messages: MessagesService,
    private readonly iam: IamService,
    private readonly vocabulary: VocabularyService,
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
   * Payload público read-only: status + previsão + diagnóstico + orçamento
   * (itens/serviços/peças com nome, qtd, preço e total) + fotos + timeline
   * (só eventos visible_public, mais recente no topo) + dados da empresa.
   * NÃO inclui queixa, telefone nem notas internas.
   */
  async getPublicTrack(token: string) {
    const { tenantId, orderId } = await this.resolveToken(token);
    // Nome da empresa + nicho: tabela global `tenant` (sem RLS) — leitura direta
    // pelo client base. O `vertical` entra no MESMO select de propósito: este é
    // um fluxo público, sem JWT, e uma consulta a mais por acesso de cliente
    // final não se paga. O vocabulário resolvido daqui é o que o cliente lê.
    const company = await this.prisma.tenant.findUnique({
      where: { id: tenantId },
      select: { name: true, vertical: true },
    });
    const vocab = this.vocabulary.vocab(company?.vertical ?? null);

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
        const photoUrlById = new Map(photos.map((p) => [p.id, p.url]));
        return {
          number: order.number,
          status,
          statusLabel: vocab[`os.status.${status}`] ?? STATUS_LABELS_FALLBACK[status] ?? status,
          diagnosis: order.diagnosis ?? null,
          subjectLabel: order.subject_label,
          scheduledEnd: order.scheduled_end,
          // Orçamento: nome, qtd, preço unitário, desconto e total de cada item.
          // O cliente precisa ver o que vai pagar ANTES de aprovar.
          items: (order.items ?? []).map((it) => ({
            kind: it.kind,
            name: it.name,
            quantity: Number(it.quantity),
            unitPrice: Number(it.unit_price),
            discount: Number(it.discount),
            total: Number(it.total),
          })),
          total: (order.items ?? []).reduce(
            (sum, it) => sum + Number(it.total),
            0,
          ),
          // id exposto para o cliente citar/comentar a foto (uuid, não sensível).
          photos: photos.map((p) => ({
            id: p.id,
            url: p.url,
            caption: p.caption,
          })),
          timeline: events
            .filter((e) => e.visible_public)
            .map((e) => ({
              kind: e.kind,
              message: e.message,
              statusSnapshot: e.status_snapshot,
              createdAt: e.created_at,
              // A FOTO no próprio evento. A coluna `photo_id` já era gravada
              // no upload, mas nunca saía daqui: a timeline do cliente dizia
              // "Foto adicionada" em texto puro e a imagem ficava numa galeria
              // à parte, desligada do momento em que foi tirada. Resolvido o
              // id para url aqui (a foto já é pública nesta página — não expõe
              // nada novo).
              photoUrl: e.photo_id ? photoUrlById.get(e.photo_id) ?? null : null,
            })),
          company: company ? { name: company.name } : undefined,
          // Vocabulário do nicho para a PÁGINA PÚBLICA. Ela não tem sessão, então
          // não pode resolver isso sozinha — e é justamente onde mais importa:
          // é o cliente final da empresa que lê. Sem isto, a clínica dizia
          // "Seu veículo está com a equipe" para o paciente dela.
          vocab: {
            objeto: vocab['objeto.singular'] ?? 'item',
            objetoPlural: vocab['objeto.plural'] ?? 'itens',
          },
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
    // Busca a página E anexa o preview da citação dentro do MESMO contexto de
    // tenant (previewByIds usa getClient — precisa da tx).
    const messages = await this.tenant.runWithTenant(tenantId, async () => {
      const page = await this.listMessages(conversationId, {
        before: cursor,
        take: take + 1,
      });
      const ordered = page.slice(0, take).reverse(); // asc p/ exibição
      return this.messages.attachReplyPreviews(ordered);
    });
    if (!cursor) {
      // O cliente está vendo a conversa: marca as respostas do staff como
      // lidas (recibo de leitura no inbox). Fora da tx acima.
      await this.messages.markStaffMessagesRead(tenantId, conversationId);
    }
    // Shape mantido como ARRAY (compat com o app público atual). O cliente
    // infere "há mais antigas" quando a página vem cheia (length == 50).
    return messages.map((m) => ({
      // id exposto p/ o cliente poder responder (citar) uma mensagem.
      id: m.id,
      sender: m.sender,
      authorName: m.author_name,
      body: m.body,
      createdAt: m.created_at,
      // Recibo de leitura: a oficina já leu esta mensagem do cliente?
      readAt: m.read_at,
      // Citação (estilo WhatsApp): mensagem respondida + foto da OS citada.
      replyTo: m.replyTo,
      photoUrl: m.photo_url,
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
  async postPublicMessage(
    token: string,
    dto: { body: string; authorName?: string; replyToId?: string; photoId?: string },
  ) {
    const text = dto.body?.trim();
    if (!text) throw new BadRequestException('A mensagem não pode ser vazia.');
    if (text.length > 2000) {
      throw new BadRequestException('Mensagem muito longa (máx. 2000).');
    }
    const { tenantId, orderId } = await this.resolveToken(token);
    const conversationId = await this.resolveConversationId(tenantId, orderId);

    // Foto citada: resolve a URL a partir do id, SÓ se a foto for desta OS
    // (nunca confia em url do cliente — evita injeção de imagem arbitrária).
    let photoId: string | null = null;
    let photoUrl: string | null = null;
    if (dto.photoId) {
      const photo = await this.tenant.runWithTenant(tenantId, () =>
        this.repo.findPhotoById(dto.photoId!),
      );
      if (photo && photo.order_id === orderId) {
        photoId = photo.id;
        photoUrl = photo.url;
      }
    }

    const message = await this.messages.postCustomerMessage(
      tenantId,
      conversationId,
      text,
      dto.authorName,
      { replyToId: dto.replyToId, photoId, photoUrl },
    );
    return {
      id: message.id,
      sender: message.sender,
      authorName: message.author_name,
      body: message.body,
      createdAt: message.created_at,
      photoUrl: message.photo_url,
    };
  }

  // ---- Comentários das fotos (cliente, sem auth) ----

  /**
   * Resolve o token + garante que a foto pertence à OS do link (tenant-scoped).
   * Foto de outra OS/tenant → 404. Retorna { tenantId, photoId }.
   */
  private async resolvePhoto(token: string, photoId: string) {
    if (!photoId || !/^[0-9a-f-]{36}$/i.test(photoId)) {
      throw new NotFoundException('Foto não encontrada.');
    }
    const { tenantId, orderId } = await this.resolveToken(token);
    const ok = await this.tenant.runWithTenant(tenantId, async () => {
      const photo = await this.repo.findPhotoById(photoId);
      return photo != null && photo.order_id === orderId;
    });
    if (!ok) throw new NotFoundException('Foto não encontrada.');
    return { tenantId, photoId };
  }

  async getPublicPhotoComments(token: string, photoId: string) {
    const { tenantId } = await this.resolvePhoto(token, photoId);
    const comments = await this.tenant.runWithTenant(tenantId, () =>
      this.repo.listPhotoComments(photoId),
    );
    return comments.map((c) => ({
      authorKind: c.author_kind,
      authorName: c.author_name,
      body: c.body,
      createdAt: c.created_at,
    }));
  }

  async addPublicPhotoComment(
    token: string,
    photoId: string,
    body: string,
    authorName?: string,
  ) {
    const text = body?.trim();
    if (!text) throw new BadRequestException('O comentário não pode ser vazio.');
    if (text.length > 2000) {
      throw new BadRequestException('Comentário muito longo (máx. 2000).');
    }
    const { tenantId } = await this.resolvePhoto(token, photoId);
    const created = await this.tenant.runWithTenant(tenantId, () =>
      this.repo.addPhotoComment(tenantId, {
        photoId,
        authorKind: 'customer',
        authorName: authorName?.trim() || null,
        body: text,
      }),
    );
    return {
      authorKind: created.author_kind,
      authorName: created.author_name,
      body: created.body,
      createdAt: created.created_at,
    };
  }
}
