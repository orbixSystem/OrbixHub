import { Inject, Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { createTransport, type Transporter } from 'nodemailer';
import { ENV } from '../config/config.module';
import { Env } from '../config/env.schema';
import { renderVerificationEmail } from './mail-templates';
import { MailMessage, MailerService, VerificationEmail } from './mailer.service';

/**
 * Envio real por SMTP (Google Workspace: smtp.gmail.com:587 + STARTTLS,
 * autenticado com senha de app). Ativado por MAIL_TRANSPORT=smtp.
 *
 * Erros NÃO são engolidos aqui — quem chama decide. Os fluxos de identidade já
 * capturam a falha de propósito (cadastro/convite não podem ser desfeitos por
 * uma queda do SMTP), e o envio sempre acontece FORA de transação de banco.
 */
@Injectable()
export class SmtpMailerService extends MailerService implements OnModuleInit {
  private readonly log = new Logger('SmtpMailer');
  private readonly transporter: Transporter;

  constructor(@Inject(ENV) private readonly env: Env) {
    super();
    this.transporter = createTransport({
      host: env.SMTP_HOST,
      port: env.SMTP_PORT,
      secure: env.SMTP_SECURE, // 587 → false (STARTTLS); 465 → true
      auth: { user: env.SMTP_USER, pass: env.SMTP_PASS },
    });
  }

  /**
   * Falha cedo e alto: sem credencial, todo e-mail sairia silenciosamente pelo
   * ralo (os chamadores engolem exceção) e ninguém descobriria até um cliente
   * reclamar que o "esqueci a senha" nunca chega.
   */
  onModuleInit(): void {
    if (!this.env.SMTP_USER || !this.env.SMTP_PASS) {
      this.log.error(
        'MAIL_TRANSPORT=smtp mas SMTP_USER/SMTP_PASS estão vazios — nenhum e-mail será entregue.',
      );
    }
  }

  /** `"OrbixHub" <conta@dominio>` — endereço sempre o nosso; só o nome varia. */
  private from(nameOverride?: string): string {
    const address = this.env.MAIL_FROM_ADDRESS || this.env.SMTP_USER;
    const name = nameOverride ?? this.env.MAIL_FROM_NAME;
    return `"${name.replace(/"/g, "'")}" <${address}>`;
  }

  async send(email: VerificationEmail): Promise<void> {
    const { subject, html, text } = renderVerificationEmail(
      email,
      this.env.APP_PUBLIC_URL,
    );
    await this.deliver({ to: email.to, subject, html, text }, email.kind);
  }

  async sendMessage(message: MailMessage): Promise<void> {
    await this.deliver(message, 'message');
  }

  private async deliver(message: MailMessage, kind: string): Promise<void> {
    try {
      const info = await this.transporter.sendMail({
        from: this.from(message.fromName),
        to: message.to,
        replyTo: message.replyTo,
        subject: message.subject,
        text: message.text,
        html: message.html,
      });
      // Log sem token e sem senha — só o suficiente para rastrear entrega.
      this.log.log(`[${kind}] -> ${message.to} (${info.messageId})`);
    } catch (e) {
      this.log.error(
        `[${kind}] falhou para ${message.to}: ${(e as Error).message}`,
      );
      throw e;
    }
  }
}
