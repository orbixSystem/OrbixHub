import {
  IsDateString,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
} from 'class-validator';
import { Transform, Type } from 'class-transformer';
import { ENTRY_CATEGORIES, PAYMENT_METHODS } from '../cashier.config';

/** Filtros + paginação do extrato (livro caixa). */
export class EntryQueryDto {
  @IsOptional() @IsUUID() sessionId?: string;
  /**
   * Busca textual na descrição do lançamento — é onde fica o número da OS/venda
   * e o nome do cliente. Filtrar no SERVIDOR (e não na página já carregada) é o
   * que mantém a paginação correta e o mesmo comportamento offline.
   */
  @IsOptional() @IsString() @MaxLength(120) q?: string;
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

/**
 * Listagem de despesas fixas. Por padrão só as ATIVAS (é o que vira atalho);
 * a tela de gerenciamento pede as desativadas para poder reativá-las.
 */
export class ExpenseTemplateQueryDto {
  @IsOptional()
  @Transform(({ value }) => value === true || value === 'true')
  includeDisabled?: boolean;
}

/** Período do resumo (totais por método/categoria/origem). */
export class SummaryQueryDto {
  @IsOptional() @IsDateString() from?: string;
  @IsOptional() @IsDateString() to?: string;
}

/**
 * Paginação do histórico de sessões. `deviceId` restringe ao PONTO de caixa —
 * necessário para sugerir a abertura com o valor contado no último fechamento
 * DAQUELE terminal (o troco que ficou na gaveta), sem pegar a sessão de outro.
 */
export class SessionQueryDto {
  @IsOptional() @IsUUID() deviceId?: string;
  @IsOptional() @IsIn(['open', 'closed']) status?: 'open' | 'closed';
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) pageSize?: number;
}

/** Sessão atual de um ponto de caixa específico; ausente = ponto legado (NULL). */
export class CurrentSessionQueryDto {
  @IsOptional() @IsUUID() deviceId?: string;
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
