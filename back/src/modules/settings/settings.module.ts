import { Module } from '@nestjs/common';
import { SettingsService } from './settings.service';
import { SettingsSectionRegistry } from './settings.section-registry';
import { SettingsController } from './settings.controller';
import { BillingModule } from '../billing/billing.module';
import { TenancyModule } from '../tenancy/tenancy.module';

@Module({
  imports: [BillingModule, TenancyModule],
  controllers: [SettingsController],
  providers: [SettingsService, SettingsSectionRegistry],
  exports: [SettingsSectionRegistry],
})
export class SettingsModule {}
