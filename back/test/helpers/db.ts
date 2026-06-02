import { Test } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import { DatabaseModule } from '../../src/common/database/database.module';
import { ConfigModule } from '../../src/common/config/config.module';
import { PrismaService } from '../../src/common/database/prisma.service';
import { TenantContext } from '../../src/common/database/tenant-context';

export async function makeDbApp(): Promise<{
  app: INestApplication;
  prisma: PrismaService;
  tenant: TenantContext;
}> {
  const mod = await Test.createTestingModule({
    imports: [ConfigModule, DatabaseModule],
  }).compile();
  const app = mod.createNestApplication();
  await app.init();
  return {
    app,
    prisma: app.get(PrismaService),
    tenant: app.get(TenantContext),
  };
}

/** Seed two tenants directly (auth tables have no RLS). Returns their ids. */
export async function seedTwoTenants(prisma: PrismaService) {
  const a = await prisma.tenant.create({
    data: { name: 'A', slug: `a-${Date.now()}-${Math.random().toString(36).slice(2)}` },
  });
  const b = await prisma.tenant.create({
    data: { name: 'B', slug: `b-${Date.now()}-${Math.random().toString(36).slice(2)}` },
  });
  const plan = await prisma.plan.findFirstOrThrow({ where: { key: 'trial' } });
  // subscriptions are RLS tables — insert under each tenant's context
  return { a, b, plan };
}
