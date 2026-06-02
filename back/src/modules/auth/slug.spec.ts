import { validateSlug, RESERVED_SLUGS } from './slug';

describe('validateSlug', () => {
  it('accepts a valid slug', () => {
    expect(validateSlug('oficina-do-ze')).toBeNull();
  });
  it('rejects bad format', () => {
    expect(validateSlug('Oficina Do Zé')).toMatch(/formato/i);
    expect(validateSlug('ab')).toMatch(/formato/i);
  });
  it('rejects reserved slugs', () => {
    for (const r of RESERVED_SLUGS) expect(validateSlug(r)).toMatch(/reservado/i);
  });
});
