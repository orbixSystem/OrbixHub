import {
  Body,
  Controller,
  HttpCode,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import type { Request } from 'express';
import { AuthService } from './auth.service';
import { CnpjLookupService } from './cnpj-lookup.service';
import { AuthThrottlerGuard } from './auth-throttler.guard';
import { Public, CurrentUser } from '../../common/auth/decorators';
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
} from './dto/auth.dto';

// Strict 5/min per IP+account. Targets the named `auth` throttler so only the
// AuthThrottlerGuard enforces it; the global default (120/min) is untouched.
const STRICT = { auth: { ttl: 60_000, limit: 5 } };

@Controller('auth')
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly cnpjLookup: CnpjLookupService,
  ) {}

  @Public()
  @Post('register')
  @HttpCode(201)
  @UseGuards(AuthThrottlerGuard)
  @Throttle(STRICT)
  register(@Body() dto: RegisterDto) {
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
