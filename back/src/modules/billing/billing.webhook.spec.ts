import { BadRequestException } from '@nestjs/common';
import { BillingService } from './billing.service';

function build(overrides: { repo?: object; gateway?: object } = {}) {
  const repo = {
    insertWebhookEvent: jest.fn(async () => ({ id: 'evt-row' })),
    markWebhookProcessed: jest.fn(async () => undefined),
    resolveTenantBySubscription: jest.fn(async () => 't1'),
    updateSubscriptionStatus: jest.fn(async () => ({ id: 'sub' })),
    findWebhookEventByExternalId: jest.fn(async () => ({ id: 'evt-row', processed_at: new Date() })),
    ...(overrides.repo ?? {}),
  };
  const tenant = { runWithTenant: (_t: string, fn: () => unknown) => fn() } as never;
  const audit = { log: jest.fn() } as never;
  const gateway = { verifySignature: jest.fn(() => true), ...(overrides.gateway ?? {}) } as never;
  const env = {} as never;
  const svc = new BillingService(tenant, repo as never, env, audit, gateway);
  return { svc, repo, gateway, audit };
}

const body = JSON.stringify({
  id: 'evt_1',
  type: 'subscription.active',
  data: { subscriptionId: 'noop_sub_t1_pro' },
});

describe('BillingService.processWebhook', () => {
  it('rejects an invalid signature with 400 and zero DB work', async () => {
    const { svc, repo } = build({ gateway: { verifySignature: () => false } });
    await expect(svc.processWebhook(body, 'bad')).rejects.toBeInstanceOf(BadRequestException);
    expect(repo.insertWebhookEvent).not.toHaveBeenCalled();
  });

  it('no-ops on a duplicate external_event_id (P2002)', async () => {
    const dup = Object.assign(new Error('dup'), { code: 'P2002' });
    const { svc, repo } = build({ repo: { insertWebhookEvent: jest.fn(async () => { throw dup; }) } });
    await expect(svc.processWebhook(body, 'sig')).resolves.toBeUndefined();
    expect(repo.updateSubscriptionStatus).not.toHaveBeenCalled();
  });

  it('resolves tenant via external id and updates status', async () => {
    const { svc, repo } = build();
    await svc.processWebhook(body, 'sig');
    expect(repo.resolveTenantBySubscription).toHaveBeenCalledWith('noop_sub_t1_pro');
    expect(repo.updateSubscriptionStatus).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'active' }),
    );
    expect(repo.markWebhookProcessed).toHaveBeenCalled();
  });

  it('audits the change on a known event', async () => {
    const { svc, audit } = build();
    await svc.processWebhook(body, 'sig');
    expect((audit as { log: jest.Mock }).log).toHaveBeenCalledWith(
      't1', null, 'subscription_change', 'webhook', expect.objectContaining({ type: 'subscription.active' }),
    );
  });

  it('records but does not update status for an unknown event type', async () => {
    const unknown = JSON.stringify({ id: 'evt_2', type: 'invoice.paid', data: { subscriptionId: 'noop_sub_t1_pro' } });
    const { svc, repo } = build();
    await svc.processWebhook(unknown, 'sig');
    expect(repo.insertWebhookEvent).toHaveBeenCalled();
    expect(repo.updateSubscriptionStatus).not.toHaveBeenCalled();
    expect(repo.markWebhookProcessed).toHaveBeenCalled();
  });

  it('re-drives processing when a duplicate row was never processed (processed_at null)', async () => {
    const dup = Object.assign(new Error('dup'), { code: 'P2002' });
    const { svc, repo } = build({
      repo: {
        insertWebhookEvent: jest.fn(async () => { throw dup; }),
        findWebhookEventByExternalId: jest.fn(async () => ({ id: 'evt-row', processed_at: null })),
      },
    });
    await svc.processWebhook(body, 'sig');
    const m = repo as unknown as { updateSubscriptionStatus: jest.Mock; markWebhookProcessed: jest.Mock };
    expect(m.updateSubscriptionStatus).toHaveBeenCalled();
    expect(m.markWebhookProcessed).toHaveBeenCalledWith('evt-row');
  });

  it('no-ops on a duplicate that was already processed', async () => {
    const dup = Object.assign(new Error('dup'), { code: 'P2002' });
    const { svc, repo } = build({
      repo: {
        insertWebhookEvent: jest.fn(async () => { throw dup; }),
        findWebhookEventByExternalId: jest.fn(async () => ({ id: 'evt-row', processed_at: new Date() })),
      },
    });
    await svc.processWebhook(body, 'sig');
    const m = repo as unknown as { updateSubscriptionStatus: jest.Mock };
    expect(m.updateSubscriptionStatus).not.toHaveBeenCalled();
  });
});
