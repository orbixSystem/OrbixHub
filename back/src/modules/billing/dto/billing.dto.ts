import { IsString, MinLength } from 'class-validator';

export class SubscribeDto {
  @IsString()
  @MinLength(1)
  planKey!: string;
}

export class ChangePlanDto {
  @IsString()
  @MinLength(1)
  planKey!: string;
}
