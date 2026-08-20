import {
  IsEmail,
  IsOptional,
  MaxLength,
  IsString,
  IsUUID,
  MinLength,
} from 'class-validator';

export class RegisterDto {
  @IsString() @MinLength(2) tenantName!: string;
  @IsString() slug!: string;
  // 14 dígitos (com ou sem máscara); os dígitos verificadores são checados no service.
  @IsString() @MinLength(14) cnpj!: string;
  @IsString() @MinLength(2) legalName!: string; // razão social
  @IsOptional() @IsString() tradeName?: string; // nome fantasia
  @IsString() @MinLength(2) fullName!: string;
  @IsEmail() email!: string;
  @IsString() @MinLength(8) password!: string;
  /**
   * Nicho escolhido no cadastro ('veiculos' | 'equipamentos' | ...).
   * Opcional: ausente = pacote padrão. Validado contra o VerticalRegistry no
   * service — chave inventada é recusada, não gravada.
   */
  @IsOptional() @IsString() @MaxLength(64) vertical?: string;
}

export class CnpjLookupDto {
  @IsString() @MinLength(14) cnpj!: string;
}

export class LoginDto {
  @IsEmail() email!: string;
  @IsString() @MinLength(1) password!: string;
}

export class VerifyEmailDto {
  @IsString() token!: string;
}
export class RefreshDto {
  @IsString() refreshToken!: string;
}
export class LogoutDto {
  @IsString() refreshToken!: string;
}
export class ForgotPasswordDto {
  @IsEmail() email!: string;
}
export class ResetPasswordDto {
  @IsString() token!: string;
  @IsString() @MinLength(8) newPassword!: string;
}
export class SwitchTenantDto {
  @IsUUID() tenantId!: string;
}
