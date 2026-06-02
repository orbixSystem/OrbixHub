import { Inject, Injectable, UnauthorizedException } from '@nestjs/common';
import * as jwt from 'jsonwebtoken';
import { ENV } from '../config/config.module';
import type { Env } from '../config/env.schema';
import type { AccessTokenClaims } from './auth.types';

const ALG: jwt.Algorithm = 'HS256';

@Injectable()
export class AccessTokenService {
  constructor(@Inject(ENV) private readonly env: Env) {}

  sign(claims: AccessTokenClaims, ttl?: string): string {
    return jwt.sign(claims, this.env.JWT_ACCESS_SECRET, {
      algorithm: ALG,
      expiresIn: ttl ?? this.env.JWT_ACCESS_TTL,
    } as jwt.SignOptions);
  }

  verify(token: string): AccessTokenClaims {
    try {
      // algorithms allowlist => 'none' and asymmetric confusion are rejected.
      const decoded = jwt.verify(token, this.env.JWT_ACCESS_SECRET, {
        algorithms: [ALG],
      });
      return decoded as AccessTokenClaims;
    } catch {
      throw new UnauthorizedException();
    }
  }
}
