import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { ThrottlerGuard } from '@nestjs/throttler';
import { ConfigModule } from './common/config/config.module';
import { RedisModule } from './common/redis/redis.module';
import { DatabaseModule } from './common/database/database.module';
import { CryptoModule } from './common/crypto/crypto.module';
import { CommonAuthModule } from './common/auth/auth.module';
import { AppThrottlerModule } from './common/throttler/throttler.module';
import { MailerModule } from './common/mailer/mailer.module';
import { AuditModule } from './common/audit/audit.module';
import { JwtAuthGuard } from './common/auth/jwt-auth.guard';
import { PermissionsGuard } from './common/auth/permissions.guard';
import { TenantInterceptor } from './common/tenant/tenant.interceptor';
import { RequestIdMiddleware } from './common/observability/request-id.middleware';
import { HealthController } from './common/observability/health.controller';
// TODO(phase5): enable when module exists
// import { AuthModule } from './modules/auth/auth.module';
// TODO(phase6): enable when module exists
// import { IamModule } from './modules/iam/iam.module';
// TODO(phase7): enable when module exists
// import { TenancyModule } from './modules/tenancy/tenancy.module';
// TODO(phase8): enable when module exists
// import { BillingModule } from './modules/billing/billing.module';

@Module({
  imports: [
    ConfigModule,
    RedisModule,
    DatabaseModule,
    CryptoModule,
    CommonAuthModule,
    AppThrottlerModule,
    MailerModule,
    AuditModule,
    // TODO(phase5-8): enable when modules exist
    // AuthModule, IamModule, TenancyModule, BillingModule,
  ],
  controllers: [HealthController],
  providers: [
    // Guard order matters: ThrottlerGuard -> JwtAuthGuard (sets req.user)
    // -> PermissionsGuard (reads it). APP_GUARD runs in registration order.
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: PermissionsGuard },
    { provide: APP_INTERCEPTOR, useClass: TenantInterceptor },
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(RequestIdMiddleware).forRoutes('*');
  }
}
