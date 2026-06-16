import { IsIn, IsNumber, IsOptional, IsString, MaxLength, Min } from 'class-validator';

export class CreateMovementDto {
  @IsIn(['in', 'out', 'adjust']) type!: 'in' | 'out' | 'adjust';
  /** in/out: quantidade movimentada; adjust: saldo-alvo. Sempre >= 0. */
  @IsNumber() @Min(0) quantity!: number;
  @IsOptional() @IsString() @MaxLength(40) reason?: string;
  @IsOptional() @IsString() @MaxLength(2000) note?: string;
}
