import { IsArray, IsBoolean, IsIn, IsOptional } from 'class-validator';
import { PAYMENT_METHODS } from '../cashier.config';

export class UpdateCashierConfigDto {
  @IsOptional()
  @IsArray()
  @IsIn(PAYMENT_METHODS as unknown as string[], { each: true })
  paymentMethods?: string[];

  @IsOptional() @IsBoolean() requireOpenSession?: boolean;
  @IsOptional() @IsBoolean() countCashOnly?: boolean;
}
