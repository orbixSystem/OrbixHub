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
  | 'settings_change'
  | 'customer_delete'
  | 'subject_delete'
  | 'inventory_item_create'
  | 'inventory_item_update'
  | 'inventory_item_archive'
  | 'inventory_item_unarchive'
  | 'inventory_item_delete'
  | 'os_create'
  | 'os_update'
  | 'os_status_change'
  | 'os_delete'
  | 'os_photo_add'
  | 'os_photo_delete'
  | 'os_template_create'
  | 'os_template_update'
  | 'os_template_delete'
  | 'os_template_apply'
  | 'os_stock_reconcile'
  | 'invoice_issue'
  | 'invoice_authorized'
  | 'invoice_rejected'
  | 'invoice_cancel'
  | 'invoice_webhook';

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
