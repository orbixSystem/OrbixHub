import { Body, Controller, Get, HttpCode, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { IsEmail, IsOptional, IsString, MaxLength, MinLength, IsBoolean } from 'class-validator';
import { Public } from '../../common/auth/decorators';
import { AdminTokenGuard } from './admin-token.guard';
import { AdminService } from './admin.service';
import { BillingService } from '../billing/billing.service';

class ProvisionarDto {
  @IsString() @MinLength(2) tenantName!: string;
  @IsString() @MinLength(3) @MaxLength(60) slug!: string;
  @IsString() @MinLength(11) cnpj!: string;
  @IsString() @MinLength(2) legalName!: string;
  @IsOptional() @IsString() tradeName?: string;
  @IsString() @MinLength(2) ownerName!: string;
  @IsEmail() ownerEmail!: string;
  @IsOptional() @IsString() @MaxLength(64) vertical?: string;
}

class ToggleModuloDto {
  @IsString() @MaxLength(64) key!: string;
  @IsBoolean() enabled!: boolean;
}

/**
 * API administrativa, consumida pelo Orbix Admin (sistema separado).
 *
 * `@Public` desliga o guard de JWT de USUÁRIO — quem chama aqui é uma máquina,
 * não uma pessoa logada. Em troca, o `AdminTokenGuard` exige o token de
 * serviço; sem ele configurado, tudo aqui responde 401.
 */
@Controller('admin')
@Public()
@UseGuards(AdminTokenGuard)
export class AdminController {
  constructor(
    private readonly admin: AdminService,
    private readonly billing: BillingService,
  ) {}

  @Get('tenants')
  listar() {
    return this.admin.listarTenants();
  }

  @Get('tenants/:id')
  tenant(@Param('id') id: string) {
    return this.admin.tenant(id);
  }

  @Post('tenants')
  @HttpCode(201)
  provisionar(@Body() dto: ProvisionarDto) {
    return this.admin.provisionar(dto);
  }

  @Get('tenants/:id/modules')
  modulos(@Param('id') id: string) {
    return this.billing.listTenantModules(id);
  }

  /**
   * Liga/desliga módulo pelo admin. `actorUserId` vai como o id do TENANT
   * porque a ação não tem usuário do Hub por trás — o rastro de quem clicou
   * fica no `admin_audit` do outro lado, com o login do Authentik.
   */
  @Patch('tenants/:id/modules')
  @HttpCode(200)
  async alternarModulo(@Param('id') id: string, @Body() dto: ToggleModuloDto) {
    await this.billing.setModuleEnabled(id, id, dto.key, dto.enabled);
    return this.billing.listTenantModules(id);
  }
}
