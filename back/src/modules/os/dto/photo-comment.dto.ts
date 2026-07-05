import { IsString, MaxLength, MinLength } from 'class-validator';

/** Comentário do staff numa foto da OS (thread). */
export class PostPhotoCommentDto {
  @IsString()
  @MinLength(1, { message: 'O comentário não pode ser vazio.' })
  @MaxLength(2000)
  body!: string;
}
