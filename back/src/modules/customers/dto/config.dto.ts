import {
  IsArray,
  IsBoolean,
  IsIn,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

export class SubjectLabelDto {
  @IsString() @MinLength(1) @MaxLength(40) singular!: string;
  @IsString() @MinLength(1) @MaxLength(40) plural!: string;
}

export class SubjectFieldDto {
  @IsString() @MinLength(1) @MaxLength(40) chave!: string;
  @IsString() @MinLength(1) @MaxLength(60) rotulo!: string;
  @IsIn(['text', 'number']) tipo!: 'text' | 'number';
  @IsBoolean() obrigatorio!: boolean;
  @IsOptional() @IsString() @MaxLength(40) fonte?: string;
  @IsOptional() @IsString() @MaxLength(40) dependeDe?: string;
  /** Máscara/validação da UI. Whitelist: só formatos que a UI implementa. */
  @IsOptional() @IsIn(['placa']) formato?: 'placa';
}

export class UpdateCustomersConfigDto {
  @IsOptional() @IsBoolean() usaSubjects?: boolean;
  @IsOptional() @IsBoolean() documentRequired?: boolean;
  @IsOptional()
  @ValidateNested()
  @Type(() => SubjectLabelDto)
  subjectLabel?: SubjectLabelDto;
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SubjectFieldDto)
  subjectFields?: SubjectFieldDto[];
}
