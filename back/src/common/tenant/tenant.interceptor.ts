import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { TenantContext } from '../database/tenant-context';
import type { Request } from 'express';

// NOTE: AuthUser type lands in Phase 4 (../auth/auth.types). Until then we use a
// minimal inline shape so this file compiles. The JwtAuthGuard will populate the
// full AuthUser on req.user in Phase 4; we only need the tenantId here.
type RequestUser = { tenantId?: string } | undefined;

@Injectable()
export class TenantInterceptor implements NestInterceptor {
  constructor(private readonly tenant: TenantContext) {}

  intercept(ctx: ExecutionContext, next: CallHandler): Observable<unknown> {
    const req = ctx
      .switchToHttp()
      .getRequest<Request & { user?: RequestUser }>();
    // tid comes ONLY from the verified token (set by JwtAuthGuard on req.user).
    if (req.user?.tenantId) {
      this.tenant.setTenantId(req.user.tenantId);
    }
    return next.handle();
  }
}
