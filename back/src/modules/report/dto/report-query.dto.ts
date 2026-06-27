import {
  IsIn,
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';
import {
  OS_SORTS,
  OS_STATUSES,
  type OsSort,
  type OsStatus,
} from '../../os/dto/order.dto';

/**
 * Query base dos relatórios: range ISO opcional (default últimos 30 dias,
 * resolvido no controller via resolveRange). Whitelist via ValidationPipe.
 */
export class ReportRangeQueryDto {
  @IsOptional() @IsISO8601() from?: string;
  @IsOptional() @IsISO8601() to?: string;
}

/**
 * Query do relatório operacional de OS: range + filtros técnico/status +
 * busca/ordenação + paginação (scroll infinito na tela; evita carregar milhares
 * de linhas de uma vez).
 */
export class ReportOsQueryDto extends ReportRangeQueryDto {
  @IsOptional() @IsUUID() assignedTo?: string;
  @IsOptional() @IsIn(OS_STATUSES) status?: OsStatus;
  @IsOptional() @IsIn(OS_SORTS) sort?: OsSort;
  @IsOptional() @IsString() @MaxLength(120) q?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  pageSize?: number;
}

/**
 * Query do export de OS (CSV/PDF do relatório COMPLETO): mesmos filtros da OS
 * (range + técnico + status + busca + ordenação) + empresa (cabeçalho do PDF).
 * Sem paginação — o servidor gera o relatório inteiro respeitando os filtros.
 */
export class ReportOsExportQueryDto extends ReportRangeQueryDto {
  @IsOptional() @IsUUID() assignedTo?: string;
  @IsOptional() @IsIn(OS_STATUSES) status?: OsStatus;
  @IsOptional() @IsIn(OS_SORTS) sort?: OsSort;
  @IsOptional() @IsString() @MaxLength(120) q?: string;
  @IsOptional() @IsString() @MaxLength(160) companyName?: string;
  @IsOptional() @IsString() @MaxLength(200) companyLegalName?: string;
  @IsOptional() @IsString() @MaxLength(40) companyCnpj?: string;
}

/** Query da posição de estoque (tela): página + tamanho + busca opcional. */
export class ReportInventoryQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  pageSize?: number;

  @IsOptional() @IsString() @MaxLength(120) q?: string;
}

/** Query do export de estoque (CSV/PDF): empresa (cabeçalho do PDF) + busca. */
export class ReportInventoryExportQueryDto {
  @IsOptional() @IsString() @MaxLength(160) companyName?: string;
  @IsOptional() @IsString() @MaxLength(200) companyLegalName?: string;
  @IsOptional() @IsString() @MaxLength(40) companyCnpj?: string;
  @IsOptional() @IsString() @MaxLength(120) q?: string;
}

/** Query do top de itens: range + kind (produto/serviço) + limit. */
export class ReportTopItemsQueryDto extends ReportRangeQueryDto {
  @IsOptional() @IsIn(['product', 'service']) kind?: 'product' | 'service';
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;
}
