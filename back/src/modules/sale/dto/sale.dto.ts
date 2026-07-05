import {
  ArrayMinSize,
  IsArray,
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
  @IsOptional() @IsUUID() customerId?: string;
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

/** Filtros + paginação da lista de vendas. */
export class ListSalesQueryDto {
  @IsOptional() @IsIn(['active', 'canceled']) status?: 'active' | 'canceled';
  @IsOptional() @IsUUID() customerId?: string;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) pageSize?: number;
}
