import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AccessTokenService } from './jwt.service';
import { IS_PUBLIC } from './decorators';
import type { AuthUser } from './auth.types';

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly tokens: AccessTokenService,
  ) {}

  canActivate(ctx: ExecutionContext): boolean {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC, [
      ctx.getHandler(),
      ctx.getClass(),
    ]);
    if (isPublic) return true;

    const req = ctx.switchToHttp().getRequest();
    const header: string | undefined = req.headers.authorization;
    if (!header?.startsWith('Bearer ')) throw new UnauthorizedException();
    const claims = this.tokens.verify(header.slice(7)); // throws on invalid/alg:none/expired
    const user: AuthUser = {
      userId: claims.sub,
      tenantId: claims.tid,
      role: claims.role,
      jti: claims.jti,
    };
    req.user = user; // tid is now trusted (from verified token)
    return true;
  }
}
