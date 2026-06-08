import { DevInboxService } from './dev-inbox.service';
import type { Env } from '../../common/config/env.schema';

const env = { APP_PUBLIC_URL: 'http://x', DEV_TOOLS_ENABLED: true } as never as Env;

describe('DevInboxService', () => {
  let service: DevInboxService;

  beforeEach(() => {
    service = new DevInboxService(env);
  });

  it('builds an invite value containing /#/convite/<token> using APP_PUBLIC_URL', () => {
    service.record('invite', 'abc123');
    const list = service.list();
    expect(list).toHaveLength(1);
    expect(list[0].type).toBe('invite');
    expect(list[0].value).toBe('http://x/#/convite/abc123');
  });

  it('stores the raw token as value for password_reset', () => {
    service.record('password_reset', 'reset-token-xyz');
    const entry = service.list().find((e) => e.type === 'password_reset');
    expect(entry?.value).toBe('reset-token-xyz');
  });

  it('keeps only the latest entry for the same kind', () => {
    service.record('email_verify', 'first');
    service.record('email_verify', 'second');
    const entries = service.list().filter((e) => e.type === 'email_verify');
    expect(entries).toHaveLength(1);
    expect(entries[0].value).toBe('second');
  });

  it('uses correct PT-BR labels', () => {
    service.record('invite', 't1');
    service.record('email_verify', 't2');
    service.record('password_reset', 't3');
    const byType = Object.fromEntries(
      service.list().map((e) => [e.type, e.label]),
    );
    expect(byType.invite).toBe('Link de convite');
    expect(byType.email_verify).toBe('Token de verificação de e-mail');
    expect(byType.password_reset).toBe('Token de reset de senha');
  });
});
