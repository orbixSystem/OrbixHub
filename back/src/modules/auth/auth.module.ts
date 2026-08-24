import { Module } from '@nestjs/common';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { AuthRepository } from './auth.repository';
import { CnpjLookupService } from './cnpj-lookup.service';
import { SupportSessionService } from './support-session.service';
import { RefreshService } from './refresh.service';
import { BillingModule } from '../billing/billing.module';

@Module({
  imports: [BillingModule],
  controllers: [AuthController],
  providers: [
    AuthService,
    AuthRepository,
    CnpjLookupService,
    SupportSessionService,
    RefreshService,
  ],
  exports: [AuthRepository, RefreshService, CnpjLookupService, SupportSessionService],
})
export class AuthModule {}
