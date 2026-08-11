import {
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
}

export class PayInstallmentDto {
  @IsString() method!: string;
  @IsOptional() @IsString() description?: string;
}
