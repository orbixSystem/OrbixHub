import { Global, Module } from '@nestjs/common';
import { MailerService } from './mailer.service';
import { DevMailerService } from './dev-mailer.service';

@Global()
@Module({
  providers: [{ provide: MailerService, useClass: DevMailerService }],
  exports: [MailerService],
})
export class MailerModule {}
