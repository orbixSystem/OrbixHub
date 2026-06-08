import { Module } from '@nestjs/common';
import { SettingsService } from './settings.service';
import { SettingsRepository } from './settings.repository';
import { SettingsSectionRegistry } from './settings.section-registry';
import { SettingsController } from './settings.controller';
import { BillingModule } from '../billing/billing.module';

@Module({
  imports: [BillingModule],
  controllers: [SettingsController],
  providers: [SettingsService, SettingsRepository, SettingsSectionRegistry],
  exports: [SettingsSectionRegistry],
})
export class SettingsModule {}
