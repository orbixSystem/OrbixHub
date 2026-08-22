import {
  BadRequestException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ENV } from '../../common/config/config.module';
import type { Env } from '../../common/config/env.schema';
import { MailerService } from '../../common/mailer/mailer.service';
import { AuditService } from '../../common/audit/audit.service';
import { TenancyService } from '../tenancy/tenancy.service';
import { SupportRepository } from './support.repository';
import type { AuthUser } from '../../common/auth/auth.types';

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
    @Inject(ENV) private readonly env: Env,
  ) {}

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

    const lista = await this.tickets(user);
    return lista.find((t) => t.id === ticket.id)!;
  }

  /** Responde num chamado existente. */
  async responder(
    user: AuthUser,
    ticketId: string,
    body: string,
  ): Promise<SupportMessageView> {
    const ticket = await this.assertTicket(user, ticketId);
    const texto = this.validarCorpo(body);

    const criada = await this.repo.criarMensagem(user.tenantId, {
      ticketId,
      body: texto,
      fromOrbix: false,
      authorUserId: user.userId,
    });

    await this.audit.log(user.tenantId, user.userId, 'support_message', ticketId);
    await this.avisarOrbix(user, ticket.subject, texto);
    return toView(criada);
  }

  /** O cliente pode encerrar o que ele mesmo abriu — e reabrir escrevendo de novo. */
  async resolver(user: AuthUser, ticketId: string): Promise<void> {
    await this.assertTicket(user, ticketId);
    await this.repo.definirStatus(user.tenantId, ticketId, 'resolvido');
    await this.audit.log(user.tenantId, user.userId, 'support_message', ticketId, {
      status: 'resolvido',
    });
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
