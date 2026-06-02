import { INestApplication } from '@nestjs/common';
import { makeDbApp, seedTwoTenants } from './helpers/db';
import { PrismaService } from '../src/common/database/prisma.service';
import { TenantContext } from '../src/common/database/tenant-context';

describe('Multi-tenant isolation (RLS)', () => {
  let app: INestApplication;
  let prisma: PrismaService;
  let tenant: TenantContext;

  beforeAll(async () => {
    ({ app, prisma, tenant } = await makeDbApp());
  });
  afterAll(async () => app?.close());

  it('criterion 2: without tenant context, RLS tables return zero rows', async () => {
    // No runWithTenant => no app.current_tenant_id => policy matches nothing.
    const rows = await prisma.subscription.findMany();
    expect(rows).toHaveLength(0);
  });

  it('criterion 1: data written under tenant A is invisible under tenant B', async () => {
    const { a, b, plan } = await seedTwoTenants(prisma);

    // Write a subscription under A's context
    await tenant.runWithTenant(a.id, async () => {
      const db = tenant.getClient();
      await db.subscription.create({
        data: { tenant_id: a.id, plan_id: plan.id, status: 'trialing' },
      });
    });

    // Read under A => sees it
    const seenByA = await tenant.runWithTenant(a.id, async () =>
      tenant.getClient().subscription.findMany(),
    );
    expect(seenByA).toHaveLength(1);

    // Read under B => sees nothing
    const seenByB = await tenant.runWithTenant(b.id, async () =>
      tenant.getClient().subscription.findMany(),
    );
    expect(seenByB).toHaveLength(0);
  });

  it('criterion 1 (write): inserting B-owned row while in A context is blocked by WITH CHECK', async () => {
    const { a, b, plan } = await seedTwoTenants(prisma);
    await expect(
      tenant.runWithTenant(a.id, async () =>
        tenant.getClient().subscription.create({
          data: { tenant_id: b.id, plan_id: plan.id, status: 'trialing' },
        }),
      ),
    ).rejects.toThrow(); // RLS WITH CHECK violation
  });
});
