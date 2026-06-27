import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { MessagesController } from './messages.controller';
import { MessagesService } from './messages.service';
import { MessagesRepository } from './messages.repository';

/**
 * Módulo de mensagens genérico — conversas/mensagens com contexto via ref_type/ref_id.
 * Importa NotificationsModule (notifica o staff quando o cliente manda mensagem) e
 * exporta MessagesService para outros módulos (ex.: OS) criarem conversas via service
 * público ("aponta, não invade"). NotificationsModule é @Global, então o import é
 * redundante por DI mas explícito por clareza de dependência.
 */
@Module({
  imports: [NotificationsModule],
  controllers: [MessagesController],
  providers: [MessagesService, MessagesRepository],
  exports: [MessagesService],
})
export class MessagesModule {}
