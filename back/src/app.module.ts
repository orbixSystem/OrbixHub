import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { EventEmitterModule } from '@nestjs/event-emitter';
import { GlobalThrottlerGuard } from './common/throttler/global-throttler.guard';
import { ConfigModule } from './common/config/config.module';
import { RedisModule } from './common/redis/redis.module';
import { DatabaseModule } from './common/database/database.module';
import { CryptoModule } from './common/crypto/crypto.module';
import { CommonAuthModule } from './common/auth/auth.module';
import { AppThrottlerModule } from './common/throttler/throttler.module';
import { MailerModule } from './common/mailer/mailer.module';
import { AuditModule } from './common/audit/audit.module';
import { JobsModule } from './common/jobs/jobs.module';
import { StorageModule } from './common/storage/storage.module';
import { JwtAuthGuard } from './common/auth/jwt-auth.guard';
import { ActiveMembershipGuard } from './common/auth/active-membership.guard';
import { PermissionsGuard } from './common/auth/permissions.guard';
import { TenantInterceptor } from './common/tenant/tenant.interceptor';
import { RequestIdMiddleware } from './common/observability/request-id.middleware';
import { HealthController } from './common/observability/health.controller';
import { AuthModule } from './modules/auth/auth.module';
import { IamModule } from './modules/iam/iam.module';
import { TenancyModule } from './modules/tenancy/tenancy.module';
import { BillingModule } from './modules/billing/billing.module';
import { SettingsModule } from './modules/settings/settings.module';
import { CustomersModule } from './modules/customers/customers.module';
import { InventoryModule } from './modules/inventory/inventory.module';
import { OsModule } from './modules/os/os.module';
import { InvoiceModule } from './modules/invoice/invoice.module';
import { ReportModule } from './modules/report/report.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { MessagesModule } from './modules/messages/messages.module';
import { RealtimeModule } from './modules/realtime/realtime.module';
import { ScheduleModule } from './modules/schedule/schedule.module';
import { DevtoolsModule } from './modules/devtools/devtools.module';

@Module({
  imports: [
    ConfigModule,
    EventEmitterModule.forRoot(),
    RedisModule,
    DatabaseModule,
    CryptoModule,
    CommonAuthModule,
    AppThrottlerModule,
    MailerModule,
    AuditModule,
    JobsModule,
    StorageModule,
    AuthModule,
    IamModule,
    TenancyModule,
    BillingModule,
    SettingsModule,
    CustomersModule,
    InventoryModule,
    NotificationsModule,
    MessagesModule,
    OsModule,
    InvoiceModule,
    ScheduleModule,
    ReportModule,
    RealtimeModule,
    DevtoolsModule,
  ],
  controllers: [HealthController],
  providers: [
    // Guard order matters: ThrottlerGuard -> JwtAuthGuard (sets req.user) ->
    // ActiveMembershipGuard (rejects deactivated/expired sessions) ->
    // PermissionsGuard (reads req.user). APP_GUARD runs in registration order.
    { provide: APP_GUARD, useClass: GlobalThrottlerGuard },
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: ActiveMembershipGuard },
    { provide: APP_GUARD, useClass: PermissionsGuard },
    { provide: APP_INTERCEPTOR, useClass: TenantInterceptor },
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(RequestIdMiddleware).forRoutes('*');
  }
}
