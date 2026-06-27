import { Inject, Injectable, Logger } from '@nestjs/common';
import { MailerService, VerificationEmail } from './mailer.service';
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
}
