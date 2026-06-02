import { TenancyService } from './tenancy.service';
import { TenancyRepository } from './tenancy.repository';
import { AuthRepository } from '../auth/auth.repository';

describe('TenancyService.me', () => {
  it('assembles user, activeTenant, role, permissions, modules, memberships', async () => {
    const repo = {
      getTenant: jest.fn(async () => ({ id: 't1', slug: 's1', name: 'N1' })),
      permissionsForRole: jest.fn(async () => ['os.read', 'os.write']),
      enabledModules: jest.fn(async () => ['os', 'customers']),
    } as unknown as TenancyRepository;
    const authRepo = {
      findUserById: jest.fn(async () => ({
        id: 'u1',
        email_normalized: 'a@b.c',
        full_name: 'U',
        email_verified_at: new Date(),
      })),
      findUserMemberships: jest.fn(async () => [
        { tenant_id: 't1', tenant_slug: 's1', role_key: 'owner' },
      ]),
    } as unknown as AuthRepository;
    const svc = new TenancyService(repo, authRepo);

    const me = await svc.me({
      userId: 'u1',
      tenantId: 't1',
      role: 'owner',
      jti: 'j',
    });

    expect(me.user).toMatchObject({
      id: 'u1',
      email: 'a@b.c',
      fullName: 'U',
      emailVerified: true,
    });
    expect(me.activeTenant).toMatchObject({ id: 't1', slug: 's1', name: 'N1' });
    expect(me.role).toBe('owner');
    expect(me.permissions).toContain('os.write');
    expect(me.modules).toEqual(['os', 'customers']);
    expect(me.memberships).toHaveLength(1);
    expect(me.memberships[0]).toMatchObject({
      tenantId: 't1',
      tenantSlug: 's1',
      role: 'owner',
    });
  });
});
