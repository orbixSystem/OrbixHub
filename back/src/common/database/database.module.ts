import { Global, Module } from '@nestjs/common';
import { ClsModule } from 'nestjs-cls';
import { PrismaService } from './prisma.service';
import { TenantContext } from './tenant-context';

@Global()
@Module({
  imports: [ClsModule.forRoot({ global: true, middleware: { mount: false } })],
  providers: [PrismaService, TenantContext],
  exports: [PrismaService, TenantContext, ClsModule],
})
export class DatabaseModule {}
