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
      upsert: jest.fn(
        async (args: {
          where: { tenant_id_module_id: { tenant_id: string; module_id: string } };
          create: { tenant_id: string; module_id: string; enabled: boolean; source: string };
          update: { enabled: boolean };
        }) => {
          const id = args.where.tenant_id_module_id.module_id;
          const found = rows.find((r) => r.module_id === id);
          if (found) Object.assign(found, args.update);
          else rows.push({ module_id: id, enabled: args.create.enabled, source: args.create.source });
        },
      ),
      updateMany: jest.fn(
        async (args: { where: { tenant_id: string; module_id: { in: string[] } }; data: { enabled: boolean } }) => {
          for (const r of rows) {
            if (args.where.module_id.in.includes(r.module_id)) Object.assign(r, args.data);
          }
        },
      ),
    },
  };
  const prisma = client; // global reads via same fake for the test
  const tenant = { getClient: () => client, withTenantTx: (fn: () => unknown) => fn() } as never;
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

  /**
   * O BUG: um módulo desligado pelo dono ficava com `source='plan'`, e a
   * próxima troca de plano o religava (`update: { enabled: true }`). Ele
   * reaparecia em /me e na sidebar do cliente sem ninguém ter mexido.
   *
   * A correção não está aqui — está em `setModuleEnabled`, que grava
   * `source='manual'`. Este teste trava o outro lado: o reconcile tem de
   * RESPEITAR essa marca, inclusive quando o módulo está no plano novo.
   */
  it('não religa módulo desligado à mão, mesmo estando no plano', async () => {
    const { repo, rows } = makeFakes({
      planModuleIds: ['os', 'inventory'],
      coreModuleIds: [],
      existing: [
        { module_id: 'os', enabled: true, source: 'plan' },
        { module_id: 'inventory', enabled: false, source: 'manual' },
      ],
    });
    await repo.reconcile('t1', 'plan-pro');
    const byId = Object.fromEntries(rows.map((r) => [r.module_id, r]));
    expect(byId['os'].enabled).toBe(true);
    expect(byId['inventory']).toMatchObject({ enabled: false, source: 'manual' });
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
