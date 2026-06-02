export interface VerificationEmail {
  to: string;
  token: string;
  kind: 'email_verify' | 'password_reset' | 'invite';
}

export abstract class MailerService {
  abstract send(email: VerificationEmail): Promise<void>;
}
