import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export class UpdateInvoiceConfigDto {
  @IsOptional() @IsIn(['homologacao', 'producao'])
  ambiente?: 'homologacao' | 'producao';

  @IsOptional() @IsString() @MaxLength(10) serieNfse?: string;
  @IsOptional() @IsString() @MaxLength(10) serieNfce?: string;
  @IsOptional() @IsString() @MaxLength(10) serieNfe?: string;
  @IsOptional() @IsString() @MaxLength(40) idCsc?: string;
}

/** Cadastro da empresa no provedor usa a identidade fiscal do núcleo (tenant.settings);
 *  DTO vazio hoje, mantido para extensão futura sem quebrar o contrato do endpoint. */
export class RegisterEmpresaDto {}
