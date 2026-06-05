import { Module } from '@nestjs/common';
import { TenancyController } from './tenancy.controller';
import { TenancyService } from './tenancy.service';
import { TenancyRepository } from './tenancy.repository';
import { AuthModule } from '../auth/auth.module';
import { BillingModule } from '../billing/billing.module';

@Module({
  imports: [AuthModule, BillingModule], // for AuthRepository (exported) + BillingService
  controllers: [TenancyController],
  providers: [TenancyService, TenancyRepository],
})
export class TenancyModule {}
