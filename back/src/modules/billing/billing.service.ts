import {
  BadRequestException,
  Inject,
  Injectable,
} from '@nestjs/common';
import { ENV } from '../../common/config/config.module';
import type { Env } from '../../common/config/env.schema';
import { TenantContext } from '../../common/database/tenant-context';
import { AuditService } from '../../common/audit/audit.service';
import { BillingRepository } from './billing.repository';
import { PAYMENT_GATEWAY, PaymentGateway } from './payment/payment-gateway';

export interface PlanView {
  key: string;
  name: string;
  priceCents: number;
  billingPeriod: string;
  modules: string[];
}
export interface SubscriptionView {
  planKey: string;
  status: string;
  trialEndsAt: Date | null;
  currentPeriodStart: Date | null;
  currentPeriodEnd: Date | null;
  canceledAt: Date | null;
}

@Injectable()
export class BillingService {
  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: BillingRepository,
    @Inject(ENV) private readonly env: Env,
    private readonly audit: AuditService,
    @Inject(PAYMENT_GATEWAY) private readonly gateway: PaymentGateway,
  ) {}

  /**
   * Trial bootstrap called by register INSIDE its tx (caller wraps via
   * tenant.bindTx). Uses getClient() so the insert + reconcile are atomic with
   * tenant/user/membership creation.
   */
  async createTrial(tenantId: string): Promise<void> {
    const plan = await this.repo.findPlanByKey(this.env.TRIAL_PLAN_KEY);
    if (!plan) throw new Error(`TRIAL_PLAN_KEY "${this.env.TRIAL_PLAN_KEY}" not found`);
    const db = this.tenant.getClient();
    await db.subscription.create({
      data: {
        tenant_id: tenantId,
        plan_id: plan.id,
        status: 'trialing',
        trial_ends_at: new Date(Date.now() + this.env.TRIAL_DAYS * 86_400_000),
      },
    });
    await this.repo.reconcile(tenantId, plan.id);
  }

  /** Plans for the catalog endpoint (excludes the internal trial plan). */
  async getPlans(): Promise<PlanView[]> {
    const plans = await this.repo.listActivePlansWithModules();
    return plans
      .filter((p) => p.key !== this.env.TRIAL_PLAN_KEY)
      .map((p) => ({
        key: p.key,
        name: p.name,
        priceCents: p.price_cents,
        billingPeriod: p.billing_period,
        modules: p.plan_module.map((pm) => pm.module.key),
      }));
  }

  async getSubscription(): Promise<SubscriptionView | null> {
    return this.tenant.withTenantTx(async () => {
      const sub = await this.repo.getSubscription();
      if (!sub) return null;
      return {
        planKey: sub.plan.key,
        status: sub.status,
        trialEndsAt: sub.trial_ends_at,
        currentPeriodStart: sub.current_period_start,
        currentPeriodEnd: sub.current_period_end,
        canceledAt: sub.canceled_at,
      };
    });
  }

  /** Enabled module keys for a server-resolved tenant. Used by /me and the guard path. */
  async getEnabledModules(tenantId: string): Promise<string[]> {
    return this.tenant.runWithTenant(tenantId, async () => {
      const db = this.tenant.getClient();
      const tms = await db.tenant_module.findMany({
        where: { enabled: true },
        include: { module: true },
      });
      return tms.map((tm) => tm.module.key);
    });
  }

  async subscribe(tenantId: string, actorUserId: string, planKey: string): Promise<SubscriptionView> {
    const plan = await this.assertSubscribablePlan(planKey);

    if (this.env.BILLING_REQUIRE_PAYMENT) {
      // Gateway call FIRST, OUTSIDE any DB tx. Status stays authoritative via webhook.
      const checkout = await this.gateway.createCheckout({
        tenantId,
        planKey: plan.key,
        priceCents: plan.price_cents,
      });
      await this.tenant.runWithTenant(tenantId, () =>
        this.repo.upsertSubscription(tenantId, plan.id, {
          status: 'trialing', // pending until webhook confirms 'active'
          external_subscription_id: checkout.externalSubscriptionId,
        }),
      );
      // Module enablement (reconcile) is deferred to the webhook that confirms 'active'.
    } else {
      const now = new Date();
      await this.tenant.runWithTenant(tenantId, async () => {
        await this.repo.upsertSubscription(tenantId, plan.id, {
          status: 'active',
          current_period_start: now,
          current_period_end: new Date(now.getTime() + 30 * 86_400_000),
          canceled_at: null,
        });
        await this.repo.reconcile(tenantId, plan.id);
      });
    }
    await this.audit.log(tenantId, actorUserId, 'subscription_change', 'subscribe', {
      planKey: plan.key,
    });
    return this.subscriptionView(tenantId);
  }

  async changePlan(tenantId: string, actorUserId: string, planKey: string): Promise<SubscriptionView> {
    const plan = await this.assertSubscribablePlan(planKey);
    await this.tenant.runWithTenant(tenantId, async () => {
      await this.repo.upsertSubscription(tenantId, plan.id, { status: 'active' });
      await this.repo.reconcile(tenantId, plan.id);
    });
    await this.audit.log(tenantId, actorUserId, 'subscription_change', 'change-plan', {
      planKey: plan.key,
    });
    return this.subscriptionView(tenantId);
  }

  private async assertSubscribablePlan(planKey: string) {
    const plan = await this.repo.findPlanByKey(planKey);
    if (!plan || plan.key === this.env.TRIAL_PLAN_KEY) {
      throw new BadRequestException(`Invalid plan: ${planKey}`);
    }
    return plan;
  }

  private async subscriptionView(tenantId: string): Promise<SubscriptionView> {
    const sub = await this.tenant.runWithTenant(tenantId, () => this.repo.getSubscription());
    if (!sub) throw new Error('subscription not found immediately after write');
    return {
      planKey: sub.plan.key,
      status: sub.status,
      trialEndsAt: sub.trial_ends_at,
      currentPeriodStart: sub.current_period_start,
      currentPeriodEnd: sub.current_period_end,
      canceledAt: sub.canceled_at,
    };
  }
}
