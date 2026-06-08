import { Body, Controller, Get, HttpCode, Patch } from '@nestjs/common';
import { Permissions, CurrentUser } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';
import { SettingsService } from './settings.service';
import { UpdateCompanyDto } from './dto/settings.dto';

@Controller('settings')
export class SettingsController {
  constructor(private readonly settings: SettingsService) {}

  @Get()
  get(@CurrentUser() user: AuthUser) {
    return this.settings.getSettings(user); // read: any authenticated member
  }

  @Patch('company')
  @Permissions('settings.manage')
  @HttpCode(200)
  updateCompany(@CurrentUser() user: AuthUser, @Body() dto: UpdateCompanyDto) {
    return this.settings.updateCompany(user, dto);
  }
}
