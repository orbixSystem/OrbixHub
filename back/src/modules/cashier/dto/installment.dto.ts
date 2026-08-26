import {
  MaxLength,
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsInt,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  IsUUID,
  Max,
  Min,
} from 'class-validator';

export class CreateInstallmentPlanDto {
  @IsString() saleKind!: 'os' | 'sale';
  @IsUUID() saleId!: string;
  /** 1 = pagamento futuro único; 2–60 = parcelamento. */
  @IsInt() @Min(1) @Max(60) installmentCount!: number;
  @IsInt() @Min(1) @Max(28) dueDayOfMonth!: number;
  /** Valor total a parcelar (dividido igualmente entre as parcelas). */
  @IsNumber() @IsPositive() totalAmount!: number;
  /** ISO date, default = próxima ocorrência do `dueDayOfMonth`. */
  @IsOptional() @IsDateString() firstDueDate?: string;
  @IsOptional() @IsString() notes?: string;
  /**
   * Uuids das parcelas gerados no cliente (replay offline), um por parcela, na
   * MESMA ordem — mesmo espírito de `cash_entry.create`'s `id`: o replay usa o
   * id do cliente em vez de gerar um novo, senão duplicaria o plano a cada
   * reenvio do push.
   */
  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(60)
  @IsUUID('4', { each: true })
  installmentIds?: string[];
}

export class PayInstallmentDto {
  @IsString() method!: string;
  @IsOptional() @IsString() description?: string;
  /**
   * Uuid do lançamento do caixa gerado no cliente (replay offline). Repassado
   * ao caixa para o replay não duplicar o lançamento — mesmo idioma de
   * `PayExpenseDto.cashEntryId`.
   */
  @IsOptional() @IsUUID() cashEntryId?: string;
  /**
   * Desconto concedido para fechar ESTA parcela. Abate o saldo que está sendo
   * quitado nesta operação — quitar o título inteiro é outra chamada, com o
   * desconto do título. Exige `cashier.discount` e respeita o teto.
   */
  @IsOptional() @IsNumber() @Min(0) discount?: number;
  @IsOptional() @IsString() @MaxLength(500) discountReason?: string;
}
