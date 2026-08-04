export interface VerificationEmail {
  to: string;
  token: string;
  kind: 'email_verify' | 'password_reset' | 'invite';
}

/**
 * Mensagem de e-mail já renderizada (assunto + corpo). Usada por quem tem um
 * conteúdo próprio — o link de acompanhamento da OS, por exemplo — enquanto os
 * fluxos de identidade continuam mandando `VerificationEmail` (kind + token),
 * que é o formato que o dev-inbox/besouro entende.
 */
export interface MailMessage {
  to: string;
  subject: string;
  html: string;
  text: string;
  /** Resposta do destinatário vai para cá (ex.: o e-mail da oficina). */
  replyTo?: string;
  /** Sobrescreve só o nome exibido no remetente (o endereço é sempre o nosso). */
  fromName?: string;
}

export abstract class MailerService {
  abstract send(email: VerificationEmail): Promise<void>;
  abstract sendMessage(message: MailMessage): Promise<void>;
}
