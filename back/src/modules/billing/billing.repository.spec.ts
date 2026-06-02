import { BillingRepository } from './billing.repository';

/** Minimal fake of the tenant_module table behaviour for reconcile(). */
function makeFakes(opts: {
  planModuleIds: string[];
  coreModuleIds: string[];
  existing: Array<{ module_id: string; enabled: boolean; source: string }>;
}) {
  const rows = opts.existing.map((r) => ({ ...r }));
  const client = {
    plan_module: {
      findMany: jest.fn(async () => opts.planModuleIds.map((id) => ({ module_id: id }))),
    },
    module: {
      findMany: jest.fn(async () => opts.coreModuleIds.map((id) => ({ id }))),
    },
    tenant_module: {
      findMany: jest.fn(async () => rows.map((r) => ({ ...r }))),
      upsert: jest.fn(async ({ create, update, where }: any) => {
        const id = where.tenant_id_module_id.module_id;
        const found = rows.find((r) => r.module_id === id);
        if (found) Object.assign(found, update);
        else rows.push({ module_id: id, enabled: create.enabled, source: create.source });
      }),
      updateMany: jest.fn(async ({ where, data }: any) => {
        for (const r of rows) {
          if (where.module_id.in.includes(r.module_id)) Object.assign(r, data);
        }
      }),
    },
  };
  const prisma = client; // global reads via same fake for the test
  const tenant = { getClient: () => client, withTenantTx: (fn: any) => fn() } as never;
  const repo = new BillingRepository(prisma as never, tenant);
  return { repo, rows, client };
}

describe('BillingRepository.reconcile', () => {
  it('enables plan modules (source=plan) and keeps is_core always enabled', async () => {
    const { repo, rows } = makeFakes({
      planModuleIds: ['os', 'customers'],
      coreModuleIds: ['dash'],
      existing: [],
    });
    await repo.reconcile('t1', 'plan-trial');
    const byId = Object.fromEntries(rows.map((r) => [r.module_id, r]));
    expect(byId['os']).toMatchObject({ enabled: true, source: 'plan' });
    expect(byId['customers']).toMatchObject({ enabled: true, source: 'plan' });
    expect(byId['dash']).toMatchObject({ enabled: true });
  });

  it('disables plan-sourced modules dropped from the new plan, preserves addons', async () => {
    const { repo, rows } = makeFakes({
      planModuleIds: ['os'],
      coreModuleIds: [],
      existing: [
        { module_id: 'os', enabled: true, source: 'plan' },
        { module_id: 'customers', enabled: true, source: 'plan' }, // dropped
        { module_id: 'inventory', enabled: true, source: 'addon' }, // untouched
      ],
    });
    await repo.reconcile('t1', 'plan-x');
    const byId = Object.fromEntries(rows.map((r) => [r.module_id, r]));
    expect(byId['os'].enabled).toBe(true);
    expect(byId['customers'].enabled).toBe(false); // plan-sourced, dropped
    expect(byId['inventory']).toMatchObject({ enabled: true, source: 'addon' }); // untouched
  });

  it('is idempotent', async () => {
    const { repo, rows } = makeFakes({
      planModuleIds: ['os'],
      coreModuleIds: [],
      existing: [{ module_id: 'os', enabled: true, source: 'plan' }],
    });
    await repo.reconcile('t1', 'p');
    const first = JSON.stringify(rows);
    await repo.reconcile('t1', 'p');
    expect(JSON.stringify(rows)).toBe(first);
  });
});
