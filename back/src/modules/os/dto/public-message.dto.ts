import {
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';

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

  /** Citação: id da mensagem respondida (validado contra a conversa no servidor). */
  @IsOptional()
  @IsUUID()
  replyToId?: string;

  /** Foto citada: id de uma foto DESTA OS. A url é resolvida no servidor (nunca
   * confia em url do cliente — evita injeção de imagem arbitrária). */
  @IsOptional()
  @IsUUID()
  photoId?: string;
}

/** Comentário do cliente numa foto da OS (thread pública, sem auth). */
export class PostPublicPhotoCommentDto {
  @IsString()
  @MinLength(1, { message: 'O comentário não pode ser vazio.' })
  @MaxLength(2000)
  body!: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  authorName?: string;
}
