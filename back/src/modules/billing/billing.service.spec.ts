import { BillingService } from './billing.service';

describe('BillingService.createTrial', () => {
  it('creates a trialing subscription for TRIAL_PLAN_KEY and reconciles modules on the caller tx', async () => {
    const reconcile = jest.fn(async () => undefined);
    const db = {
      subscription: { create: jest.fn(async () => ({ id: 'sub1' })) },
    };
    const tenant = { getClient: () => db } as never;
    const repo = {
      findPlanByKey: jest.fn(async (k: string) => ({ id: 'plan-trial', key: k })),
      reconcile,
    };
    const env = { TRIAL_PLAN_KEY: 'trial', TRIAL_DAYS: 14, BILLING_REQUIRE_PAYMENT: false } as never;
    const audit = { log: jest.fn() } as never;
    const gateway = {} as never;

    const svc = new BillingService(tenant, repo as never, env, audit, gateway);
    await svc.createTrial('t1');

    expect(repo.findPlanByKey).toHaveBeenCalledWith('trial');
    expect(db.subscription.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ tenant_id: 't1', plan_id: 'plan-trial', status: 'trialing' }),
      }),
    );
    expect(reconcile).toHaveBeenCalledWith('t1', 'plan-trial');
  });
});
