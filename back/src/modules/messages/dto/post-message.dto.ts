import {
  IsOptional,
  IsString,
  IsUrl,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';

export class PostMessageDto {
  @IsString()
  @MinLength(1, { message: 'A mensagem não pode ser vazia.' })
  @MaxLength(4000)
  body!: string;

  /** Citação: id da mensagem respondida (quote, estilo WhatsApp). */
  @IsOptional()
  @IsUUID()
  replyToId?: string;

  /** Foto da OS citada: id (ponteiro) + url (snapshot p/ a bolha). */
  @IsOptional()
  @IsUUID()
  photoId?: string;

  @IsOptional()
  @IsString()
  @IsUrl({ require_tld: false })
  @MaxLength(1000)
  photoUrl?: string;
}
