import { BillingService } from './billing.service';

describe('BillingService.createTrial', () => {
  it('creates a trialing subscription and copies plan_module into tenant_module', async () => {
    const db = {
      plan: { findFirstOrThrow: jest.fn(async () => ({ id: 'plan-trial' })) },
      plan_module: {
        findMany: jest.fn(async () => [{ module_id: 'm1' }, { module_id: 'm2' }]),
      },
      subscription: { create: jest.fn(async () => ({ id: 'sub1' })) },
      tenant_module: { createMany: jest.fn(async () => ({ count: 2 })) },
    };
    const tenant = { getClient: () => db } as never;
    const svc = new BillingService(tenant);
    await svc.createTrial('t1');
    expect(db.subscription.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ tenant_id: 't1', status: 'trialing' }),
      }),
    );
    expect(db.tenant_module.createMany).toHaveBeenCalledWith(
      expect.objectContaining({
        data: [
          { tenant_id: 't1', module_id: 'm1', enabled: true },
          { tenant_id: 't1', module_id: 'm2', enabled: true },
        ],
      }),
    );
  });
});
