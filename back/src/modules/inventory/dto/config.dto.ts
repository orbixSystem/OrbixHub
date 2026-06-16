import { IsArray, IsBoolean, IsNumber, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

export class UpdateInventoryConfigDto {
  @IsOptional() @IsString() @MaxLength(20) defaultUnit?: string;
  @IsOptional() @IsBoolean() trackStockDefault?: boolean;
  @IsOptional() @IsNumber() @Min(0) @Max(100000) defaultMarginPercent?: number | null;
  @IsOptional() @IsArray() @IsString({ each: true }) categories?: string[];
}
