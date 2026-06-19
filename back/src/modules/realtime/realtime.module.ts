import { Module } from '@nestjs/common';
import { MessagesModule } from '../messages/messages.module';
import { OsModule } from '../os/os.module';
import { RealtimeGateway } from './realtime.gateway';

/**
 * Camada de tempo real (WebSocket). Importa OsModule (resolver de token público →
 * conversa) e MessagesModule (validar conversa no tenant do staff). AccessTokenService
 * é global. NÃO é importado por esses módulos — o push vem do event-bus
 * (`message.created`), então não há ciclo de dependência.
 */
@Module({
  imports: [OsModule, MessagesModule],
  providers: [RealtimeGateway],
})
export class RealtimeModule {}
