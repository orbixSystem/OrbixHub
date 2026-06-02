import { ForbiddenException } from '@nestjs/common';
import { ModuleAccessGuard } from './module-access.guard';

function ctx(method: string, user: { tenantId: string } | undefined = { tenantId: 't1' }) {
  return {
    getHandler: () => ({}),
    getClass: () => ({}),
    switchToHttp: () => ({ getRequest: () => ({ method, user }) }),
  } as never;
}

function guardWith(row: { enabled: boolean; is_core: boolean } | null, status: string) {
  const reflector = { getAllAndOverride: () => 'os' } as never;
  const db = {
    subscription: { findFirst: jest.fn(async () => (status ? { status } : null)) },
    tenant_module: {
      findFirst: jest.fn(async () =>
        row ? { enabled: row.enabled, module: { is_core: row.is_core } } : null,
      ),
    },
  };
  const tenant = {
    runWithTenant: (_t: string, fn: () => unknown) => fn(),
    getClient: () => db,
  } as never;
  return new ModuleAccessGuard(reflector, tenant);
}

describe('ModuleAccessGuard', () => {
  it('passes for an enabled module on active subscription (write)', async () => {
    const g = guardWith({ enabled: true, is_core: false }, 'active');
    await expect(g.canActivate(ctx('POST'))).resolves.toBe(true);
  });
  it('403 when the module is disabled and not core', async () => {
    const g = guardWith({ enabled: false, is_core: false }, 'active');
    await expect(g.canActivate(ctx('GET'))).rejects.toBeInstanceOf(ForbiddenException);
  });
  it('past_due: allows GET, blocks POST', async () => {
    const read = guardWith({ enabled: true, is_core: false }, 'past_due');
    await expect(read.canActivate(ctx('GET'))).resolves.toBe(true);
    const write = guardWith({ enabled: true, is_core: false }, 'past_due');
    await expect(write.canActivate(ctx('POST'))).rejects.toBeInstanceOf(ForbiddenException);
  });
  it('canceled: blocks read and write', async () => {
    const g = guardWith({ enabled: true, is_core: false }, 'canceled');
    await expect(g.canActivate(ctx('GET'))).rejects.toBeInstanceOf(ForbiddenException);
  });
  it('is_core bypasses the enabled check', async () => {
    const g = guardWith({ enabled: false, is_core: true }, 'active');
    await expect(g.canActivate(ctx('GET'))).resolves.toBe(true);
  });
  it('no @RequiresModule -> passes', async () => {
    const reflector = { getAllAndOverride: () => undefined } as never;
    const tenant = {} as never;
    const g = new ModuleAccessGuard(reflector, tenant);
    await expect(g.canActivate(ctx('GET'))).resolves.toBe(true);
  });
});
