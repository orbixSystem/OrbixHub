import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Inject,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import type { AuthUser } from '../../common/auth/auth.types';
import { ENV } from '../../common/config/config.module';
import type { Env } from '../../common/config/env.schema';
import { TenantContext } from '../../common/database/tenant-context';
import { REQUIRES_MODULE } from './requires-module.decorator';
import { subscriptionAllows } from './subscription-access';

const READ_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);

@Injectable()
export class ModuleAccessGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly tenant: TenantContext,
    @Inject(ENV) private readonly env: Env,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const moduleKey = this.reflector.getAllAndOverride<string | undefined>(REQUIRES_MODULE, [
      ctx.getHandler(),
      ctx.getClass(),
    ]);
    if (!moduleKey) return true;

    const req = ctx.switchToHttp().getRequest<{ method: string; user?: AuthUser }>();
    const user = req.user;
    if (!user) throw new ForbiddenException();
    const isWrite = !READ_METHODS.has(req.method.toUpperCase());

    // Guards run BEFORE the TenantInterceptor, so open context explicitly from
    // the JWT-verified tenant id (never client-supplied).
    const { status, enabled, isCore } = await this.tenant.runWithTenant(user.tenantId, async () => {
      const db = this.tenant.getClient();
      const sub = await db.subscription.findFirst();
      const tm = await db.tenant_module.findFirst({
        where: { module: { key: moduleKey } },
        include: { module: true },
      });
      return {
        status: sub?.status ?? 'canceled',
        enabled: tm?.enabled ?? false,
        isCore: tm?.module?.is_core ?? false,
      };
    });

    if (!isCore && !enabled) throw new ForbiddenException(`Module ${moduleKey} is not enabled`);

    if (subscriptionAllows(status, isWrite, this.env.BILLING_ENFORCE_SUBSCRIPTION)) return true;
    throw new ForbiddenException(`Subscription status "${status}" forbids this operation`);
  }
}
