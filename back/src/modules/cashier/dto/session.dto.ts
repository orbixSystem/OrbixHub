import { IsNumber, IsOptional, IsString, MaxLength, Min } from 'class-validator';

/** Abertura do caixa do dia (valor inicial em gaveta). */
export class OpenSessionDto {
  @IsOptional() @IsNumber() @Min(0) openingAmount?: number;
  @IsOptional() @IsString() @MaxLength(500) notes?: string;
}

/** Fechamento: informa o valor CONTADO; o service calcula esperado e diferença. */
export class CloseSessionDto {
  @IsNumber() @Min(0) countedAmount!: number;
  @IsOptional() @IsString() @MaxLength(500) notes?: string;
}
