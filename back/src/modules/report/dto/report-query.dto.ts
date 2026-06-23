import {
  IsIn,
  IsInt,
  IsISO8601,
  IsOptional,
  IsUUID,
  Max,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';
import { OS_STATUSES, type OsStatus } from '../../os/dto/order.dto';

/**
 * Query base dos relatórios: range ISO opcional (default últimos 30 dias,
 * resolvido no controller via resolveRange). Whitelist via ValidationPipe.
 */
export class ReportRangeQueryDto {
  @IsOptional() @IsISO8601() from?: string;
  @IsOptional() @IsISO8601() to?: string;
}

/** Query do relatório operacional de OS: range + filtros técnico/status. */
export class ReportOsQueryDto extends ReportRangeQueryDto {
  @IsOptional() @IsUUID() assignedTo?: string;
  @IsOptional() @IsIn(OS_STATUSES) status?: OsStatus;
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
