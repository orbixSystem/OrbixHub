import {
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { Type } from 'class-transformer';

export type InvoiceDocumentType = 'nfse' | 'nfce' | 'nfe';
export type InvoiceStatus =
  | 'draft'
  | 'processing'
  | 'authorized'
  | 'rejected'
  | 'canceled'
  | 'error';

/** Emite uma nota a partir de uma OS. Documento default = NFS-e (serviço). */
export class IssueInvoiceDto {
  @IsUUID()
  orderId!: string;

  // MVP = 'nfse'. Agnóstico p/ suportar produto (nfce/nfe) sem retrabalho.
  @IsOptional()
  @IsEnum(['nfse', 'nfce', 'nfe'])
  documentType?: InvoiceDocumentType;
}

export class ListInvoicesQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @IsEnum(['draft', 'processing', 'authorized', 'rejected', 'canceled', 'error'])
  status?: InvoiceStatus;

  @IsOptional()
  @IsUUID()
  orderId?: string;
}

export class CancelInvoiceDto {
  @IsString()
  @MinLength(3)
  @MaxLength(255)
  reason!: string;
}
