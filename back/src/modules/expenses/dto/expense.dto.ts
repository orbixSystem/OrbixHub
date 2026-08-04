import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsIn,
  IsInt,
  IsISO8601,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { FREQUENCIES, PAYMENT_METHODS } from '../expenses.config';

/**
 * Recorrência pedida na CRIAÇÃO de uma conta.
 *
 * Não existe em `UpdateExpenseDto` de propósito: alterar a regra a partir de uma
 * ocorrência já gerada reescreveria meses que a cliente talvez já tenha
 * conferido. Mexer na regra é operação própria (`PATCH /expenses/recurrences/:id`).
 */
export class RecurrenceInputDto {
  @IsOptional() @IsIn(FREQUENCIES as unknown as string[])
  frequency?: (typeof FREQUENCIES)[number];

  /** 1..31 — o dia PEDIDO. Mês curto encurta na hora de gerar, não aqui. */
  @IsOptional() @IsInt() @Min(1) @Max(31) dayOfMonth?: number;

  /** Só para `yearly` (IPVA, alvará). */
  @IsOptional() @IsInt() @Min(1) @Max(12) monthOfYear?: number;

  /** Sem fim previsto quando ausente. */
  @IsOptional() @IsISO8601() endsOn?: string;
}

/**
 * Nova conta a pagar.
 *
 * Só `description` e `dueDate` são obrigatórios — decisão de produto: sem os
 * dois não existe lembrete, e exigir mais faria a cliente desistir de cadastrar
 * a conta que ainda não chegou.
 *
 * `amount` aceita **0**: significa "valor a confirmar" (a conta de luz existe
 * antes da fatura). Diferente do lançamento no caixa, que exige valor real.
 */
export class CreateExpenseDto {
  /** Uuid gerado no cliente (replay offline preserva o id). Opcional. */
  @IsOptional() @IsUUID() id?: string;

  @IsString() @MinLength(2) @MaxLength(120) description!: string;

  /** Data civil `YYYY-MM-DD`. */
  @IsISO8601() dueDate!: string;

  @IsOptional() @IsNumber() @Min(0) amount?: number;
  @IsOptional() @IsUUID() categoryId?: string;
  @IsOptional() @IsString() @MaxLength(500) notes?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => RecurrenceInputDto)
  recorrencia?: RecurrenceInputDto;
}

/** Edição de UMA conta (não toca na regra que a gerou). */
export class UpdateExpenseDto {
  @IsOptional() @IsString() @MinLength(2) @MaxLength(120) description?: string;
  @IsOptional() @IsISO8601() dueDate?: string;
  @IsOptional() @IsNumber() @Min(0) amount?: number;
  @IsOptional() @IsUUID() categoryId?: string;
  @IsOptional() @IsString() @MaxLength(500) notes?: string;

  /**
   * Tirar a categoria exige dizer explicitamente: ausência significa "não mexe",
   * senão nunca haveria como voltar para "sem categoria".
   */
  @IsOptional() @IsBoolean() limparCategoria?: boolean;
}

/**
 * Baixa (pagamento).
 *
 * Tudo opcional: o caminho comum é um toque só, e o servidor assume o valor
 * previsto, a forma padrão do caixa e "agora". Pedir formulário para o caso
 * comum é atrito.
 */
export class PayExpenseDto {
  /** Divergente do previsto quando houve juros/desconto. */
  @IsOptional() @IsNumber() @Min(0) amount?: number;

  @IsOptional() @IsIn(PAYMENT_METHODS as unknown as string[])
  method?: (typeof PAYMENT_METHODS)[number];

  /** Pagamento lançado com data retroativa ("paguei ontem"). */
  @IsOptional() @IsISO8601() paidAt?: string;

  /** Ponto de caixa, quando o tenant tiver mais de um. */
  @IsOptional() @IsString() @MaxLength(64) deviceId?: string;

  /**
   * Uuid do lançamento do caixa gerado no cliente (replay offline). Repassado ao
   * caixa para que o replay não duplique o lançamento.
   */
  @IsOptional() @IsUUID() cashEntryId?: string;
}
