import { createHash, randomBytes } from 'node:crypto';

/** Opaque, unguessable token (≈256 bits, url-safe base64). */
export function generateOpaqueToken(): string {
  return randomBytes(32).toString('base64url');
}

/** sha-256 hex — we only ever store the hash of opaque tokens. */
export function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}
