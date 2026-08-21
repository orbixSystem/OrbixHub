import { BadRequestException, Inject, Injectable, Logger } from '@nestjs/common';
import { ENV } from '../../common/config/config.module';
import type { Env } from '../../common/config/env.schema';
import { MailerService } from '../../common/mailer/mailer.service';
import { AuditService } from '../../common/audit/audit.service';
import { TenancyService } from '../tenancy/tenancy.service';
import { SupportRepository } from './support.repository';
import type { AuthUser } from '../../common/auth/auth.types';

/** Uma mensagem da thread, como a tela precisa vê-la. */
export interface SupportMessageView {
  id: string;
  body: string;
  fromOrbix: boolean;
  authorName: string | null;
  createdAt: Date;
}

@Injectable()
export class SupportService {
  private readonly logger = new Logger(SupportService.name);

  /** Corpo maior que isto é quase sempre log colado — pede anexo, não campo. */
  static readonly MAX_BODY = 4000;

  constructor(
    private readonly repo: SupportRepository,
    private readonly mailer: MailerService,
    private readonly tenancy: TenancyService,
    private readonly audit: AuditService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /**
   * Thread do tenant. Ler marca as mensagens da Orbix como lidas — abrir a tela
   * É a leitura; exigir um clique a mais só faria o badge mentir.
   */
  async thread(user: AuthUser): Promise<SupportMessageView[]> {
    const rows = await this.repo.listar(user.tenantId);
    await this.repo.marcarLidas(user.tenantId, true);
    return rows.map((r) => ({
      id: r.id,
      body: r.body,
      fromOrbix: r.from_orbix,
      authorName: r.author_name,
      createdAt: r.created_at,
    }));
  }

  naoLidas(user: AuthUser): Promise<number> {
    return this.repo.naoLidasPeloCliente(user.tenantId);
  }

  /**
   * Cliente escreve para o suporte.
   *
   * Grava primeiro e avisa depois: o e-mail é I/O externo e não pode fazer a
   * mensagem se perder se o SMTP estiver fora. Falha de envio é logada e
   * engolida — a mensagem já está salva e o admin a lerá de qualquer forma.
   */
  async enviar(user: AuthUser, body: string): Promise<SupportMessageView> {
    const texto = body?.trim() ?? '';
    if (!texto) throw new BadRequestException('Escreva sua mensagem.');
    if (texto.length > SupportService.MAX_BODY) {
      throw new BadRequestException(
        `Mensagem muito longa (máximo ${SupportService.MAX_BODY} caracteres).`,
      );
    }

    const empresa = await this.tenancy.getCompanyView(user.tenantId);
    const autor = (empresa.contatoNome as string | undefined) ?? null;

    const criada = await this.repo.criar(user.tenantId, {
      body: texto,
      fromOrbix: false,
      authorUserId: user.userId,
      authorName: autor,
    });

    await this.audit.log(user.tenantId, user.userId, 'support_message', criada.id);
    await this.avisarOrbix(user, texto, empresa);

    return {
      id: criada.id,
      body: criada.body,
      fromOrbix: criada.from_orbix,
      authorName: criada.author_name,
      createdAt: criada.created_at,
    };
  }

  /**
   * Avisa a Orbix por e-mail. É uma ponte provisória: enquanto o sistema de
   * admin não existe, é assim que a mensagem chega em alguém. Quando o admin
   * existir, ele lê a thread direto e este e-mail vira redundância bem-vinda.
   *
   * Sem `SUPPORT_EMAIL` configurado, não envia e não quebra — a mensagem já
   * está gravada.
   */
  private async avisarOrbix(
    user: AuthUser,
    texto: string,
    empresa: Record<string, unknown>,
  ): Promise<void> {
    const para = this.env.SUPPORT_EMAIL;
    if (!para) return;

    const nomeEmpresa =
      (empresa.companyName as string | undefined) ??
      (empresa.legalName as string | undefined) ??
      user.tenantId;
    const emailEmpresa = empresa.email as string | undefined;

    try {
      await this.mailer.sendMessage({
        to: para,
        subject: `[Suporte] ${nomeEmpresa}`,
        // replyTo no e-mail da empresa: responder do próprio cliente de e-mail
        // chega em quem pediu ajuda, sem passar pelo sistema.
        replyTo: emailEmpresa,
        fromName: 'OrbixHub — Suporte',
        text: `${nomeEmpresa} escreveu para o suporte:\n\n${texto}\n\ntenant: ${user.tenantId}`,
        html:
          `<p><strong>${escapeHtml(nomeEmpresa)}</strong> escreveu para o suporte:</p>` +
          `<blockquote style="border-left:3px solid #ccc;padding-left:12px;white-space:pre-wrap">${escapeHtml(texto)}</blockquote>` +
          `<p style="color:#888;font-size:12px">tenant: ${user.tenantId}</p>`,
      });
    } catch (err) {
      // Best-effort: a mensagem já está salva. Derrubar o request aqui faria o
      // cliente achar que não enviou, e reenviar.
      this.logger.warn(`[support] aviso por e-mail falhou: ${String(err)}`);
    }
  }
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
