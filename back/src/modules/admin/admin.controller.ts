import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { IsEmail, IsOptional, IsString, MaxLength, MinLength, IsBoolean } from 'class-validator';
import { Public } from '../../common/auth/decorators';
import { AdminTokenGuard } from './admin-token.guard';
import { AdminService } from './admin.service';
import { TenantSettingsService } from '../../verticals/tenant-settings.service';
import { SupportService } from '../support/support.service';
import { CnpjLookupService } from '../auth/cnpj-lookup.service';
import { SupportSessionService } from '../auth/support-session.service';
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

class ToggleFeatureDto {
  @IsString() @MaxLength(128) key!: string;
  @IsBoolean() enabled!: boolean;
}

class CnpjDto {
  @IsString() @MinLength(11) @MaxLength(18) cnpj!: string;
}

class SessaoSuporteDto {
  /** Quem no time da Orbix pediu — vai para o audit do tenant. */
  @IsString() @MinLength(2) @MaxLength(120) por!: string;
}

class ResponderDto {
  @IsString() @MinLength(1) @MaxLength(4000) body!: string;
  /** Quem atendeu, para o cliente saber com quem falou. */
  @IsString() @MinLength(2) @MaxLength(80) autor!: string;
}

/**
 * API administrativa, consumida pelo Orbix Admin (sistema separado).
 *
 * `@Public` desliga o guard de JWT de USUÁRIO — quem chama aqui é uma máquina,
 * não uma pessoa logada. Em troca, o `AdminTokenGuard` exige o token de
 * serviço; sem ele configurado, tudo aqui responde 401.
 *
 * Note que nada aqui lê tabela de outro módulo: módulos e funcionalidades vêm
 * do `TenantSettingsService`, chamados vêm do `SupportService`. O admin
 * alcança exatamente o que estes serviços públicos expõem — e nada além.
 */
@Controller('admin')
@Public()
@UseGuards(AdminTokenGuard)
export class AdminController {
  constructor(
    private readonly admin: AdminService,
    private readonly settings: TenantSettingsService,
    private readonly support: SupportService,
    private readonly cnpj: CnpjLookupService,
    private readonly billing: BillingService,
    private readonly sessaoSuporte: SupportSessionService,
  ) {}

  /**
   * `q` busca por nome, slug, razão social ou CNPJ; `ids` traz um conjunto
   * conhecido (a carteira do painel). Sem filtro, devolve a primeira página —
   * nunca a base inteira.
   */
  @Get('tenants')
  listar(
    @Query('q') q?: string,
    @Query('ids') ids?: string,
    @Query('vertical') vertical?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.admin.listarTenants({
      q,
      ids: ids ? ids.split(',').filter(Boolean) : undefined,
      vertical,
      limit: limit ? Number(limit) : undefined,
      offset: offset ? Number(offset) : undefined,
    });
  }

  /**
   * Consulta pública de CNPJ, reusando o mesmo serviço do cadastro self-service.
   *
   * Existe separada da rota de `/auth` porque aquela tem rate-limit de 5/min por
   * IP — desenhado para o visitante anônimo. Vindo do painel, todas as consultas
   * saem do MESMO IP, e o time inteiro travaria depois da quinta empresa.
   */
  @Post('cnpj-lookup')
  @HttpCode(200)
  consultarCnpj(@Body() dto: CnpjDto) {
    return this.cnpj.lookup(dto.cnpj);
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

  // ------------------------------------------------------ módulos e features

  @Get('tenants/:id/modules')
  modulos(@Param('id') id: string) {
    return this.settings.listar(id);
  }

  /**
   * Ator NULO: a mudança veio de fora, não de um usuário do tenant. Quem no
   * time da Orbix mexeu fica no `admin_audit` do painel, que é onde a pessoa
   * tem identidade — aqui, qualquer id seria inventado.
   */
  @Patch('tenants/:id/modules')
  @HttpCode(200)
  alternarModulo(@Param('id') id: string, @Body() dto: ToggleModuloDto) {
    return this.settings.alternarModulo(id, null, dto.key, dto.enabled);
  }

  @Patch('tenants/:id/features')
  @HttpCode(200)
  alternarFeature(@Param('id') id: string, @Body() dto: ToggleFeatureDto) {
    return this.settings.alternarFeature(id, null, dto.key, dto.enabled);
  }

  /** Plano, situação e datas — o que o atendente precisa para falar de cobrança. */
  @Get('tenants/:id/billing')
  cobranca(@Param('id') id: string) {
    return this.billing.assinaturaDoTenant(id);
  }

  /**
   * Link de acesso ao ambiente do cliente. Uso único, 5 minutos, e a sessão
   * que ele abre não tem refresh — expira em 15 min e pronto.
   */
  @Post('tenants/:id/support-session')
  @HttpCode(201)
  sessaoDeSuporte(@Param('id') id: string, @Body() dto: SessaoSuporteDto) {
    return this.sessaoSuporte.criarLink(id, dto.por);
  }

  // ----------------------------------------------------------------- suporte

  @Get('tenants/:id/support')
  chamados(@Param('id') id: string) {
    return this.support.ticketsDoTenant(id);
  }

  @Get('tenants/:id/support/:ticketId')
  conversa(@Param('id') id: string, @Param('ticketId') ticketId: string) {
    return this.support.mensagensParaOrbix(id, ticketId);
  }

  @Post('tenants/:id/support/:ticketId')
  @HttpCode(201)
  responder(
    @Param('id') id: string,
    @Param('ticketId') ticketId: string,
    @Body() dto: ResponderDto,
  ) {
    return this.support.responderComoOrbix(id, ticketId, dto.body, dto.autor);
  }

  @Post('tenants/:id/support/:ticketId/resolve')
  @HttpCode(200)
  async resolver(@Param('id') id: string, @Param('ticketId') ticketId: string) {
    await this.support.resolverComoOrbix(id, ticketId);
    return this.support.ticketsDoTenant(id);
  }

  @Post('tenants/:id/support/:ticketId/reopen')
  @HttpCode(200)
  async reabrir(@Param('id') id: string, @Param('ticketId') ticketId: string) {
    await this.support.reabrirComoOrbix(id, ticketId);
    return this.support.ticketsDoTenant(id);
  }
}
