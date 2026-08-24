import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { BillingModule } from '../billing/billing.module';
import { CryptoModule } from '../../common/crypto/crypto.module';
import { SupportModule } from '../support/support.module';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';
import { AdminTokenGuard } from './admin-token.guard';

/**
 * Superfície administrativa do Hub. Isolada num módulo próprio para que fique
 * evidente o que o sistema de admin alcança — e o que ele não alcança.
 */
@Module({
  // VerticalsModule é @Global — TenantSettingsService entra sem import.
  imports: [AuthModule, BillingModule, CryptoModule, SupportModule],
  controllers: [AdminController],
  providers: [AdminService, AdminTokenGuard],
  exports: [AdminService],
})
export class AdminModule {}
