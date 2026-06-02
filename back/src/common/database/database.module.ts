import { Global, Module } from '@nestjs/common';
import { ClsModule } from 'nestjs-cls';
import { PrismaService } from './prisma.service';
import { TenantContext } from './tenant-context';

@Global()
@Module({
  // mount: true installs ClsMiddleware on every route so a per-request CLS
  // context exists before guards/interceptors run. TenantInterceptor relies on
  // this to store the verified tid (req.user is set by JwtAuthGuard, which runs
  // after middleware but before the interceptor). Without it, any authenticated
  // route that uses withTenantTx fails with "No CLS context available".
  imports: [ClsModule.forRoot({ global: true, middleware: { mount: true } })],
  providers: [PrismaService, TenantContext],
  exports: [PrismaService, TenantContext, ClsModule],
})
export class DatabaseModule {}
