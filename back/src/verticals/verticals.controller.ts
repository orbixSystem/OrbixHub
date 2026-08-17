import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpCode,
  Patch,
} from '@nestjs/common';
import { IsBoolean, IsString, MaxLength } from 'class-validator';
import { CurrentUser, Permissions, Public } from '../common/auth/decorators';
import type { AuthUser } from '../common/auth/auth.types';
import { BillingService } from '../modules/billing/billing.service';
import { TenancyService } from '../modules/tenancy/tenancy.service';
import { FeatureService } from './feature.service';
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
 */
@Controller()
export class VerticalsController {
  constructor(
    private readonly registry: VerticalRegistry,
    private readonly features: FeatureService,
    private readonly billing: BillingService,
    private readonly tenancy: TenancyService,
  ) {}

  @Get('verticals')
  @Public()
  listarVerticais() {
    return { verticals: this.registry.listar() };
  }

  /**
   * Módulos contratados + as funcionalidades de cada um. Capacidade
   * indisponível para o nicho não vem na lista: toggle que não faz efeito é
   * pior que toggle ausente.
   */
  @Get('settings/modules')
  @Permissions('settings.manage')
  async listar(@CurrentUser() user: AuthUser) {
    const modules = await this.billing.listTenantModules(user.tenantId);
    const habilitados = modules.filter((m) => m.enabled).map((m) => m.key);
    const vertical = await this.tenancy.getTenantVertical(user.tenantId);
    const features = await this.features.listar(user.tenantId, vertical, habilitados);
    return {
      vertical,
      modules: modules.map((m) => ({
        ...m,
        features: features.filter((f) => f.moduleKey === m.key),
      })),
    };
  }

  @Patch('settings/modules')
  @Permissions('settings.manage')
  @HttpCode(200)
  async alternarModulo(
    @CurrentUser() user: AuthUser,
    @Body() dto: ToggleModuloDto,
  ) {
    await this.billing.setModuleEnabled(
      user.tenantId,
      user.userId,
      dto.key,
      dto.enabled,
    );
    return this.listar(user);
  }

  @Patch('settings/features')
  @Permissions('settings.manage')
  @HttpCode(200)
  async alternarFeature(
    @CurrentUser() user: AuthUser,
    @Body() dto: ToggleFeatureDto,
  ) {
    const vertical = await this.tenancy.getTenantVertical(user.tenantId);
    const modules = await this.billing.listTenantModules(user.tenantId);
    const habilitados = modules.filter((m) => m.enabled).map((m) => m.key);
    // Recusa ligar o que está indisponível para o nicho, em vez de gravar uma
    // linha que o resolvedor ignoraria depois — toggle fantasma é dívida.
    const disponivel = await this.features.listar(user.tenantId, vertical, habilitados);
    if (!disponivel.some((f) => f.key === dto.key)) {
      throw new BadRequestException(
        `Funcionalidade indisponível para este tenant: ${dto.key}`,
      );
    }
    await this.features.definir(user.tenantId, dto.key, dto.enabled, user.userId);
    return this.listar(user);
  }
}
