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
import { PAYMENT_METHODS, PaymentMethod } from '../cashier.config';

/** Categorias que um modelo pode lançar — só saídas (ver a migration 0038). */
export const TEMPLATE_CATEGORIES = ['despesa', 'sangria'] as const;
export type TemplateCategory = (typeof TEMPLATE_CATEGORIES)[number];

/**
 * Modelo de despesa fixa: nome + valor para lançar em um toque.
 *
 * `amount` aceita **0** de propósito: 0 significa "o valor varia" (conta de luz,
 * por exemplo) e o atalho preenche só o nome. Repare que `CreateEntryDto` exige
 * `Min(0.01)` — lançar zero continua proibido; o modelo é que pode ficar em
 * aberto, e o operador digita o valor na hora.
 */
export class CreateExpenseTemplateDto {
  /** Uuid gerado no cliente (replay offline preserva o id). Opcional. */
  @IsOptional() @IsUUID() id?: string;
  @IsString() @MinLength(2) @MaxLength(80) name!: string;
  @IsOptional() @IsNumber() @Min(0) amount?: number;
  @IsOptional() @IsIn(TEMPLATE_CATEGORIES as unknown as string[])
  category?: TemplateCategory;
  /** Forma sugerida; ausente = não opinar (usa o default do caixa). */
  @IsOptional() @IsIn(PAYMENT_METHODS as unknown as string[]) method?: PaymentMethod;
}

/**
 * Edição de um modelo. Alterar o valor aqui é seguro (diferente de um
 * lançamento): modelo não é dinheiro no livro caixa, é só um atalho — o que já
 * foi lançado com ele não muda.
 */
export class UpdateExpenseTemplateDto {
  @IsOptional() @IsString() @MinLength(2) @MaxLength(80) name?: string;
  @IsOptional() @IsNumber() @Min(0) amount?: number;
  @IsOptional() @IsIn(TEMPLATE_CATEGORIES as unknown as string[])
  category?: TemplateCategory;
  @IsOptional() @IsIn(PAYMENT_METHODS as unknown as string[]) method?: PaymentMethod;
  /** Desativar/reativar. Sem hard delete (regra 6) — preserva o histórico. */
  @IsOptional() @IsIn(['active', 'disabled']) status?: 'active' | 'disabled';
}
