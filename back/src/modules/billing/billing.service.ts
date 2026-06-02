import { Injectable } from '@nestjs/common';
import { TenantContext } from '../../common/database/tenant-context';

@Injectable()
export class BillingService {
  constructor(private readonly tenant: TenantContext) {}

  /**
   * Minimal trial bootstrap used by register. Runs on the CURRENT tx/context
   * (caller wraps it via tenant.bindTx/runWithTenant). Creates
   * subscription(trialing) + tenant_module from the trial plan's plan_module.
   */
  async createTrial(tenantId: string): Promise<void> {
    const db = this.tenant.getClient();
    const trial = await db.plan.findFirstOrThrow({ where: { key: 'trial' } });
    const modules = await db.plan_module.findMany({
      where: { plan_id: trial.id },
    });
    await db.subscription.create({
      data: {
        tenant_id: tenantId,
        plan_id: trial.id,
        status: 'trialing',
        trial_ends_at: new Date(Date.now() + 14 * 86_400_000),
      },
    });
    if (modules.length > 0) {
      await db.tenant_module.createMany({
        data: modules.map((m: { module_id: string }) => ({
          tenant_id: tenantId,
          module_id: m.module_id,
          enabled: true,
        })),
      });
    }
  }
}
