import { IsEmail, IsIn, IsOptional, IsString, IsUrl, Matches } from 'class-validator';

const HEX = /^#([0-9a-fA-F]{6})$/;
const UFS = ['AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG','PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'];
const REGIMES = ['simples', 'mei', 'presumido', 'real'];
export const PRESETS = ['tangerina', 'vermelho', 'azul', 'verde', 'roxo', 'petroleo', 'ambar'];

/**
 * DTO exclusivo para o endpoint PATCH /settings/appearance.
 * Aceita APENAS os 3 campos de aparência — o ValidationPipe com whitelist/
 * forbidNonWhitelisted bloqueia qualquer tentativa de enviar campos de empresa.
 */
export class UpdateAppearanceDto {
  @IsOptional() @IsIn(PRESETS, { message: 'themePreset inválido' }) themePreset?: string;
  @IsOptional() @Matches(HEX, { message: 'primaryColor deve ser hex #RRGGBB' }) primaryColor?: string;
  @IsOptional() @Matches(HEX, { message: 'secondaryColor deve ser hex #RRGGBB' }) secondaryColor?: string;
}

export class UpdateCompanyDto {
  // Identidade
  @IsOptional() @IsString() companyName?: string;
  @IsOptional() @IsString() legalName?: string;
  @IsOptional() @IsString() taxId?: string;
  @IsOptional() @IsString() phone?: string;
  @IsOptional() @IsEmail() email?: string;
  @IsOptional() @IsUrl({ require_tld: false }) website?: string;
  @IsOptional() @IsUrl({ require_tld: false }) logoUrl?: string;
  // Fiscal
  @IsOptional() @IsString() inscricaoEstadual?: string;
  @IsOptional() @IsString() inscricaoMunicipal?: string;
  @IsOptional() @IsIn(REGIMES, { message: 'regimeTributario inválido' }) regimeTributario?: string;
  @IsOptional() @IsString() cnae?: string;
  // Endereço
  @IsOptional() @IsString() cep?: string;
  @IsOptional() @IsString() logradouro?: string;
  @IsOptional() @IsString() numero?: string;
  @IsOptional() @IsString() complemento?: string;
  @IsOptional() @IsString() bairro?: string;
  @IsOptional() @IsString() municipio?: string;
  @IsOptional() @IsIn(UFS, { message: 'uf inválida' }) uf?: string;
  // Aparência (também presente no UpdateAppearanceDto — PRESETS exportado e compartilhado)
  @IsOptional() @IsIn(PRESETS, { message: 'themePreset inválido' }) themePreset?: string;
  @IsOptional() @Matches(HEX, { message: 'primaryColor deve ser hex #RRGGBB' }) primaryColor?: string;
  @IsOptional() @Matches(HEX, { message: 'secondaryColor deve ser hex #RRGGBB' }) secondaryColor?: string;
}
