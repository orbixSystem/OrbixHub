import { hashToken, generateOpaqueToken } from './tokens';

describe('tokens', () => {
  it('generateOpaqueToken returns a long url-safe string', () => {
    const t = generateOpaqueToken();
    expect(t).toMatch(/^[A-Za-z0-9_-]+$/);
    expect(t.length).toBeGreaterThanOrEqual(43);
  });
  it('hashToken is deterministic sha-256 hex', () => {
    expect(hashToken('abc')).toBe(hashToken('abc'));
    expect(hashToken('abc')).toHaveLength(64);
    expect(hashToken('abc')).not.toBe(hashToken('abd'));
  });
});
