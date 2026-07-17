import {
  IsBoolean, IsIn, IsInt, IsNumber, IsObject, IsOptional, IsString,
  Max, MaxLength, Min, MinLength,
} from 'class-validator';
import { Type } from 'class-transformer';
import type { ItemSort } from '../inventory.repository';

/**
 * Produto (item com estoque). Decimais (não centavos). Sem kind/sellable/track_stock/
 * duration. `attributes` é validado dinamicamente no service contra `itemFields`.
 */
export class CreateInventoryItemDto {
  @IsString() @MinLength(1) @MaxLength(200) name!: string;
  @IsOptional() @IsIn(['product', 'service']) kind?: 'product' | 'service';
  @IsOptional() @IsInt() @Min(0) durationMinutes?: number;
  @IsOptional() @IsString() @MaxLength(60) sku?: string;
  @IsOptional() @IsString() @MaxLength(60) manufacturerCode?: string;
  @IsOptional() @IsString() @MaxLength(60) barcode?: string;
  @IsOptional() @IsString() @MaxLength(120) category?: string;
  @IsOptional() @IsString() @MaxLength(120) brand?: string;
  @IsOptional() @IsString() @MaxLength(20) unit?: string;
  @IsOptional() @IsNumber() @Min(0) salePrice?: number;
  @IsOptional() @IsNumber() @Min(0) costPrice?: number;
  @IsOptional() @IsNumber() @Min(0) @Max(100000) marginPct?: number;
  @IsOptional() @IsNumber() @Min(0) currentStock?: number;
  @IsOptional() @IsNumber() @Min(0) minStock?: number;
  /** Classificação fiscal — produto (ncm/cfop/origem/gtin) OU serviço (codigoServico/aliquotaIss), gated por `kind` no service. */
  @IsOptional() @IsString() @MaxLength(8) ncm?: string;
  @IsOptional() @IsString() @MaxLength(4) cfop?: string;
  @IsOptional() @IsString() @MaxLength(1) origem?: string;
  @IsOptional() @IsString() @MaxLength(14) gtin?: string;
  @IsOptional() @IsString() @MaxLength(10) codigoServico?: string;
  @IsOptional() @IsNumber() @Min(0) @Max(100) aliquotaIss?: number;
  /** Campos da vertical — validados dinâmico no service contra itemFields. */
  @IsOptional() @IsObject() attributes?: Record<string, unknown>;
}

export class UpdateInventoryItemDto {
  @IsOptional() @IsString() @MinLength(1) @MaxLength(200) name?: string;
  @IsOptional() @IsInt() @Min(0) durationMinutes?: number;
  @IsOptional() @IsString() @MaxLength(60) sku?: string;
  @IsOptional() @IsString() @MaxLength(60) manufacturerCode?: string;
  @IsOptional() @IsString() @MaxLength(60) barcode?: string;
  @IsOptional() @IsString() @MaxLength(120) category?: string;
  @IsOptional() @IsString() @MaxLength(120) brand?: string;
  @IsOptional() @IsString() @MaxLength(20) unit?: string;
  @IsOptional() @IsNumber() @Min(0) salePrice?: number;
  @IsOptional() @IsNumber() @Min(0) costPrice?: number;
  @IsOptional() @IsNumber() @Min(0) @Max(100000) marginPct?: number;
  @IsOptional() @IsNumber() @Min(0) currentStock?: number;
  @IsOptional() @IsNumber() @Min(0) minStock?: number;
  /** Classificação fiscal — produto (ncm/cfop/origem/gtin) OU serviço (codigoServico/aliquotaIss), gated por `kind` (imutável) no service. */
  @IsOptional() @IsString() @MaxLength(8) ncm?: string;
  @IsOptional() @IsString() @MaxLength(4) cfop?: string;
  @IsOptional() @IsString() @MaxLength(1) origem?: string;
  @IsOptional() @IsString() @MaxLength(14) gtin?: string;
  @IsOptional() @IsString() @MaxLength(10) codigoServico?: string;
  @IsOptional() @IsNumber() @Min(0) @Max(100) aliquotaIss?: number;
  @IsOptional() @IsObject() attributes?: Record<string, unknown>;
}

/** Query de GET /inventory/sku-suggestion?name=<nome do produto>. */
export class SkuSuggestionQueryDto {
  @IsString() @MinLength(1) @MaxLength(200) name!: string;
}

export class ItemQueryDto {
  @IsOptional() @IsString() @MaxLength(120) q?: string;
  @IsOptional() @IsIn(['product', 'service']) kind?: 'product' | 'service';
  @IsOptional() @IsString() @MaxLength(120) category?: string;
  @IsOptional() @Type(() => Boolean) @IsBoolean() lowStock?: boolean;
  /** 'true' (padrão: só ativos), 'false' (só arquivados), 'all'. */
  @IsOptional() @IsIn(['true', 'false', 'all']) active?: 'true' | 'false' | 'all';
  /** Ordenação da lista. Default: nome A–Z. Ver ItemSort no repository. */
  @IsOptional()
  @IsIn([
    'name_asc', 'name_desc', 'price_desc', 'price_asc',
    'stock_desc', 'stock_asc', 'recent',
  ])
  sort?: ItemSort;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) pageSize?: number;
}
