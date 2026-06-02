export const RESERVED_SLUGS = [
  'api',
  'www',
  'admin',
  'app',
  'auth',
  'billing',
  'health',
];
const SLUG_RE = /^[a-z0-9-]{3,40}$/;

/** Returns an error message, or null if valid. */
export function validateSlug(slug: string): string | null {
  if (!SLUG_RE.test(slug)) {
    return 'Slug inválido: use 3–40 caracteres minúsculos, números ou hífen (formato ^[a-z0-9-]{3,40}$).';
  }
  if (RESERVED_SLUGS.includes(slug)) return 'Slug reservado, escolha outro.';
  return null;
}
