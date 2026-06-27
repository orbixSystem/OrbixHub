import { IsString, MaxLength, MinLength } from 'class-validator';

export class PostMessageDto {
  @IsString()
  @MinLength(1, { message: 'A mensagem não pode ser vazia.' })
  @MaxLength(4000)
  body!: string;
}
