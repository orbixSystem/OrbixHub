import {
  Body,
  Controller,
  ForbiddenException,
  HttpCode,
  Inject,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import type { Request } from 'express';
import { AuthService } from './auth.service';
import { CnpjLookupService } from './cnpj-lookup.service';
import { SupportSessionService } from './support-session.service';
import { AuthThrottlerGuard } from './auth-throttler.guard';
import { Public, CurrentUser } from '../../common/auth/decorators';
import { ENV } from '../../common/config/config.module';
import type { Env } from '../../common/config/env.schema';
import type { AuthUser } from '../../common/auth/auth.types';
import {
  RegisterDto,
  LoginDto,
  VerifyEmailDto,
  RefreshDto,
  LogoutDto,
  ForgotPasswordDto,
  ResetPasswordDto,
  SwitchTenantDto,
  CnpjLookupDto,
  SupportSessionDto,
} from './dto/auth.dto';

// Strict 5/min per IP+account. Targets the named `auth` throttler so only the
// AuthThrottlerGuard enforces it; the global default (120/min) is untouched.
const STRICT = { auth: { ttl: 60_000, limit: 5 } };

@Controller('auth')
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly cnpjLookup: CnpjLookupService,
    private readonly suporte: SupportSessionService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /**
   * Troca o código do link de suporte por uma sessão. Público porque quem
   * chega aqui ainda não tem sessão nenhuma — o que autentica é o próprio
   * código, de uso único e 5 minutos de vida. Throttled como o resto do /auth.
   */
  @Public()
  @Post('support-session')
  @HttpCode(200)
  @UseGuards(AuthThrottlerGuard)
  @Throttle(STRICT)
  consumirSessaoDeSuporte(@Body() dto: SupportSessionDto) {
    return this.suporte.consumir(dto.code);
  }

  /**
   * Autocadastro de ambiente — DESLIGADO por padrão.
   *
   * O ambiente nasce pelo Orbix Admin, com CNPJ conferido e cadastro comercial
   * junto; a tela que levava aqui saiu do app. A rota continua para as suítes
   * e2e, que a usam como fixture, e é liberada por `SELF_SIGNUP_ENABLED`.
   */
  @Public()
  @Post('register')
  @HttpCode(201)
  @UseGuards(AuthThrottlerGuard)
  @Throttle(STRICT)
  register(@Body() dto: RegisterDto) {
    if (!this.env.SELF_SIGNUP_ENABLED) {
      throw new ForbiddenException(
        'O cadastro de novas empresas é feito pela Orbix. Fale com o suporte.',
      );
    }
    return this.auth.register(dto);
  }

  // Pré-cadastro: consulta pública de dados da empresa pelo CNPJ (proxy p/ a
  // fonte externa). Throttled — sem JWT. Body em vez de path p/ evitar máscara na URL.
  @Public()
  @Post('cnpj-lookup')
  @HttpCode(200)
  @UseGuards(AuthThrottlerGuard)
  @Throttle(STRICT)
  cnpjLookupFn(@Body() dto: CnpjLookupDto) {
    return this.cnpjLookup.lookup(dto.cnpj);
  }

  @Public()
  @Post('verify-email')
  @HttpCode(200)
  verifyEmail(@Body() dto: VerifyEmailDto) {
    return this.auth.verifyEmail(dto);
  }

  @Public()
  @Post('login')
  @HttpCode(200)
  @UseGuards(AuthThrottlerGuard)
  @Throttle(STRICT)
  login(@Body() dto: LoginDto, @Req() req: Request) {
    return this.auth.login(dto, req.ip);
  }

  @Public()
  @Post('refresh')
  @HttpCode(200)
  refresh(@Body() dto: RefreshDto) {
    return this.auth.refreshTokens(dto.refreshToken);
  }

  @Public()
  @Post('logout')
  @HttpCode(204)
  async logout(@Body() dto: LogoutDto) {
    await this.auth.logout(dto.refreshToken);
  }

  @Public()
  @Post('forgot-password')
  @HttpCode(200)
  @UseGuards(AuthThrottlerGuard)
  @Throttle(STRICT)
  forgot(@Body() dto: ForgotPasswordDto) {
    return this.auth.forgotPassword(dto);
  }

  @Public()
  @Post('reset-password')
  @HttpCode(200)
  reset(@Body() dto: ResetPasswordDto) {
    return this.auth.resetPassword(dto);
  }

  @Post('switch-tenant')
  @HttpCode(200)
  switchTenant(@CurrentUser() user: AuthUser, @Body() dto: SwitchTenantDto) {
    return this.auth.switchTenant(user.userId, dto.tenantId);
  }
}
