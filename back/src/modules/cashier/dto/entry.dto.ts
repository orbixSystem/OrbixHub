import {
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import {
  ENTRY_CATEGORIES,
  EntryCategory,
  PAYMENT_METHODS,
  PaymentMethod,
} from '../cashier.config';

/**
 * Lançamento no caixa. A direção (entrada/saída) NÃO vem do cliente — é derivada
 * da categoria no service (despesa/sangria = saída; resto = entrada). Recebimento
 * de venda informa `saleKind`+`saleId` (aponta para a venda). Permite parcial e
 * múltiplas formas: cada chamada cria uma entry.
 */
export class CreateEntryDto {
  /** Uuid gerado no cliente (replay offline preserva o id). Opcional. */
  @IsOptional() @IsUUID() id?: string;
  @IsNumber() @Min(0.01) amount!: number;
  @IsIn(PAYMENT_METHODS as unknown as string[]) method!: PaymentMethod;
  @IsIn(ENTRY_CATEGORIES as unknown as string[]) category!: EntryCategory;
  @IsOptional() @IsIn(['os', 'sale']) saleKind?: 'os' | 'sale';
  @IsOptional() @IsUUID() saleId?: string;
  @IsOptional() @IsString() @MaxLength(500) description?: string;
  /** Ponto de caixa (dispositivo/terminal); ausente = ponto legado (NULL). */
  @IsOptional() @IsUUID() deviceId?: string;
}

/** Estorno lógico de uma entry (auditado). Motivo é obrigatório. */
export class ReverseEntryDto {
  @IsString() @MinLength(3) @MaxLength(500) reason!: string;
}
