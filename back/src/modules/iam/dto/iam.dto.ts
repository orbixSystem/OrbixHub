import { IsEmail, IsIn, IsOptional, IsString, MinLength } from 'class-validator';

export class CreateInviteDto {
  @IsEmail() email!: string;
  @IsIn(['owner', 'mechanic']) role!: 'owner' | 'mechanic';
}

export class AcceptInviteDto {
  @IsString() token!: string;
  @IsOptional() @IsString() @MinLength(2) fullName?: string;
  @IsOptional() @IsString() @MinLength(8) password?: string;
}
