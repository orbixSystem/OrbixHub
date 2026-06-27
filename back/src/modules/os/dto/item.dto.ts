import {
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
} from 'class-validator';

/**
 * Item da OS: produto/serviço do estoque (via inventoryItemId → snapshot) ou avulso
 * (sem inventoryItemId, exige name). Validação cruzada (name obrigatório p/ avulso)
 * fica no service.
 */
export class CreateItemDto {
  @IsIn(['product', 'service']) kind!: 'product' | 'service';
  @IsOptional() @IsUUID() inventoryItemId?: string;
  /** Obrigatório quando não há inventoryItemId (avulso). */
  @IsOptional() @IsString() @MaxLength(200) name?: string;
  @IsOptional() @IsNumber() @Min(0) quantity?: number;
  @IsOptional() @IsNumber() @Min(0) unitPrice?: number;
  @IsOptional() @IsNumber() @Min(0) discount?: number;
}

export class UpdateItemDto {
  @IsOptional() @IsString() @MaxLength(200) name?: string;
  @IsOptional() @IsNumber() @Min(0) quantity?: number;
  @IsOptional() @IsNumber() @Min(0) unitPrice?: number;
  @IsOptional() @IsNumber() @Min(0) discount?: number;
}
