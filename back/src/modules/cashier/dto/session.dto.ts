import {
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
} from 'class-validator';

/**
 * Abertura do caixa do dia (valor inicial em gaveta). `deviceId` identifica o
 * PONTO de caixa (dispositivo/terminal); ausente = ponto legado (NULL), com
 * no máximo uma sessão aberta por tenant.
 */
export class OpenSessionDto {
  /** Uuid gerado no cliente (replay offline preserva o id). Opcional. */
  @IsOptional() @IsUUID() id?: string;
  @IsOptional() @IsNumber() @Min(0) openingAmount?: number;
  @IsOptional() @IsString() @MaxLength(500) notes?: string;
  @IsOptional() @IsUUID() deviceId?: string;
}

/** Fechamento: informa o valor CONTADO; o service calcula esperado e diferença. */
export class CloseSessionDto {
  @IsNumber() @Min(0) countedAmount!: number;
  @IsOptional() @IsString() @MaxLength(500) notes?: string;
  @IsOptional() @IsUUID() deviceId?: string;
}
