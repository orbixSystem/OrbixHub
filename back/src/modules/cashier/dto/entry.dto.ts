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
  /**
   * Min(0), não Min(0.01): com desconto na quitação, perdoar a dívida inteira é
   * um lançamento legítimo de valor zero em dinheiro. O par (amount, discount)
   * não pode ser zero nos dois — isso o service valida, porque é regra entre
   * campos e o class-validator só enxerga um de cada vez.
   */
  @IsNumber() @Min(0) amount!: number;
  /**
   * Desconto concedido na quitação. NÃO altera o total do documento — a dívida
   * fecha quando `amount + discount` cobre o saldo. Exige `cashier.discount` e
   * respeita o teto do tenant; ambos verificados no service.
   */
  @IsOptional() @IsNumber() @Min(0) discount?: number;
  @IsOptional() @IsString() @MaxLength(500) discountReason?: string;
  /**
   * Total do documento sendo quitado, informado por quem o conhece (o módulo
   * dono). O caixa não lê a tabela da OS/venda — regra de independência de
   * módulos —, então sem isto ele não tem denominador para o teto percentual.
   * Ausente: só o teto por valor é aplicado.
   */
  @IsOptional() @IsNumber() @Min(0) saleTotal?: number;
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

/**
 * Edição de campos **não-financeiros** de um lançamento: o que ele diz, não
 * quanto ele vale. Corrigir R$ 50 → R$ 45 NÃO passa aqui — passa por
 * [CorrectEntryDto], que estorna e relança, preservando a trilha.
 *
 * `category` é aceita só quando não muda a DIREÇÃO do lançamento (despesa ⇄
 * sangria, ambas saída). Trocar despesa por suprimento inverteria entrada/saída
 * e alteraria o saldo do caixa sem nenhum registro — isso é mudança financeira.
 */
export class UpdateEntryDto {
  @IsOptional() @IsString() @MaxLength(500) description?: string;
  @IsOptional()
  @IsIn(ENTRY_CATEGORIES as unknown as string[])
  category?: EntryCategory;
}

/**
 * Correção de um lançamento errado: estorna o original (com motivo) e cria um
 * novo com os valores certos, numa única operação. É o "editar" do dinheiro —
 * o livro caixa não apaga um movimento, ele registra a correção.
 *
 * Campos ausentes herdam do lançamento original (corrigir só o valor é o caso
 * comum). O motivo é obrigatório: é ele que explica o estorno no histórico.
 */
export class CorrectEntryDto {
  @IsString() @MinLength(3) @MaxLength(500) reason!: string;
  @IsOptional() @IsNumber() @Min(0) amount?: number;
  @IsOptional() @IsNumber() @Min(0) discount?: number;
  @IsOptional() @IsString() @MaxLength(500) discountReason?: string;
  @IsOptional() @IsIn(PAYMENT_METHODS as unknown as string[]) method?: PaymentMethod;
  @IsOptional()
  @IsIn(ENTRY_CATEGORIES as unknown as string[])
  category?: EntryCategory;
  @IsOptional() @IsString() @MaxLength(500) description?: string;
  /** Uuid do lançamento NOVO, gerado no cliente (replay offline). */
  @IsOptional() @IsUUID() newId?: string;
}
