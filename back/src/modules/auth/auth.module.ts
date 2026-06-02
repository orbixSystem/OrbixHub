import { Module } from '@nestjs/common';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { AuthRepository } from './auth.repository';
import { RefreshService } from './refresh.service';
import { BillingModule } from '../billing/billing.module';

@Module({
  imports: [BillingModule],
  controllers: [AuthController],
  providers: [AuthService, AuthRepository, RefreshService],
  exports: [AuthRepository, RefreshService],
})
export class AuthModule {}
