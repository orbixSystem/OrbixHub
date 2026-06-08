import { Injectable, Logger } from '@nestjs/common';
import { MailerService, VerificationEmail } from './mailer.service';
import { DevInboxService } from '../../modules/devtools/dev-inbox.service';

@Injectable()
export class DevMailerService extends MailerService {
  private readonly log = new Logger('DevMailer');
  constructor(private readonly devInbox: DevInboxService) {
    super();
  }
  async send(email: VerificationEmail): Promise<void> {
    this.log.log(`[${email.kind}] to=${email.to} token=${email.token}`);
    this.devInbox.record(email.kind, email.token);
  }
}
