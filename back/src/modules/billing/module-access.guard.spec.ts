import { ForbiddenException } from '@nestjs/common';
import { ModuleAccessGuard } from './module-access.guard';

function ctx(method: string, user: { tenantId: string } | undefined = { tenantId: 't1' }) {
  return {
    getHandler: () => ({}),
    getClass: () => ({}),
    switchToHttp: () => ({ getRequest: () => ({ method, user }) }),
  } as never;
}

/** `enforce` = BILLING_ENFORCE_SUBSCRIPTION. Os casos de status assumem a régua
 *  LIGADA; com ela desligada (o default em produção hoje) o status não barra. */
function guardWith(
  row: { enabled: boolean; is_core: boolean } | null,
  status: string,
  enforce = true,
) {
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
  const env = { BILLING_ENFORCE_SUBSCRIPTION: enforce } as never;
  return new ModuleAccessGuard(reflector, tenant, env);
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
  it('is_core + past_due + write -> 403 (status gate not bypassed by core)', async () => {
    const g = guardWith({ enabled: false, is_core: true }, 'past_due');
    await expect(g.canActivate(ctx('POST'))).rejects.toBeInstanceOf(ForbiddenException);
  });
  it('no req.user -> 403', async () => {
    const g = guardWith({ enabled: true, is_core: false }, 'active');
    // Build the context inline: passing undefined to ctx() would hit the
    // default param value, so set user: undefined explicitly here.
    const noUser = {
      getHandler: () => ({}),
      getClass: () => ({}),
      switchToHttp: () => ({ getRequest: () => ({ method: 'GET', user: undefined }) }),
    } as never;
    await expect(g.canActivate(noUser)).rejects.toBeInstanceOf(ForbiddenException);
  });
  it('no @RequiresModule -> passes', async () => {
    const reflector = { getAllAndOverride: () => undefined } as never;
    const tenant = {} as never;
    const env = { BILLING_ENFORCE_SUBSCRIPTION: false } as never;
    const g = new ModuleAccessGuard(reflector, tenant, env);
    await expect(g.canActivate(ctx('GET'))).resolves.toBe(true);
  });

  describe('BILLING_ENFORCE_SUBSCRIPTION=false (default enquanto não há cobrança)', () => {
    it('past_due escreve normalmente', async () => {
      const g = guardWith({ enabled: true, is_core: false }, 'past_due', false);
      await expect(g.canActivate(ctx('POST'))).resolves.toBe(true);
    });
    it('canceled lê e escreve normalmente', async () => {
      const read = guardWith({ enabled: true, is_core: false }, 'canceled', false);
      await expect(read.canActivate(ctx('GET'))).resolves.toBe(true);
      const write = guardWith({ enabled: true, is_core: false }, 'canceled', false);
      await expect(write.canActivate(ctx('POST'))).resolves.toBe(true);
    });
    it('módulo desabilitado CONTINUA barrado (modularidade não é cobrança)', async () => {
      const g = guardWith({ enabled: false, is_core: false }, 'active', false);
      await expect(g.canActivate(ctx('GET'))).rejects.toBeInstanceOf(ForbiddenException);
    });
  });
});
