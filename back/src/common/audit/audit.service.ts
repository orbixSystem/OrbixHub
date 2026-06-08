import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { TenantContext } from '../database/tenant-context';

export type AuditAction =
  | 'login'
  | 'password_change'
  | 'invite'
  | 'subscription_change'
  | 'role_change'
  | 'member_activate'
  | 'member_deactivate'
  | 'settings_change';

@Injectable()
export class AuditService {
  constructor(private readonly tenant: TenantContext) {}

  /** audit_log has RLS — write under the given tenant's context (short tx). */
  async log(
    tenantId: string,
    actorUserId: string | null,
    action: AuditAction,
    target?: string,
    metadata?: Record<string, unknown>,
  ): Promise<void> {
    await this.tenant.runWithTenant(tenantId, async () => {
      const db = this.tenant.getClient();
      await db.audit_log.create({
        data: {
          tenant_id: tenantId,
          actor_user_id: actorUserId,
          action,
          target: target ?? null,
          metadata: metadata
            ? (metadata as Prisma.InputJsonValue)
            : undefined,
        },
      });
    });
  }
}
