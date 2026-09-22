import { IsIn, IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';
import { Type } from 'class-transformer';

/**
 * Filtros do "A receber". Todos opcionais: sem nada, devolve a carteira inteira
 * ordenada por valor, primeira página — o comportamento que a aba antiga tinha.
 *
 * `vencimento`, `origem` e `sort` são listas fechadas (`@IsIn`) porque viram
 * `switch` na regra pura: valor fora da lista é erro do cliente, não caso novo.
 */
export class ListDebtorsQueryDto {
  @IsOptional() @IsString() @MaxLength(120) q?: string;

  @IsOptional()
  @IsIn(['todos', 'vencidos', 'vence7', 'a_vencer', 'sem_prazo'])
  vencimento?: 'todos' | 'vencidos' | 'vence7' | 'a_vencer' | 'sem_prazo';

  @IsOptional()
  @IsIn(['todos', 'os', 'sale'])
  origem?: 'todos' | 'os' | 'sale';

  @IsOptional()
  @IsIn(['valor', 'mais_antigo', 'nome', 'vencimento'])
  sort?: 'valor' | 'mais_antigo' | 'nome' | 'vencimento';

  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;

  // Cap igual ao dos demais módulos — sem ele um cliente pede uma página
  // arbitrariamente grande.
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) pageSize?: number;
}
