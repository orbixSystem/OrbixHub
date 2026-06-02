import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { ConfigModule } from './common/config/config.module';
import { RedisModule } from './common/redis/redis.module';
import { DatabaseModule } from './common/database/database.module';
import { RequestIdMiddleware } from './common/observability/request-id.middleware';
import { HealthController } from './common/observability/health.controller';

@Module({
  imports: [ConfigModule, RedisModule, DatabaseModule],
  controllers: [HealthController],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(RequestIdMiddleware).forRoutes('*');
  }
}
