import { Inject, Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { ENV } from '../../common/config/config.module';
import type { Env } from '../../common/config/env.schema';
import { TenantContext } from '../../common/database/tenant-context';
import { AuditService } from '../../common/audit/audit.service';
import { BillingRepository } from './billing.repository';

/**
 * O que vence, todo dia à meia-noite: teste acabado e acesso fora do prazo.
 *
 * Os dois viram `past_due`, que é "continua vendo o que é dele, não escreve
 * mais" — e não `canceled`. Cancelar por vencimento tiraria do cliente até a
 * consulta ao próprio histórico por causa de um boleto atrasado.
 */
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

    await this.vencer(await this.repo.findExpiredTrials(), 'trial_expired', 'trial(s)');
    await this.vencer(
      await this.repo.findExpiredAccess(),
      'access_expired',
      'acesso(s) fora do prazo',
    );
  }

  private async vencer(
    vencidos: Array<{ tenant_id: string; subscription_id: string }>,
    motivo: 'trial_expired' | 'access_expired',
    rotulo: string,
  ): Promise<void> {
    if (vencidos.length === 0) return;
    this.logger.log(`Expiring ${vencidos.length} ${rotulo}`);

    for (const { tenant_id, subscription_id } of vencidos) {
      await this.tenant.runWithTenant(tenant_id, () =>
        this.repo.updateSubscriptionStatus({ status: 'past_due' }),
      );
      await this.audit.log(tenant_id, null, 'subscription_change', motivo, {
        subscriptionId: subscription_id,
      });
    }
  }
}
