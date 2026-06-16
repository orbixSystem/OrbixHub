import {
  IsArray, IsBoolean, IsIn, IsOptional, IsString,
  MaxLength, MinLength, ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import type { ItemFieldType } from '../inventory.config';

/** Um campo da vertical (espelha ItemFieldConfig). */
export class ItemFieldDto {
  @IsString() @MinLength(1) @MaxLength(40) key!: string;
  @IsString() @MinLength(1) @MaxLength(60) label!: string;
  @IsIn(['text', 'number', 'tags', 'select']) type!: ItemFieldType;
  @IsBoolean() required!: boolean;
  @IsOptional() @IsArray() @IsString({ each: true }) options?: string[];
}

export class UpdateInventoryConfigDto {
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ItemFieldDto)
  itemFields?: ItemFieldDto[];
}
