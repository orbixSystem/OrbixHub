import {
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
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

/** Cria OS. Cliente (e opcionalmente veículo/subject) são ponteiros — snapshot no service. */
export class CreateOrderDto {
  @IsUUID() customerId!: string;
  @IsOptional() @IsUUID() subjectId?: string;
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
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) pageSize?: number;
}
