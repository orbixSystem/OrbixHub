import {
  ArrayMaxSize,
  IsArray,
  IsISO8601,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

/**
 * Uma mutação do outbox offline. `payload` é validado numa SEGUNDA passada,
 * contra o DTO do módulo dono (whitelist S7), depois de resolvida a op no
 * registry — aqui só garantimos que é um objeto. `clientUpdatedAt` é o relógio
 * do cliente (clampado no servidor para o LWW — S2).
 */
export class SyncMutationDto {
  @IsUUID() clientMutationId!: string;
  @IsString() @MaxLength(64) entity!: string;
  @IsString() @MaxLength(64) op!: string;
  @IsObject() payload!: Record<string, unknown>;
  @IsISO8601() clientUpdatedAt!: string;
}

/**
 * Corpo do `POST /sync/push`. `authorUserId` é a autoria do lote (S1: precisa
 * casar com o usuário autenticado). `mutations` é limitado a 100 (S10, anti-DoS).
 */
export class PushDto {
  @IsUUID() authorUserId!: string;
  @IsArray()
  @ArrayMaxSize(100)
  @ValidateNested({ each: true })
  @Type(() => SyncMutationDto)
  mutations!: SyncMutationDto[];
}

/**
 * Query do `GET /sync/changes` (pull incremental). `sinceTs`+`sinceId` formam o
 * cursor opaco devolvido no `nextCursor` anterior (só valem juntos). `limit` é
 * clampado a [1,500] no servidor (A4 já clampa; reforçamos aqui — S10).
 */
export class PullChangesQueryDto {
  @IsString() @MaxLength(64) entity!: string;
  /** Cursor (texto ISO com microssegundos) devolvido pelo pull anterior. */
  @IsOptional() @IsString() @MaxLength(64) sinceTs?: string;
  @IsOptional() @IsUUID() sinceId?: string;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) limit?: number;
}

/**
 * DTO vazio para ops de replay sem corpo (archive/unarchive/delete, deleteItem,
 * applyTemplate). Depois de extrair as chaves estruturais (id/itemId/…), o resto
 * do payload precisa ser {} — qualquer campo extra dispara `forbidNonWhitelisted`
 * na segunda passada de validação (S7).
 */
export class EmptyPayloadDto {}
