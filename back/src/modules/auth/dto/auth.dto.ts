import { IsEmail, IsString, IsUUID, MinLength } from 'class-validator';

export class RegisterDto {
  @IsString() @MinLength(2) tenantName!: string;
  @IsString() slug!: string;
  @IsString() @MinLength(2) fullName!: string;
  @IsEmail() email!: string;
  @IsString() @MinLength(8) password!: string;
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
