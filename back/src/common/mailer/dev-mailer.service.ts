import { Inject, Injectable, Logger } from '@nestjs/common';
import { MailMessage, MailerService, VerificationEmail } from './mailer.service';
import { DevInboxService } from '../../modules/devtools/dev-inbox.service';
import { ENV } from '../config/config.module';
import { Env } from '../config/env.schema';

@Injectable()
export class DevMailerService extends MailerService {
  private readonly log = new Logger('DevMailer');
  constructor(
    private readonly devInbox: DevInboxService,
    @Inject(ENV) private readonly env: Env,
  ) {
    super();
  }
  async send(email: VerificationEmail): Promise<void> {
    if (this.env.DEV_TOOLS_ENABLED) {
      this.log.log(`[${email.kind}] to=${email.to} token=${email.token}`);
      this.devInbox.record(email.kind, email.token);
    } else {
      this.log.log(`[mail] ${email.kind} -> ${email.to}`);
    }
  }

  /**
   * Conteúdo livre (ex.: link da OS) não tem token para o besouro guardar —
   * em dev só registramos que sairia, sem tocar a internet.
   */
  async sendMessage(message: MailMessage): Promise<void> {
    this.log.log(`[mail] "${message.subject}" -> ${message.to}`);
  }
}
