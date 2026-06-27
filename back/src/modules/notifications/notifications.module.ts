import { Global, Module } from '@nestjs/common';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { NotificationsRepository } from './notifications.repository';

/**
 * Sistema de notificações genérico e tenant-wide. @Global para que qualquer módulo
 * (hoje `messages`; amanhã outros) injete o NotificationsService e chame `notify(...)`
 * sem precisar importar este módulo explicitamente ("aponta, não invade" via service
 * público — nenhum módulo toca a tabela `notification`).
 */
@Global()
@Module({
  controllers: [NotificationsController],
  providers: [NotificationsService, NotificationsRepository],
  exports: [NotificationsService],
})
export class NotificationsModule {}
