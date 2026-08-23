import { Body, Controller, Get, HttpCode, Patch } from '@nestjs/common';
import { IsBoolean, IsString, MaxLength } from 'class-validator';
import { CurrentUser, Permissions, Public } from '../common/auth/decorators';
import type { AuthUser } from '../common/auth/auth.types';
import { TenantSettingsService } from './tenant-settings.service';
import { VerticalRegistry } from './vertical.registry';

class ToggleModuloDto {
  @IsString() @MaxLength(64) key!: string;
  @IsBoolean() enabled!: boolean;
}

class ToggleFeatureDto {
  @IsString() @MaxLength(128) key!: string;
  @IsBoolean() enabled!: boolean;
}

/**
 * Módulos e funcionalidades do tenant + catálogo de nichos.
 *
 * `GET /verticals` é PÚBLICO de propósito: a tela de cadastro precisa listar os
 * nichos antes de existir conta, e a lista tem de vir do servidor — nicho
 * hardcoded no Flutter seria a mesma dívida que planos e módulos já não têm.
 * Não expõe nada sensível: são as chaves e os nomes do catálogo em código.
 *
 * A REGRA de quais módulos/funcionalidades o tenant tem mora no
 * `TenantSettingsService`, compartilhado com a superfície administrativa: aqui
 * ficam só a autorização (dono, `settings.manage`) e o formato do request.
 */
@Controller()
export class VerticalsController {
  constructor(
    private readonly registry: VerticalRegistry,
    private readonly settings: TenantSettingsService,
  ) {}

  @Get('verticals')
  @Public()
  listarVerticais() {
    return { verticals: this.registry.listar() };
  }

  @Get('settings/modules')
  @Permissions('settings.manage')
  listar(@CurrentUser() user: AuthUser) {
    return this.settings.listar(user.tenantId);
  }

  @Patch('settings/modules')
  @Permissions('settings.manage')
  @HttpCode(200)
  alternarModulo(@CurrentUser() user: AuthUser, @Body() dto: ToggleModuloDto) {
    return this.settings.alternarModulo(
      user.tenantId,
      user.userId,
      dto.key,
      dto.enabled,
    );
  }

  @Patch('settings/features')
  @Permissions('settings.manage')
  @HttpCode(200)
  alternarFeature(@CurrentUser() user: AuthUser, @Body() dto: ToggleFeatureDto) {
    return this.settings.alternarFeature(
      user.tenantId,
      user.userId,
      dto.key,
      dto.enabled,
    );
  }
}
