import { Inject, Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { ENV } from '../../common/config/config.module';
import type { Env } from '../../common/config/env.schema';
import { TenantContext } from '../../common/database/tenant-context';
import { AuditService } from '../../common/audit/audit.service';
import { BillingRepository } from './billing.repository';

@Injectable()
export class TrialExpiryJob {
  private readonly logger = new Logger(TrialExpiryJob.name);

  constructor(
    private readonly repo: BillingRepository,
    private readonly tenant: TenantContext,
    private readonly audit: AuditService,
    @Inject(ENV) private readonly env: Env,
  ) {}

  @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT)
  async run(): Promise<void> {
    // Sem cobrança de verdade, marcar past_due só produz tenant travado e uma
    // entrada de auditoria por dia. O status volta a mudar quando o módulo de
    // assinatura existir e `BILLING_ENFORCE_SUBSCRIPTION` for ligado.
    if (!this.env.BILLING_ENFORCE_SUBSCRIPTION) return;

    const expired = await this.repo.findExpiredTrials();
    if (expired.length === 0) return;
    this.logger.log(`Expiring ${expired.length} trial(s)`);
    for (const { tenant_id, subscription_id } of expired) {
      await this.tenant.runWithTenant(tenant_id, () =>
        this.repo.updateSubscriptionStatus({ status: 'past_due' }),
      );
      await this.audit.log(tenant_id, null, 'subscription_change', 'trial_expired', {
        subscriptionId: subscription_id,
      });
    }
  }
}
