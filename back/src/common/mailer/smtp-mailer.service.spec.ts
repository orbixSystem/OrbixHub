type SentMail = Record<string, string | undefined>;
const sendMail = jest.fn(async (_options: SentMail) => ({
  messageId: '<id@x>',
}));
jest.mock('nodemailer', () => ({
  createTransport: jest.fn(() => ({ sendMail })),
}));

import { createTransport } from 'nodemailer';
import { SmtpMailerService } from './smtp-mailer.service';
import type { Env } from '../config/env.schema';

const env = {
  SMTP_HOST: 'smtp.gmail.com',
  SMTP_PORT: 587,
  SMTP_SECURE: false,
  SMTP_USER: 'conta@orbixsystem.com',
  SMTP_PASS: 'senhadeapp16car',
  MAIL_FROM_ADDRESS: 'conta@orbixsystem.com',
  MAIL_FROM_NAME: 'OrbixHub',
  APP_PUBLIC_URL: 'https://hub.orbixsystem.com',
} as unknown as Env;

describe('SmtpMailerService', () => {
  beforeEach(() => jest.clearAllMocks());

  it('connects with STARTTLS settings and the app password', () => {
    new SmtpMailerService(env);
    expect(createTransport).toHaveBeenCalledWith({
      host: 'smtp.gmail.com',
      port: 587,
      secure: false,
      auth: { user: 'conta@orbixsystem.com', pass: 'senhadeapp16car' },
    });
  });

  it('sends the reset mail with both parts and a link built from APP_PUBLIC_URL', async () => {
    await new SmtpMailerService(env).send({
      to: 'cliente@x.com',
      token: 'tok123',
      kind: 'password_reset',
    });
    const sent = sendMail.mock.calls[0][0];
    expect(sent.to).toBe('cliente@x.com');
    expect(sent.from).toBe('"OrbixHub" <conta@orbixsystem.com>');
    expect(sent.html).toContain(
      'https://hub.orbixsystem.com/#/reset?token=tok123',
    );
    expect(sent.text).toContain(
      'https://hub.orbixsystem.com/#/reset?token=tok123',
    );
  });

  it('never leaks the token into the log line', async () => {
    const logged: string[] = [];
    const svc = new SmtpMailerService(env);
    (svc as never as { log: { log: (m: string) => void } }).log = {
      log: (m: string) => logged.push(m),
    } as never;
    await svc.send({ to: 'a@b.com', token: 'segredo', kind: 'invite' });
    expect(logged.join(' ')).not.toContain('segredo');
  });

  it('keeps our address as sender but honors fromName and replyTo', async () => {
    await new SmtpMailerService(env).sendMessage({
      to: 'cliente@x.com',
      subject: 'Acompanhe sua OS',
      html: '<p>oi</p>',
      text: 'oi',
      replyTo: 'oficina@exemplo.com',
      fromName: 'Oficina do Ze',
    });
    const sent = sendMail.mock.calls[0][0];
    expect(sent.from).toBe('"Oficina do Ze" <conta@orbixsystem.com>');
    expect(sent.replyTo).toBe('oficina@exemplo.com');
  });

  it('rethrows so the caller decides — identity flows swallow it on purpose', async () => {
    sendMail.mockRejectedValueOnce(new Error('535 auth failed') as never);
    const svc = new SmtpMailerService(env);
    (svc as never as { log: { error: () => void } }).log = {
      error: () => undefined,
    } as never;
    await expect(
      svc.send({ to: 'a@b.com', token: 't', kind: 'email_verify' }),
    ).rejects.toThrow('535 auth failed');
  });
});
