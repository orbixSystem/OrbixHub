import { Module } from '@nestjs/common';
import { MailerModule } from '../../common/mailer/mailer.module';
import { TenancyModule } from '../tenancy/tenancy.module';
import { SupportController } from './support.controller';
import { SupportService } from './support.service';
import { SupportRepository } from './support.repository';

/**
 * Suporte: uma thread por tenant com a Orbix.
 *
 * Importa TenancyModule só para o nome/e-mail da empresa no aviso — via service
 * público, sem tocar a tabela `tenant` ("aponta, não invade").
 */
@Module({
  imports: [MailerModule, TenancyModule],
  controllers: [SupportController],
  providers: [SupportService, SupportRepository],
  exports: [SupportService],
})
export class SupportModule {}
