import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsEnum,
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

export type PaymentMethod = 'dinheiro' | 'cartao' | 'pix' | 'outro';
export type SaleStatus = 'concluida' | 'cancelada';

/** Uma linha do carrinho: item do estoque (por id) OU avulso (nome + preço). */
export class SaleItemInputDto {
  @IsOptional() @IsUUID() inventoryItemId?: string;
  @IsOptional() @IsString() @MaxLength(200) name?: string;
  @IsOptional() @IsEnum(['product', 'service']) kind?: 'product' | 'service';
  @IsNumber() @Min(0.001) quantity!: number;
  @IsNumber() @Min(0) unitPrice!: number;
  @IsOptional() @IsNumber() @Min(0) discount?: number;
}

/** Fecha uma venda (checkout). Cliente opcional = consumidor final. */
export class CreateSaleDto {
  @IsOptional() @IsUUID() customerId?: string;

  @IsArray()
  @ArrayMinSize(1, { message: 'Adicione ao menos um item.' })
  @ValidateNested({ each: true })
  @Type(() => SaleItemInputDto)
  items!: SaleItemInputDto[];

  @IsOptional() @IsNumber() @Min(0) discount?: number;

  @IsEnum(['dinheiro', 'cartao', 'pix', 'outro'])
  paymentMethod!: PaymentMethod;
}

export class ListSalesQueryDto {
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @IsEnum(['concluida', 'cancelada']) status?: SaleStatus;
  @IsOptional() @IsUUID() customerId?: string;
}

export class CancelSaleDto {
  @IsString() @MinLength(3) @MaxLength(255) reason!: string;
}
