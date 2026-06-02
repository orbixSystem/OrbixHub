import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { TenantContext } from '../database/tenant-context';
import type { Request } from 'express';
import type { AuthUser } from '../auth/auth.types';

@Injectable()
export class TenantInterceptor implements NestInterceptor {
  constructor(private readonly tenant: TenantContext) {}

  intercept(ctx: ExecutionContext, next: CallHandler): Observable<unknown> {
    const req = ctx
      .switchToHttp()
      .getRequest<Request & { user?: AuthUser }>();
    // tid comes ONLY from the verified token (set by JwtAuthGuard on req.user).
    if (req.user?.tenantId) {
      this.tenant.setTenantId(req.user.tenantId);
    }
    return next.handle();
  }
}
