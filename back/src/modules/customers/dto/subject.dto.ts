import {
  IsInt,
  IsIn,
  IsObject,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreateSubjectDto {
  @IsOptional() @IsString() @MaxLength(200) label?: string;
  /** Genérico/indexado — é a placa na oficina. */
  @IsOptional() @IsString() @MaxLength(120) identifier?: string;
  /** Específico do vertical (marca/modelo/ano/cor/km na oficina). */
  @IsOptional() @IsObject() attributes?: Record<string, unknown>;
}

export class UpdateSubjectDto {
  @IsOptional() @IsString() @MaxLength(200) label?: string;
  @IsOptional() @IsString() @MaxLength(120) identifier?: string;
  @IsOptional() @IsObject() attributes?: Record<string, unknown>;
}

export class ListSubjectsQueryDto {
  /** Busca por `identifier` (placa). */
  @IsOptional() @IsString() @MaxLength(120) q?: string;
  @IsOptional() @IsString() customerId?: string;
  @IsOptional() @IsIn(['active', 'archived', 'all']) status?:
    | 'active'
    | 'archived'
    | 'all';
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) pageSize?: number;
}
