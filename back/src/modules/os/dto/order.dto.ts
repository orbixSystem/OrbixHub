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
  MinLength,
  ValidateIf,
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
 * Caminho "cliente existente": passe `customerId` (+ `subjectId` do veículo já
 * cadastrado, OU os campos `newSubject*` para cadastrar um veículo na hora).
 * Caminho "cliente novo na hora": omita `customerId` e passe `newCustomerName`
 * + `newCustomerPhone` (+ opcional veículo); o service cria cliente (e subject)
 * via CustomersService.
 */
export class CreateOrderDto {
  /** Uuid gerado no cliente (replay offline preserva o id). Opcional. */
  @IsOptional() @IsUUID() id?: string;
  @IsOptional() @IsUUID() customerId?: string;
  @IsOptional() @IsUUID() subjectId?: string;
  /** Cliente novo na hora: nome (obrigatório quando não há customerId). */
  @IsOptional() @IsString() @MaxLength(200) newCustomerName?: string;
  /**
   * Telefone do cliente novo — OBRIGATÓRIO neste caminho, igual ao cadastro
   * completo (é o contato da oficina com o cliente). Exigido só quando a OS de
   * fato cria um cliente; com `customerId` não se aplica.
   */
  @ValidateIf((o: CreateOrderDto) => !o.customerId && !!o.newCustomerName)
  @IsString()
  @MinLength(8)
  @MaxLength(40)
  newCustomerPhone!: string;
  /** Veículo novo: placa/identificação (genérico = identifier). */
  @IsOptional() @IsString() @MaxLength(120) newSubjectIdentifier?: string;
  /** Veículo novo: atributos do vertical (ex.: { marca, modelo }). */
  @IsOptional() @IsObject() newSubjectAttributes?: Record<string, unknown>;
  /**
   * Veículo novo: retorno da consulta por placa, guardado nas colunas
   * exclusivas do subject (alimenta a aba "Informações adicionais" e a ficha).
   */
  @IsOptional() @IsObject() newSubjectPlateData?: Record<string, unknown>;
  @IsOptional() @IsString() @MaxLength(2000) complaint?: string;
  @IsOptional() @IsString() @MaxLength(4000) diagnosis?: string;
  /** ISO date strings (previsão). */
  @IsOptional() @IsString() scheduledStart?: string;
  @IsOptional() @IsString() scheduledEnd?: string;
  @IsOptional() @IsUUID() assignedTo?: string;
  /**
   * Desconto do cabeçalho já na abertura — o atendente que fecha o orçamento
   * junto com o cliente não precisa criar a OS e depois editá-la só para isso.
   * O total é recalculado a cada item; aqui a OS nasce sem itens, então só o
   * desconto é gravado.
   */
  @IsOptional() @IsNumber() @Min(0) discount?: number;
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
  // Grupo de status (ex.: "aberta,aguardando_aprovacao,aprovada,em_execucao"
  // para o filtro "Em andamento" do front simplificado). Prevalece sobre
  // `status` quando presente; tokens fora de OS_STATUSES são ignorados.
  @IsOptional() @IsString() @MaxLength(200) statuses?: string;
  @IsOptional() @IsUUID() customerId?: string;
  @IsOptional() @IsIn(OS_SORTS) sort?: OsSort;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  // Cap igual ao dos demais módulos — sem ele um cliente pode pedir uma
  // página arbitrariamente grande (full-table scan disfarçado).
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100)
  pageSize?: number;
}
