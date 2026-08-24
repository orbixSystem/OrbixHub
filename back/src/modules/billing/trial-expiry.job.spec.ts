import { TrialExpiryJob } from './trial-expiry.job';

const envWith = (enforce: boolean) =>
  ({ BILLING_ENFORCE_SUBSCRIPTION: enforce }) as never;

describe('TrialExpiryJob', () => {
  it('transitions each expired trial to past_due and audits', async () => {
    const repo = {
      findExpiredTrials: jest.fn(async () => [
        { tenant_id: 't1', subscription_id: 's1' },
        { tenant_id: 't2', subscription_id: 's2' },
      ]),
      findExpiredAccess: jest.fn(async () => []),
      updateSubscriptionStatus: jest.fn(async () => ({ id: 's' })),
    } as never;
    const tenant = { runWithTenant: (_t: string, fn: () => unknown) => fn() } as never;
    const audit = { log: jest.fn() } as never;
    const job = new TrialExpiryJob(repo, tenant, audit, envWith(true));

    await job.run();

    const repoMock = repo as unknown as { updateSubscriptionStatus: jest.Mock };
    const auditMock = audit as unknown as { log: jest.Mock };
    expect(repoMock.updateSubscriptionStatus).toHaveBeenCalledTimes(2);
    expect(repoMock.updateSubscriptionStatus).toHaveBeenCalledWith({ status: 'past_due' });
    expect(auditMock.log).toHaveBeenCalledWith(
      't1', null, 'subscription_change', 'trial_expired', expect.any(Object),
    );
  });

  it('no expired trials -> no writes', async () => {
    const repo = {
      findExpiredTrials: jest.fn(async () => []),
      findExpiredAccess: jest.fn(async () => []),
      updateSubscriptionStatus: jest.fn(),
    } as never;
    const tenant = { runWithTenant: (_t: string, fn: () => unknown) => fn() } as never;
    const audit = { log: jest.fn() } as never;
    await new TrialExpiryJob(repo, tenant, audit, envWith(true)).run();
    const repoMock = repo as unknown as { updateSubscriptionStatus: jest.Mock };
    expect(repoMock.updateSubscriptionStatus).not.toHaveBeenCalled();
  });

  it('BILLING_ENFORCE_SUBSCRIPTION=false -> nem consulta os trials vencidos', async () => {
    const repo = {
      findExpiredTrials: jest.fn(async () => [{ tenant_id: 't1', subscription_id: 's1' }]),
      findExpiredAccess: jest.fn(async () => [{ tenant_id: 't2', subscription_id: 's2' }]),
      updateSubscriptionStatus: jest.fn(),
    } as never;
    const tenant = { runWithTenant: (_t: string, fn: () => unknown) => fn() } as never;
    const audit = { log: jest.fn() } as never;
    await new TrialExpiryJob(repo, tenant, audit, envWith(false)).run();
    const repoMock = repo as unknown as {
      findExpiredTrials: jest.Mock;
      updateSubscriptionStatus: jest.Mock;
    };
    const auditMock = audit as unknown as { log: jest.Mock };
    expect(repoMock.findExpiredTrials).not.toHaveBeenCalled();
    expect(repoMock.updateSubscriptionStatus).not.toHaveBeenCalled();
    expect(auditMock.log).not.toHaveBeenCalled();
  });

  it('acesso fora do prazo também vira past_due, com motivo próprio', async () => {
    const repo = {
      findExpiredTrials: jest.fn(async () => []),
      findExpiredAccess: jest.fn(async () => [
        { tenant_id: 't9', subscription_id: 's9' },
      ]),
      updateSubscriptionStatus: jest.fn(async () => ({ id: 's9' })),
    } as never;
    const tenant = { runWithTenant: (_t: string, fn: () => unknown) => fn() } as never;
    const audit = { log: jest.fn() } as never;

    await new TrialExpiryJob(repo, tenant, audit, envWith(true)).run();

    const repoMock = repo as unknown as { updateSubscriptionStatus: jest.Mock };
    const auditMock = audit as unknown as { log: jest.Mock };
    expect(repoMock.updateSubscriptionStatus).toHaveBeenCalledWith({ status: 'past_due' });
    // Motivo separado do trial: quem lê a auditoria precisa saber se caiu por
    // fim de teste ou por contrato vencido — a conversa com o cliente é outra.
    expect(auditMock.log).toHaveBeenCalledWith(
      't9', null, 'subscription_change', 'access_expired', expect.any(Object),
    );
  });
});
