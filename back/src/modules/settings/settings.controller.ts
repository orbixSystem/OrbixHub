import { Body, Controller, Delete, Get, HttpCode, Param, Patch, Post, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
import { Permissions, CurrentUser } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';
import { SettingsService } from './settings.service';
import {
  UpdateAppearanceDto,
  UpdateCompanyDto,
  UpdateSectionDto,
} from './dto/settings.dto';
import { UploadedImage } from './settings.types';

@Controller('settings')
export class SettingsController {
  constructor(private readonly settings: SettingsService) {}

  @Get()
  get(@CurrentUser() user: AuthUser) {
    return this.settings.getSettings(user); // read: any authenticated member
  }

  /**
   * Qualquer membro autenticado pode alterar aparência (themePreset + cores).
   * Sem @Permissions: basta estar logado (JwtAuthGuard global).
   * O ValidationPipe com whitelist/forbidNonWhitelisted bloqueia campos de empresa.
   */
  @Patch('appearance')
  @HttpCode(200)
  updateAppearance(@CurrentUser() user: AuthUser, @Body() dto: UpdateAppearanceDto) {
    return this.settings.updateAppearance(user, dto);
  }

  @Patch('company')
  @Permissions('settings.manage')
  @HttpCode(200)
  updateCompany(@CurrentUser() user: AuthUser, @Body() dto: UpdateCompanyDto) {
    return this.settings.updateCompany(user, dto);
  }

  /**
   * Aplica um patch nos valores de uma SEÇÃO de módulo (ex.: `cashier`). O host
   * só encaminha para o módulo dono, que valida e persiste — ver `setValues`.
   */
  @Patch('section/:key')
  @Permissions('settings.manage')
  @HttpCode(200)
  updateSection(
    @CurrentUser() user: AuthUser,
    @Param('key') key: string,
    @Body() dto: UpdateSectionDto,
  ) {
    return this.settings.updateSection(user, key, dto.values);
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
