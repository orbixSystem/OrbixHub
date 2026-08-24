import {
  BadRequestException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { ENV } from '../../common/config/config.module';
import type { Env } from '../../common/config/env.schema';
import { MailerService } from '../../common/mailer/mailer.service';
import { AuditService } from '../../common/audit/audit.service';
import { TenancyService } from '../tenancy/tenancy.service';
import { SupportRepository } from './support.repository';
import type { AuthUser } from '../../common/auth/auth.types';
import {
  SUPPORT_CHANGED_EVENT,
  type SupportChangeKind,
  type SupportChangedEvent,
} from './support.events';

/**
 * Situações de um chamado.
 *
 * `reabertura_solicitada` existe porque fechar é decisão da Orbix: antes, uma
 * mensagem do cliente num chamado resolvido o reabria sozinha, e quem fechou
 * perdia o controle do que estava fechado. Agora o cliente PEDE, o pedido fica
 * visível como pendência, e reabrir continua sendo um ato de quem atende.
 */
export const STATUS_ABERTO = 'aberto';
export const STATUS_RESOLVIDO = 'resolvido';
export const STATUS_REABERTURA = 'reabertura_solicitada';

export interface SupportMessageView {
  id: string;
  body: string;
  fromOrbix: boolean;
  authorName: string | null;
  createdAt: Date;
}

export interface SupportTicketView {
  id: string;
  subject: string;
  status: string;
  lastMessageAt: Date;
  createdAt: Date;
  naoLidas: number;
}

@Injectable()
export class SupportService {
  private readonly logger = new Logger(SupportService.name);

  static readonly MAX_BODY = 4000;
  static readonly MAX_SUBJECT = 120;

  constructor(
    private readonly repo: SupportRepository,
    private readonly mailer: MailerService,
    private readonly tenancy: TenancyService,
    private readonly audit: AuditService,
    private readonly events: EventEmitter2,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /** Avisa as telas abertas dos dois lados. Fora de qualquer transação. */
  private avisar(
    tenantId: string,
    ticketId: string,
    kind: SupportChangeKind,
    daOrbix: boolean,
  ): void {
    const evt: SupportChangedEvent = { tenantId, ticketId, kind, daOrbix };
    this.events.emit(SUPPORT_CHANGED_EVENT, evt);
  }

  async tickets(user: AuthUser): Promise<SupportTicketView[]> {
    const rows = await this.repo.listarTickets(user.tenantId);
    return rows.map((t) => ({
      id: t.id,
      subject: t.subject,
      status: t.status,
      lastMessageAt: t.last_message_at,
      createdAt: t.created_at,
      naoLidas: t.naoLidas,
    }));
  }

  /**
   * Mensagens de um chamado. Abrir o chamado É a leitura — marcar aqui evita
   * que o ponto de não lida fique mentindo depois que a pessoa já leu.
   */
  async mensagens(user: AuthUser, ticketId: string): Promise<SupportMessageView[]> {
    await this.assertTicket(user, ticketId);
    const rows = await this.repo.mensagens(user.tenantId, ticketId);
    await this.repo.marcarLidas(user.tenantId, ticketId, true);
    return rows.map(toView);
  }

  naoLidas(user: AuthUser): Promise<number> {
    return this.repo.naoLidasPeloCliente(user.tenantId);
  }

  /** Abre um chamado com a primeira mensagem — chamado vazio não serve a ninguém. */
  async abrir(
    user: AuthUser,
    subject: string,
    body: string,
  ): Promise<SupportTicketView> {
    const assunto = (subject ?? '').trim();
    if (!assunto) throw new BadRequestException('Dê um assunto ao chamado.');
    if (assunto.length > SupportService.MAX_SUBJECT) {
      throw new BadRequestException(
        `Assunto muito longo (máximo ${SupportService.MAX_SUBJECT} caracteres).`,
      );
    }
    const texto = this.validarCorpo(body);

    const ticket = await this.repo.criarTicket(user.tenantId, assunto, user.userId);
    await this.repo.criarMensagem(user.tenantId, {
      ticketId: ticket.id,
      body: texto,
      fromOrbix: false,
      authorUserId: user.userId,
    });

    await this.audit.log(user.tenantId, user.userId, 'support_message', ticket.id, {
      assunto,
    });
    await this.avisarOrbix(user, assunto, texto);
    this.avisar(user.tenantId, ticket.id, 'aberto', false);

    const lista = await this.tickets(user);
    return lista.find((t) => t.id === ticket.id)!;
  }

  /**
   * Responde num chamado existente.
   *
   * Chamado FECHADO não aceita resposta solta: o caminho é `solicitarReabertura`,
   * que registra um pedido visível para quem atende. Deixar a mensagem entrar e
   * reabrir sozinho tirava da Orbix o controle sobre o que está fechado.
   */
  async responder(
    user: AuthUser,
    ticketId: string,
    body: string,
  ): Promise<SupportMessageView> {
    const ticket = await this.assertTicket(user, ticketId);
    if (ticket.status === STATUS_RESOLVIDO) {
      throw new BadRequestException(
        'Este chamado está fechado. Peça a reabertura para continuar.',
      );
    }
    const texto = this.validarCorpo(body);

    const criada = await this.repo.criarMensagem(user.tenantId, {
      ticketId,
      body: texto,
      fromOrbix: false,
      authorUserId: user.userId,
    });

    await this.audit.log(user.tenantId, user.userId, 'support_message', ticketId);
    await this.avisarOrbix(user, ticket.subject, texto);
    this.avisar(user.tenantId, ticketId, 'mensagem', false);
    return toView(criada);
  }

  /**
   * O cliente pede a reabertura de um chamado fechado, dizendo por quê.
   *
   * O pedido entra como mensagem (o contexto não se perde) e muda o status para
   * `reabertura_solicitada` — que aparece no painel como pendência. Quem reabre
   * de fato continua sendo a Orbix.
   */
  async solicitarReabertura(
    user: AuthUser,
    ticketId: string,
    body: string,
  ): Promise<SupportTicketView> {
    const ticket = await this.assertTicket(user, ticketId);
    if (ticket.status === STATUS_ABERTO) {
      throw new BadRequestException('Este chamado já está aberto.');
    }
    const texto = this.validarCorpo(body);

    await this.repo.criarMensagem(user.tenantId, {
      ticketId,
      body: texto,
      fromOrbix: false,
      authorUserId: user.userId,
    });
    await this.repo.definirStatus(user.tenantId, ticketId, STATUS_REABERTURA);

    await this.audit.log(user.tenantId, user.userId, 'support_message', ticketId, {
      status: STATUS_REABERTURA,
    });
    await this.avisarOrbix(user, `Reabertura pedida — ${ticket.subject}`, texto);
    this.avisar(user.tenantId, ticketId, 'status', false);

    const lista = await this.tickets(user);
    return lista.find((t) => t.id === ticketId)!;
  }

  /** O cliente pode encerrar o que ele mesmo abriu — e reabrir escrevendo de novo. */
  async resolver(user: AuthUser, ticketId: string): Promise<void> {
    await this.assertTicket(user, ticketId);
    await this.repo.definirStatus(user.tenantId, ticketId, STATUS_RESOLVIDO);
    await this.audit.log(user.tenantId, user.userId, 'support_message', ticketId, {
      status: STATUS_RESOLVIDO,
    });
    this.avisar(user.tenantId, ticketId, 'status', false);
  }

  // ------------------------------------------------------------------
  // Lado da Orbix (sistema de admin). Não recebe `AuthUser` porque quem
  // atende não é usuário do tenant — quem prova a identidade é o token de
  // serviço, no guard da rota administrativa. A RLS continua valendo: tudo
  // aqui passa pelo repositório, sempre sob `runWithTenant`.
  // ------------------------------------------------------------------

  async ticketsDoTenant(tenantId: string): Promise<SupportTicketView[]> {
    const rows = await this.repo.listarTickets(tenantId, true);
    return rows.map((t) => ({
      id: t.id,
      subject: t.subject,
      status: t.status,
      lastMessageAt: t.last_message_at,
      createdAt: t.created_at,
      naoLidas: t.naoLidas,
    }));
  }

  /** Abrir o chamado no admin marca as mensagens do cliente como lidas. */
  async mensagensParaOrbix(
    tenantId: string,
    ticketId: string,
  ): Promise<SupportMessageView[]> {
    await this.assertTicketDoTenant(tenantId, ticketId);
    const rows = await this.repo.mensagens(tenantId, ticketId);
    await this.repo.marcarLidas(tenantId, ticketId, false);
    return rows.map(toView);
  }

  /**
   * Resposta da Orbix. `autor` é quem atendeu, e vai junto na mensagem: o
   * cliente merece saber com quem falou, e nós, quem respondeu o quê.
   */
  async responderComoOrbix(
    tenantId: string,
    ticketId: string,
    body: string,
    autor: string,
  ): Promise<SupportMessageView> {
    await this.assertTicketDoTenant(tenantId, ticketId);
    const texto = this.validarCorpo(body);

    const criada = await this.repo.criarMensagem(tenantId, {
      ticketId,
      body: texto,
      fromOrbix: true,
      // `author_user_id` fica nulo de propósito: quem respondeu não é usuário
      // deste tenant, e apontar para um id que não existe lá seria mentira.
      authorUserId: null,
      authorName: autor,
    });

    await this.audit.log(tenantId, null, 'support_message', ticketId, {
      por: 'orbix-admin',
      autor,
    });
    this.avisar(tenantId, ticketId, 'mensagem', true);
    return toView(criada);
  }

  /**
   * Reabre um chamado encerrado.
   *
   * Fechar e reabrir são decisões de gente, sempre — nada aqui encerra chamado
   * sozinho, e nenhum job mexe em `status`. A única mudança automática é o
   * contrário: mensagem nova do cliente reabre, porque quem volta a escrever
   * está dizendo que não estava resolvido.
   */
  async reabrirComoOrbix(tenantId: string, ticketId: string): Promise<void> {
    await this.assertTicketDoTenant(tenantId, ticketId);
    await this.repo.definirStatus(tenantId, ticketId, STATUS_ABERTO);
    await this.audit.log(tenantId, null, 'support_message', ticketId, {
      status: STATUS_ABERTO,
      por: 'orbix-admin',
    });
    this.avisar(tenantId, ticketId, 'status', true);
  }

  async resolverComoOrbix(tenantId: string, ticketId: string): Promise<void> {
    await this.assertTicketDoTenant(tenantId, ticketId);
    await this.repo.definirStatus(tenantId, ticketId, STATUS_RESOLVIDO);
    await this.audit.log(tenantId, null, 'support_message', ticketId, {
      status: STATUS_RESOLVIDO,
      por: 'orbix-admin',
    });
    this.avisar(tenantId, ticketId, 'status', true);
  }

  private async assertTicketDoTenant(tenantId: string, ticketId: string) {
    const t = await this.repo.acharTicket(tenantId, ticketId);
    if (!t) throw new NotFoundException('Chamado não encontrado.');
    return t;
  }

  private validarCorpo(body: string): string {
    const texto = (body ?? '').trim();
    if (!texto) throw new BadRequestException('Escreva sua mensagem.');
    if (texto.length > SupportService.MAX_BODY) {
      throw new BadRequestException(
        `Mensagem muito longa (máximo ${SupportService.MAX_BODY} caracteres).`,
      );
    }
    return texto;
  }

  /**
   * O chamado é do tenant do usuário? A RLS já impediria ler de outro, mas o
   * 404 explícito evita devolver "vazio" quando o id simplesmente não existe.
   */
  private async assertTicket(user: AuthUser, ticketId: string) {
    const t = await this.repo.acharTicket(user.tenantId, ticketId);
    if (!t) throw new NotFoundException('Chamado não encontrado.');
    return t;
  }

  /**
   * Avisa a Orbix por e-mail. Ponte provisória até o sistema de admin existir;
   * depois vira redundância bem-vinda. Sem `SUPPORT_EMAIL`, não envia e não
   * quebra — a mensagem já está gravada.
   */
  private async avisarOrbix(
    user: AuthUser,
    assunto: string,
    texto: string,
  ): Promise<void> {
    const para = this.env.SUPPORT_EMAIL;
    if (!para) return;

    try {
      const empresa = await this.tenancy.getCompanyView(user.tenantId);
      const nomeEmpresa =
        (empresa.companyName as string | undefined) ??
        (empresa.legalName as string | undefined) ??
        user.tenantId;

      await this.mailer.sendMessage({
        to: para,
        subject: `[Suporte] ${nomeEmpresa} — ${assunto}`,
        // Responder do próprio cliente de e-mail chega em quem pediu ajuda.
        replyTo: empresa.email as string | undefined,
        fromName: 'OrbixHub — Suporte',
        text: `${nomeEmpresa} escreveu no chamado "${assunto}":\n\n${texto}\n\ntenant: ${user.tenantId}`,
        html:
          `<p><strong>${escapeHtml(nomeEmpresa)}</strong> escreveu no chamado ` +
          `<strong>${escapeHtml(assunto)}</strong>:</p>` +
          `<blockquote style="border-left:3px solid #ccc;padding-left:12px;white-space:pre-wrap">${escapeHtml(texto)}</blockquote>` +
          `<p style="color:#888;font-size:12px">tenant: ${user.tenantId}</p>`,
      });
    } catch (err) {
      // Best-effort: a mensagem já está salva. Derrubar o request faria o
      // cliente achar que não enviou, e reenviar.
      this.logger.warn(`[support] aviso por e-mail falhou: ${String(err)}`);
    }
  }
}

function toView(r: {
  id: string;
  body: string;
  from_orbix: boolean;
  author_name: string | null;
  created_at: Date;
}): SupportMessageView {
  return {
    id: r.id,
    body: r.body,
    fromOrbix: r.from_orbix,
    authorName: r.author_name,
    createdAt: r.created_at,
  };
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
