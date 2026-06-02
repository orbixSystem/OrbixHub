import { AccessTokenService } from './jwt.service';
import type { Env } from '../config/env.schema';

const env = {
  JWT_ACCESS_SECRET: 'x'.repeat(40),
  JWT_ACCESS_TTL: '15m',
} as unknown as Env;

describe('AccessTokenService', () => {
  const svc = new AccessTokenService(env);

  it('signs and verifies a token', () => {
    const token = svc.sign({ sub: 'u1', tid: 't1', role: 'owner', jti: 'j1' });
    const claims = svc.verify(token);
    expect(claims.sub).toBe('u1');
    expect(claims.tid).toBe('t1');
    expect(claims.role).toBe('owner');
  });

  it('rejects a token signed with alg:none', () => {
    // header {"alg":"none"} . payload . (empty sig)
    const header = Buffer.from(
      JSON.stringify({ alg: 'none', typ: 'JWT' }),
    ).toString('base64url');
    const payload = Buffer.from(
      JSON.stringify({ sub: 'u1', tid: 't1', role: 'owner', jti: 'j' }),
    ).toString('base64url');
    const forged = `${header}.${payload}.`;
    expect(() => svc.verify(forged)).toThrow();
  });

  it('rejects an expired token', () => {
    const token = svc.sign(
      { sub: 'u1', tid: 't1', role: 'owner', jti: 'j1' },
      '-1s',
    );
    expect(() => svc.verify(token)).toThrow();
  });
});
