import {
  IsBoolean,
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';

/**
 * Chaves de ícone conhecidas. Whitelist (não texto livre) porque o Flutter faz
 * tree-shake de ícones: o front mapeia chave → `IconData` const, e uma chave
 * inventada viraria ícone neutro. Melhor recusar na borda do que renderizar
 * errado — e a lista cresce por migration, junto com o mapa do front.
 */
export const ICON_KEYS = [
  'aluguel',
  'energia',
  'agua',
  'internet',
  'telefone',
  'impostos',
  'fornecedor',
  'produto',
  'salarios',
  'manutencao',
  'outros',
] as const;

/** `#RRGGBB` — mesmo CHECK da tabela. */
const HEX = /^#[0-9A-Fa-f]{6}$/;

export class CreateExpenseCategoryDto {
  @IsOptional() @IsUUID() id?: string;
  @IsString() @MinLength(2) @MaxLength(40) name!: string;
  @IsOptional() @IsIn(ICON_KEYS as unknown as string[]) icon?: string;
  @IsOptional() @Matches(HEX, { message: 'Cor deve ser #RRGGBB.' }) color?: string;

  /**
   * Esta categoria tem FORNECEDOR do outro lado?
   *
   * Peças e manutenção têm; aluguel, imposto e salário não. É o que decide se o
   * cadastro de despesa oferece o campo de fornecedor — mostrá-lo em toda conta
   * era ruído em quase todas. Default `false`: quem cria uma categoria nova só
   * liga o switch quando faz sentido.
   */
  @IsOptional() @IsBoolean() tracksSupplier?: boolean;
}

export class UpdateExpenseCategoryDto {
  @IsOptional() @IsString() @MinLength(2) @MaxLength(40) name?: string;
  @IsOptional() @IsIn(ICON_KEYS as unknown as string[]) icon?: string;
  @IsOptional() @Matches(HEX, { message: 'Cor deve ser #RRGGBB.' }) color?: string;
  @IsOptional() @IsBoolean() tracksSupplier?: boolean;
  /** Desativar/reativar. Sem hard delete (regra 6). */
  @IsOptional() @IsIn(['active', 'disabled']) status?: 'active' | 'disabled';
}
