import { IsIn, IsNumber, IsOptional, IsString, Matches, Max, MaxLength, Min } from 'class-validator';

export class UpdateInvoiceConfigDto {
  @IsOptional() @IsIn(['homologacao', 'producao'])
  ambiente?: 'homologacao' | 'producao';

  @IsOptional() @IsString() @MaxLength(10) serieNfse?: string;
  @IsOptional() @IsString() @MaxLength(10) serieNfce?: string;
  @IsOptional() @IsString() @MaxLength(10) serieNfe?: string;
  @IsOptional() @IsString() @MaxLength(40) idCsc?: string;

  // Classificação padrão do serviço na NFS-e Nacional. '' limpa.
  @IsOptional() @Matches(/^(\d{6})?$/, { message: 'Código de tributação nacional deve ter 6 dígitos' })
  codigoServicoNacional?: string;
  @IsOptional() @Matches(/^(\d{9})?$/, { message: 'Código NBS deve ter 9 dígitos' })
  codigoNbs?: string;
  // null limpa. ISS: 0–5% na lei, mas o leiaute aceita até 9,99.
  @IsOptional() @IsNumber({ maxDecimalPlaces: 2 }) @Min(0) @Max(9.99)
  aliquotaIss?: number | null;
  @IsOptional() @IsNumber({ maxDecimalPlaces: 2 }) @Min(0) @Max(99.99)
  percentualTributosSimples?: number | null;
}

/** Cadastro da empresa no provedor usa a identidade fiscal do núcleo (tenant.settings);
 *  DTO vazio hoje, mantido para extensão futura sem quebrar o contrato do endpoint. */
export class RegisterEmpresaDto {}
