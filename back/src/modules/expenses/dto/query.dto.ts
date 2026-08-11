import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, Max, Min } from 'class-validator';

/**
 * Recorte da listagem: um MÊS.
 *
 * É como a cliente pensa ("o que tenho pra pagar em setembro"), não "as próximas
 * 50 contas". Ausentes ⇒ mês corrente, resolvido no service (o DTO não conhece
 * "hoje").
 */
export class ExpensesMonthQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(2000) @Max(2200)
  ano?: number;

  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(12)
  mes?: number;

  /**
   * Filtro por situação. `vencido`/`aberto` são DERIVADOS (paid_at + due_date),
   * não colunas — ver a nota na migration 0039.
   *
   * `excluidas` é a LIXEIRA e não é um recorte das demais: as outras opções olham
   * só `status='active'`, esta olha só `status='canceled'`. Por isso é o único
   * valor que muda a consulta, e não apenas o filtro em memória.
   */
  @IsOptional() @IsIn(['todas', 'aberto', 'vencido', 'pago', 'excluidas'])
  situacao?: 'todas' | 'aberto' | 'vencido' | 'pago' | 'excluidas';
}

/** Listagem de categorias. Por padrão só as ATIVAS (é o que vira chip na UI). */
export class ExpenseCategoryQueryDto {
  @IsOptional() @Type(() => Boolean) includeDisabled?: boolean;
}
