import { IsEmail, IsOptional, IsString, IsUrl, Matches } from 'class-validator';

const HEX = /^#([0-9a-fA-F]{6})$/;

export class UpdateCompanyDto {
  @IsOptional() @IsString() companyName?: string;
  @IsOptional() @IsString() legalName?: string;
  @IsOptional() @IsString() taxId?: string;
  @IsOptional() @IsString() address?: string;
  @IsOptional() @IsString() phone?: string;
  @IsOptional() @IsEmail() email?: string;
  @IsOptional() @IsUrl() logoUrl?: string;
  @IsOptional() @Matches(HEX, { message: 'primaryColor deve ser hex #RRGGBB' }) primaryColor?: string;
  @IsOptional() @Matches(HEX, { message: 'secondaryColor deve ser hex #RRGGBB' }) secondaryColor?: string;
}
