import {
  IsIn,
  IsInt,
  IsNumber,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';

/** Os 7 estados do workflow da OS. */
export const OS_STATUSES = [
  'aberta',
  'aguardando_aprovacao',
  'aprovada',
  'em_execucao',
  'concluida',
  'entregue',
  'cancelada',
] as const;
export type OsStatus = (typeof OS_STATUSES)[number];

/**
 * Chaves de ordenação da lista/relatório de OS (contrato com o front). `recent`
 * é o default. Usado tanto na lista (`os/orders`) quanto no relatório de OS.
 */
export const OS_SORTS = [
  'recent',
  'oldest',
  'number_asc',
  'number_desc',
  'customer_asc',
  'customer_desc',
  'total_desc',
  'total_asc',
  'status',
] as const;
export type OsSort = (typeof OS_SORTS)[number];

/**
 * Cria OS. Cliente (e opcionalmente veículo/subject) são ponteiros — snapshot no service.
 * Caminho "cliente existente": passe `customerId` (+ opcional `subjectId`).
 * Caminho "cliente novo na hora": omita `customerId` e passe `newCustomerName`
 * (+ opcional telefone/veículo); o service cria cliente (e subject) via CustomersService.
 */
export class CreateOrderDto {
  @IsOptional() @IsUUID() customerId?: string;
  @IsOptional() @IsUUID() subjectId?: string;
  /** Cliente novo na hora: nome (obrigatório quando não há customerId). */
  @IsOptional() @IsString() @MaxLength(200) newCustomerName?: string;
  @IsOptional() @IsString() @MaxLength(40) newCustomerPhone?: string;
  /** Veículo novo: placa/identificação (genérico = identifier). */
  @IsOptional() @IsString() @MaxLength(120) newSubjectIdentifier?: string;
  /** Veículo novo: atributos do vertical (ex.: { marca, modelo }). */
  @IsOptional() @IsObject() newSubjectAttributes?: Record<string, unknown>;
  @IsOptional() @IsString() @MaxLength(2000) complaint?: string;
  @IsOptional() @IsString() @MaxLength(4000) diagnosis?: string;
  /** ISO date strings (previsão). */
  @IsOptional() @IsString() scheduledStart?: string;
  @IsOptional() @IsString() scheduledEnd?: string;
  @IsOptional() @IsUUID() assignedTo?: string;
}

/** Edita cabeçalho. NÃO altera status, cliente nem veículo. */
export class UpdateOrderDto {
  @IsOptional() @IsString() @MaxLength(2000) complaint?: string;
  @IsOptional() @IsString() @MaxLength(4000) diagnosis?: string;
  @IsOptional() @IsString() scheduledStart?: string;
  @IsOptional() @IsString() scheduledEnd?: string;
  @IsOptional() @IsUUID() assignedTo?: string;
  @IsOptional() @IsNumber() @Min(0) discount?: number;
}

export class ChangeStatusDto {
  @IsIn(OS_STATUSES) status!: OsStatus;
}

export class ListOrdersQueryDto {
  @IsOptional() @IsString() @MaxLength(120) q?: string;
  @IsOptional() @IsIn(OS_STATUSES) status?: OsStatus;
  @IsOptional() @IsUUID() customerId?: string;
  @IsOptional() @IsIn(OS_SORTS) sort?: OsSort;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  // Cap igual ao dos demais módulos — sem ele um cliente pode pedir uma
  // página arbitrariamente grande (full-table scan disfarçado).
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100)
  pageSize?: number;
}
