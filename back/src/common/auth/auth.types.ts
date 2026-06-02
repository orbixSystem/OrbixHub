export type RoleKey = 'owner' | 'mechanic';

export interface AccessTokenClaims {
  sub: string; // userId
  tid: string; // tenantId
  role: RoleKey;
  jti: string;
}

/** What guards attach to req.user after verifying the access token. */
export interface AuthUser {
  userId: string;
  tenantId: string;
  role: RoleKey;
  jti: string;
}
