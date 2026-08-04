import { Global, Module } from '@nestjs/common';
import { ENV } from '../config/config.module';
import { Env } from '../config/env.schema';
import { DevMailerService } from './dev-mailer.service';
import { MailerService } from './mailer.service';
import { SmtpMailerService } from './smtp-mailer.service';
import { DevInboxService } from '../../modules/devtools/dev-inbox.service';

/**
 * O transporte é escolhido por MAIL_TRANSPORT: 'smtp' entrega de verdade,
 * 'dev' (default) cai no dev-inbox/besouro. Default seguro de propósito —
 * esquecer a variável não dispara e-mail para cliente real sem querer.
 */
@Global()
@Module({
  providers: [
    {
      provide: MailerService,
      inject: [ENV, DevInboxService],
      useFactory: (env: Env, devInbox: DevInboxService): MailerService =>
        env.MAIL_TRANSPORT === 'smtp'
          ? new SmtpMailerService(env)
          : new DevMailerService(devInbox, env),
    },
  ],
  exports: [MailerService],
})
export class MailerModule {}
