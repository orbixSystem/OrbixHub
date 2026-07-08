import {
  IsEmail,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreateCustomerDto {
  /** Uuid gerado no cliente (replay offline preserva o id). Opcional. */
  @IsOptional() @IsUUID() id?: string;
  @IsString() @MinLength(1) @MaxLength(200) name!: string;
  @IsOptional() @IsIn(['PF', 'PJ']) type?: 'PF' | 'PJ';
  @IsOptional() @IsString() @MaxLength(60) document?: string;
  @IsOptional() @IsString() @MaxLength(40) phone?: string;
  @IsOptional() @IsEmail() email?: string;
  @IsOptional() @IsString() @MaxLength(300) address?: string;
  @IsOptional() @IsString() @MaxLength(2000) notes?: string;
}

export class UpdateCustomerDto {
  @IsOptional() @IsString() @MinLength(1) @MaxLength(200) name?: string;
  @IsOptional() @IsIn(['PF', 'PJ']) type?: 'PF' | 'PJ';
  // document: string limpa o documento (vira null); ausência = não mexe.
  @IsOptional() @IsString() @MaxLength(60) document?: string;
  @IsOptional() @IsString() @MaxLength(40) phone?: string;
  @IsOptional() @IsEmail() email?: string;
  @IsOptional() @IsString() @MaxLength(300) address?: string;
  @IsOptional() @IsString() @MaxLength(2000) notes?: string;
}

/** Chaves de ordenação da lista de clientes (contrato com o front). */
export const CUSTOMER_SORTS = [
  'recent',
  'oldest',
  'name_asc',
  'name_desc',
] as const;
export type CustomerSort = (typeof CUSTOMER_SORTS)[number];

export class ListCustomersQueryDto {
  /** Busca por nome / documento / telefone. */
  @IsOptional() @IsString() @MaxLength(120) q?: string;
  @IsOptional() @IsIn(['active', 'archived', 'all']) status?:
    | 'active'
    | 'archived'
    | 'all';
  @IsOptional() @IsIn(CUSTOMER_SORTS) sort?: CustomerSort;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) pageSize?: number;
}
