import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { PrismaService } from '../database/prisma.service';
import type { AuthUser } from './auth.types';

/**
 * Verifies, on every authenticated request, that the caller's membership in the
 * token's tenant is still active and non-expired. The access token lives 15min
 * and carries no live session state, so without this a member deactivated (or
 * whose access expired) mid-session kept working until the token expired. Runs
 * after [JwtAuthGuard]; public routes have no `req.user` and pass through (the
 * JWT guard already let them in).
 */
@Injectable()
export class ActiveMembershipGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest();
    const user = req.user as AuthUser | undefined;
    if (!user) return true; // @Public route — JwtAuthGuard already allowed it.

    // SECURITY DEFINER predicate (bypasses RLS); checks status + access expiry.
    const rows = await this.prisma.$queryRaw<Array<{ active: boolean }>>`
      SELECT auth_membership_active(${user.userId}::uuid, ${user.tenantId}::uuid) AS active
    `;
    if (!rows[0]?.active) {
      throw new UnauthorizedException('Acesso revogado.');
    }
    return true;
  }
}
