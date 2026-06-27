import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

/** Mensagem postada pelo cliente no chat público (sem auth). */
export class PostPublicMessageDto {
  @IsString()
  @MinLength(1, { message: 'A mensagem não pode ser vazia.' })
  @MaxLength(2000)
  body!: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  authorName?: string;
}
