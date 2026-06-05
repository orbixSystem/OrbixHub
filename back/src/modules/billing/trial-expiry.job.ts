import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
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
  ) {}

  @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT)
  async run(): Promise<void> {
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
