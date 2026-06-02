import { Injectable, Logger } from '@nestjs/common';
import { MailerService, VerificationEmail } from './mailer.service';

@Injectable()
export class DevMailerService extends MailerService {
  private readonly log = new Logger('DevMailer');
  async send(email: VerificationEmail): Promise<void> {
    this.log.log(`[${email.kind}] to=${email.to} token=${email.token}`);
  }
}
