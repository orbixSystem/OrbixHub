import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { TenantContext } from '../../common/database/tenant-context';

export type SubscriptionStatus = 'trialing' | 'active' | 'past_due' | 'canceled';

@Injectable()
export class BillingRepository {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tenant: TenantContext,
  ) {}

  // ---- global catalog reads (no RLS) ----
  listActivePlansWithModules() {
    return this.prisma.plan.findMany({
      include: { plan_module: { include: { module: true } } },
      orderBy: { price_cents: 'asc' },
    });
  }
  findPlanByKey(key: string) {
    return this.prisma.plan.findUnique({ where: { key } });
  }

  // ---- tenant-scoped (RLS) — caller MUST be inside a tenant tx ----
  getSubscription() {
    const db = this.tenant.getClient();
    return db.subscription.findFirst({ include: { plan: true } });
  }

  async upsertSubscription(
    tenantId: string,
    planId: string,
    data: {
      status: SubscriptionStatus;
      trial_ends_at?: Date | null;
      current_period_start?: Date | null;
      current_period_end?: Date | null;
      canceled_at?: Date | null;
      external_subscription_id?: string | null;
    },
  ) {
    const db = this.tenant.getClient();
    return db.subscription.upsert({
      where: { tenant_id: tenantId },
      create: { tenant_id: tenantId, plan_id: planId, ...data },
      update: { plan_id: planId, updated_at: new Date(), ...data },
    });
  }

  async updateSubscriptionStatus(
    data: {
      status: SubscriptionStatus;
      current_period_start?: Date | null;
      current_period_end?: Date | null;
      canceled_at?: Date | null;
    },
  ) {
    const db = this.tenant.getClient();
    const sub = await db.subscription.findFirst();
    if (!sub) return null;
    return db.subscription.update({
      where: { id: sub.id },
      data: { ...data, updated_at: new Date() },
    });
  }

  /**
   * Derive tenant_module from a plan. Idempotent. Assumes an active tenant tx.
   * - plan modules + is_core modules -> enabled=true (source 'plan' on create)
   * - existing source='addon'|'manual' rows are NEVER touched
   * - plan-sourced rows no longer in the plan (and not core) -> enabled=false
   *   (settings preserved — only the `enabled` flag changes)
   */
  async reconcile(tenantId: string, planId: string): Promise<void> {
    const db = this.tenant.getClient();

    const [planMods, coreMods, existing] = await Promise.all([
      db.plan_module.findMany({ where: { plan_id: planId } }),
      db.module.findMany({ where: { is_core: true } }),
      db.tenant_module.findMany(),
    ]);

    const target = new Set<string>([
      ...planMods.map((m: { module_id: string }) => m.module_id),
      ...coreMods.map((m: { id: string }) => m.id),
    ]);
    const bySource = new Map(
      existing.map((r: { module_id: string; source: string }) => [r.module_id, r.source]),
    );

    // Enable every target module (skip addon/manual rows — leave them as-is).
    for (const moduleId of target) {
      if (bySource.get(moduleId) && bySource.get(moduleId) !== 'plan') continue;
      await db.tenant_module.upsert({
        where: { tenant_id_module_id: { tenant_id: tenantId, module_id: moduleId } },
        create: { tenant_id: tenantId, module_id: moduleId, enabled: true, source: 'plan' },
        update: { enabled: true },
      });
    }

    // Disable plan-sourced modules that left the plan and aren't core.
    const toDisable = existing
      .filter(
        (r: { module_id: string; source: string }) =>
          r.source === 'plan' && !target.has(r.module_id),
      )
      .map((r: { module_id: string }) => r.module_id);
    if (toDisable.length > 0) {
      await db.tenant_module.updateMany({
        where: { tenant_id: tenantId, module_id: { in: toDisable } },
        data: { enabled: false },
      });
    }
  }

  // ---- platform table (no RLS) — webhook idempotency ----
  insertWebhookEvent(externalEventId: string, type: string, payload: Prisma.InputJsonValue) {
    return this.prisma.billing_webhook_event.create({
      data: { external_event_id: externalEventId, type, payload },
    });
  }
  markWebhookProcessed(id: string) {
    return this.prisma.billing_webhook_event.update({
      where: { id },
      data: { processed_at: new Date() },
    });
  }

  // ---- controlled SECURITY DEFINER resolvers (no JWT context) ----
  async resolveTenantBySubscription(externalSubscriptionId: string): Promise<string | null> {
    const rows = await this.prisma.$queryRaw<Array<{ tenant_id: string }>>`
      SELECT billing_resolve_tenant_by_subscription(${externalSubscriptionId}) AS tenant_id
    `;
    return rows[0]?.tenant_id ?? null;
  }
  findExpiredTrials() {
    return this.prisma.$queryRaw<Array<{ tenant_id: string; subscription_id: string }>>`
      SELECT tenant_id, subscription_id FROM billing_find_expired_trials()
    `;
  }
}
