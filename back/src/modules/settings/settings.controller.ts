import { Body, Controller, Delete, Get, HttpCode, Patch, Post, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { Permissions, CurrentUser } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';
import { SettingsService } from './settings.service';
import { UpdateCompanyDto } from './dto/settings.dto';
import { UploadedImage } from './settings.types';

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

  @Post('company/logo')
  @Permissions('settings.manage')
  @HttpCode(200)
  @UseInterceptors(FileInterceptor('file', { storage: memoryStorage(), limits: { fileSize: 4 * 1024 * 1024 } }))
  uploadLogo(@CurrentUser() user: AuthUser, @UploadedFile() file: UploadedImage | undefined) {
    return this.settings.uploadLogo(user, file);
  }

  @Delete('company/logo')
  @Permissions('settings.manage')
  @HttpCode(200)
  removeLogo(@CurrentUser() user: AuthUser) {
    return this.settings.removeLogo(user);
  }
}
