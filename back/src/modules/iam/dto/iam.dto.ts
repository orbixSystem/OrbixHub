import { IsEmail, IsIn, IsOptional, IsString, MinLength } from 'class-validator';

const ROLE_KEYS = ['owner', 'gerente', 'mechanic', 'caixa'] as const;
export type RoleKeyInput = (typeof ROLE_KEYS)[number];

export class CreateInviteDto {
  @IsEmail() email!: string;
  @IsIn(ROLE_KEYS) role!: RoleKeyInput;
  @IsString() @MinLength(1) currentPassword!: string; // reautenticação
  @IsOptional() @IsIn(['15min', '30min', '1day', '15days', 'never'])
  expiresIn?: string;
}

export class ResendInviteDto {
  @IsString() @MinLength(1) currentPassword!: string;
  @IsOptional() @IsIn(['15min', '30min', '1day', '15days', 'never'])
  expiresIn?: string;
}

export class AcceptInviteDto {
  @IsString() token!: string;
  @IsOptional() @IsString() @MinLength(2) fullName?: string;
  @IsOptional() @IsString() @MinLength(8) password?: string;
}

export class ChangeRoleDto {
  @IsIn(ROLE_KEYS) role!: RoleKeyInput;
  @IsString() @MinLength(1) currentPassword!: string;
}

export class ReauthDto {
  @IsString() @MinLength(1) currentPassword!: string;
}
