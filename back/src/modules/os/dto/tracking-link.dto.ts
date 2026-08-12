import { IsEmail, MaxLength } from 'class-validator';

/**
 * Envio do link público de acompanhamento por e-mail. O endereço vem do corpo
 * (o atendente confirma/corrige o e-mail do cliente na hora do envio) — não é
 * lido do cadastro cegamente. Enviar aqui NÃO altera o cadastro do cliente.
 */
export class SendTrackingLinkDto {
  @IsEmail({}, { message: 'Informe um e-mail válido.' })
  @MaxLength(255)
  email!: string;
}
