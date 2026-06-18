import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  MinLength,
  ValidateNested,
} from 'class-validator';

/**
 * Item de um template de serviço: produto/serviço do estoque (via inventoryItemId →
 * snapshot de nome/preço) ou avulso (sem inventoryItemId, exige name). Validação
 * cruzada (name obrigatório p/ avulso) fica no service.
 */
export class TemplateItemDto {
  @IsIn(['product', 'service']) kind!: 'product' | 'service';
  @IsOptional() @IsUUID() inventoryItemId?: string;
  /** Obrigatório quando não há inventoryItemId (avulso). */
  @IsOptional() @IsString() @MaxLength(200) name?: string;
  @IsOptional() @IsNumber() @Min(0) quantity?: number;
  @IsOptional() @IsNumber() @Min(0) unitPrice?: number;
}

export class CreateTemplateDto {
  @IsString() @MinLength(1) @MaxLength(200) name!: string;
  @IsOptional() @IsString() @MaxLength(2000) description?: string;
  @IsArray()
  @ArrayMaxSize(100)
  @ValidateNested({ each: true })
  @Type(() => TemplateItemDto)
  items!: TemplateItemDto[];
}

export class UpdateTemplateDto {
  @IsOptional() @IsString() @MinLength(1) @MaxLength(200) name?: string;
  @IsOptional() @IsString() @MaxLength(2000) description?: string;
  /** Quando presente, substitui integralmente os itens do template. */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(100)
  @ValidateNested({ each: true })
  @Type(() => TemplateItemDto)
  items?: TemplateItemDto[];
}
