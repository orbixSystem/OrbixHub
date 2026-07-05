import {
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';

/**
 * Query do inbox de conversas: busca (título/rótulo da OS) + paginação para o
 * scroll infinito na tela. Whitelist via ValidationPipe.
 */
export class ListConversationsQueryDto {
  @IsOptional() @IsString() @MaxLength(120) q?: string;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) pageSize?: number;
}

/**
 * Query da thread: cursor `before` = created_at (ISO) da mensagem mais antiga
 * já carregada — retorna a página anterior (threads nunca sem limite).
 */
export class GetThreadQueryDto {
  @IsOptional() @IsISO8601() before?: string;
}
