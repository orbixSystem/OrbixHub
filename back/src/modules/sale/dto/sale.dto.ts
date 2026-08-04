import {
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { SaleItemKind } from '../sale.config';

/**
 * Uma linha da venda. Item do estoque (`inventoryItemId`) faz snapshot de
 * nome/preço via service público (não toca a tabela alheia); item avulso exige
 * `name`. `unitPrice` opcional → cai no preço de venda do estoque.
 */
export class CreateSaleItemDto {
  @IsOptional() @IsUUID() inventoryItemId?: string;
  @IsOptional() @IsString() @MaxLength(200) name?: string;
  @IsOptional() @IsIn(['product', 'service']) kind?: SaleItemKind;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0.001) quantity?: number;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0) unitPrice?: number;
}

/**
 * Cria uma venda de balcão. Cliente OPCIONAL (balcão pode ser sem cadastro).
 * Pelo menos 1 item. Pagamento e nota são passos posteriores (caixa/fiscal).
 */
export class CreateSaleDto {
  /**
   * Uuid gerado no cliente, preservado no replay (venda criada offline). Mesmo
   * padrão do `CreateOrderDto`: sem ele o aparelho ficaria com uma venda local
   * que nunca casa com a do servidor.
   */
  @IsOptional() @IsUUID() id?: string;
  @IsOptional() @IsUUID() customerId?: string;
  /** Desconto em valor sobre o total da venda (≥ 0). O service clampa ao bruto. */
  @IsOptional() @IsNumber() @Min(0) discount?: number;
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => CreateSaleItemDto)
  items!: CreateSaleItemDto[];
}

/** Cancelamento lógico (estorna estoque). Motivo opcional. */
export class CancelSaleDto {
  @IsOptional() @IsString() @MinLength(3) @MaxLength(500) reason?: string;
}

/**
 * Edição de uma venda registrada: cliente, itens e desconto.
 *
 * `customerId: null` desvincula. Trocar o cliente resolve o fiado lançado sem
 * identificar quem levou — sem isso a dívida fica presa no balde "sem cliente".
 *
 * `items` SUBSTITUI as linhas da venda (não faz merge): o front manda a lista
 * inteira, como na criação. O total é recalculado no servidor e o estoque
 * reconciliado — nunca confiamos no total do cliente.
 *
 * O service recusa a edição quando ela quebraria algo que já saiu da venda:
 * nota fiscal emitida (a NF passaria a divergir) ou total menor do que o cliente
 * já pagou (ficaríamos devendo troco, e não há mecanismo para isso).
 */
export class UpdateSaleDto {
  @IsOptional() @IsUUID() customerId?: string | null;
  /** Desconto em valor sobre o total (≥ 0). O service clampa ao bruto. */
  @IsOptional() @IsNumber() @Min(0) discount?: number;
  /** Lista COMPLETA de itens da venda (substitui a atual). */
  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => CreateSaleItemDto)
  items?: CreateSaleItemDto[];
}

/**
 * Filtros + paginação da lista de vendas. `from`/`to` recortam por
 * `created_at` — sem eles não há como responder "o que vendi neste período",
 * que é a pergunta do histórico de vendas. `q` busca por número da venda ou
 * nome do cliente (o snapshot gravado na venda).
 */
export class ListSalesQueryDto {
  @IsOptional() @IsIn(['active', 'canceled']) status?: 'active' | 'canceled';
  @IsOptional() @IsUUID() customerId?: string;
  @IsOptional() @IsString() @MaxLength(120) q?: string;
  @IsOptional() @IsDateString() from?: string;
  @IsOptional() @IsDateString() to?: string;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) pageSize?: number;
}
