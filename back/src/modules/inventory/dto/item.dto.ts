import {
  IsBoolean, IsIn, IsInt, IsNumber, IsOptional, IsString,
  Max, MaxLength, Min, MinLength,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreateItemDto {
  @IsIn(['product', 'service']) kind!: 'product' | 'service';
  @IsString() @MinLength(1) @MaxLength(200) name!: string;
  @IsOptional() @IsString() @MaxLength(60) code?: string;
  @IsOptional() @IsString() @MaxLength(60) barcode?: string;
  @IsOptional() @IsString() @MaxLength(120) category?: string;
  @IsOptional() @IsString() @MaxLength(20) unit?: string;
  @IsOptional() @IsInt() @Min(0) salePriceCents?: number;
  @IsOptional() @IsInt() @Min(0) costPriceCents?: number;
  @IsOptional() @IsNumber() @Min(0) @Max(100000) marginPercent?: number;
  @IsOptional() @IsBoolean() sellable?: boolean;
  @IsOptional() @IsBoolean() trackStock?: boolean;
  @IsOptional() @IsNumber() @Min(0) minQty?: number;
  @IsOptional() @IsInt() @Min(0) durationMinutes?: number;
  @IsOptional() @IsString() @MaxLength(120) brand?: string;
}

export class UpdateItemDto {
  // kind is immutable after creation; stock_qty is never set here (only via movements).
  @IsOptional() @IsString() @MinLength(1) @MaxLength(200) name?: string;
  @IsOptional() @IsString() @MaxLength(60) code?: string;
  @IsOptional() @IsString() @MaxLength(60) barcode?: string;
  @IsOptional() @IsString() @MaxLength(120) category?: string;
  @IsOptional() @IsString() @MaxLength(20) unit?: string;
  @IsOptional() @IsInt() @Min(0) salePriceCents?: number;
  @IsOptional() @IsInt() @Min(0) costPriceCents?: number;
  @IsOptional() @IsNumber() @Min(0) @Max(100000) marginPercent?: number;
  @IsOptional() @IsBoolean() sellable?: boolean;
  @IsOptional() @IsBoolean() trackStock?: boolean;
  @IsOptional() @IsNumber() @Min(0) minQty?: number;
  @IsOptional() @IsInt() @Min(0) durationMinutes?: number;
  @IsOptional() @IsString() @MaxLength(120) brand?: string;
}

export class ListItemsQueryDto {
  @IsOptional() @IsString() @MaxLength(120) q?: string;
  @IsOptional() @IsIn(['product', 'service']) kind?: 'product' | 'service';
  @IsOptional() @IsString() @MaxLength(120) category?: string;
  @IsOptional() @IsIn(['active', 'archived', 'all']) status?: 'active' | 'archived' | 'all';
  @IsOptional() @Type(() => Boolean) @IsBoolean() lowStock?: boolean;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) pageSize?: number;
}
