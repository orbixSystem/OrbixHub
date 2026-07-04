import {
  IsBoolean,
  IsInt,
  IsISO8601,
  IsOptional,
  IsUUID,
  Matches,
  Max,
  Min,
  Validate,
  ValidatorConstraint,
  ValidatorConstraintInterface,
} from 'class-validator';

@ValidatorConstraint({ name: 'multipleOf30', async: false })
class MultipleOf30 implements ValidatorConstraintInterface {
  validate(value: unknown) {
    return typeof value === 'number' && value % 30 === 0;
  }
  defaultMessage() {
    return 'estimatedDuration deve ser múltiplo de 30 minutos.';
  }
}

/** Atualiza um dia da semana no horário de funcionamento. */
export class UpdateBusinessHoursDto {
  @IsBoolean() isOpen!: boolean;
  /** Formato HH:MM (ex.: "08:00"). */
  @Matches(/^\d{2}:\d{2}$/, { message: 'openTime deve estar no formato HH:MM.' })
  openTime!: string;
  /** Formato HH:MM (ex.: "18:00"). */
  @Matches(/^\d{2}:\d{2}$/, { message: 'closeTime deve estar no formato HH:MM.' })
  closeTime!: string;
}

/** Agendamento de um item de OS (atribuição + horário + duração estimada). */
export class ScheduleItemDto {
  /** Técnico responsável (memberId do tenant). Null = desatribuir. */
  @IsOptional() @IsUUID() assignedTo?: string | null;
  /** Início do serviço (ISO-8601). Null = desagendar. */
  @IsOptional() @IsISO8601() scheduledStart?: string | null;
  /** Duração estimada em minutos (múltiplos de 30, máx 8 h). */
  @IsOptional() @IsInt() @Min(30) @Max(480) @Validate(MultipleOf30)
  estimatedDuration?: number | null;
}

/** Filtros da agenda (período obrigatório; técnico opcional). */
export class AgendaQueryDto {
  @IsISO8601() from!: string;
  @IsISO8601() to!: string;
  @IsOptional() @IsUUID() assignedTo?: string;
}
