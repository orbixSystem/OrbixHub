import { IsString, MaxLength } from 'class-validator';

/** Query do fluxo código-first: GET /inventory/lookup?code=<barras/fabricante>. */
export class LookupQueryDto {
  @IsString() @MaxLength(64) code!: string;
}
