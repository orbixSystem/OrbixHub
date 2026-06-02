import { PasswordService } from './password.service';
import type { Env } from '../config/env.schema';

const env = {
  ARGON_MEMORY_KIB: 19456,
  ARGON_TIME_COST: 2,
  ARGON_PARALLELISM: 1,
} as unknown as Env;

describe('PasswordService', () => {
  const svc = new PasswordService(env);
  it('hashes and verifies a correct password', async () => {
    const hash = await svc.hash('correct horse battery');
    expect(hash).toContain('$argon2id$');
    expect(await svc.verify(hash, 'correct horse battery')).toBe(true);
  });
  it('rejects a wrong password', async () => {
    const hash = await svc.hash('correct horse battery');
    expect(await svc.verify(hash, 'wrong')).toBe(false);
  });
});
