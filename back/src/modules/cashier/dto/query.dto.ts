import {
  IsDateString,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsUUID,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';
import { ENTRY_CATEGORIES, PAYMENT_METHODS } from '../cashier.config';

/** Filtros + paginação do extrato (livro caixa). */
export class EntryQueryDto {
  @IsOptional() @IsUUID() sessionId?: string;
  @IsOptional() @IsIn(['in', 'out']) direction?: 'in' | 'out';
  @IsOptional() @IsIn(PAYMENT_METHODS as unknown as string[]) method?: string;
  @IsOptional() @IsIn(ENTRY_CATEGORIES as unknown as string[]) category?: string;
  @IsOptional() @IsIn(['os', 'sale']) saleKind?: string;
  @IsOptional() @IsUUID() saleId?: string;
  @IsOptional() @IsDateString() from?: string;
  @IsOptional() @IsDateString() to?: string;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) pageSize?: number;
}

/** Período do resumo (totais por método/categoria/origem). */
export class SummaryQueryDto {
  @IsOptional() @IsDateString() from?: string;
  @IsOptional() @IsDateString() to?: string;
}

/** Paginação do histórico de sessões. */
export class SessionQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) pageSize?: number;
}

/**
 * Resumo de pagamento de uma venda. `total` é OPCIONAL e informado pelo dono da
 * venda (a OS sabe seu próprio total) — o caixa não toca a tabela da venda. Sem
 * `total`, o resumo reflete só o que o caixa recebeu (total=0).
 */
export class PaymentSummaryQueryDto {
  @IsIn(['os', 'sale']) saleKind!: string;
  @IsUUID() saleId!: string;
  @IsOptional() @Type(() => Number) @IsNumber() total?: number;
}
