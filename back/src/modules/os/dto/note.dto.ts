import { IsBoolean, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

/**
 * Nota manual na timeline da OS. `visiblePublic` controla se a nota aparece na
 * página pública de acompanhamento (default: false — interna).
 */
export class CreateNoteDto {
  @IsString() @MinLength(1) @MaxLength(4000) message!: string;
  @IsOptional() @IsBoolean() visiblePublic?: boolean;
}
