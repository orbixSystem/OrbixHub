import { TenancyService } from './tenancy.service';
import { TenancyRepository } from './tenancy.repository';
import { AuthRepository } from '../auth/auth.repository';
import { BillingService } from '../billing/billing.service';
import { VocabularyService } from '../../verticals/vocabulary.service';
import { FeatureService } from '../../verticals/feature.service';
import { VerticalRegistry } from '../../verticals/vertical.registry';
import type { AuthUser } from '../../common/auth/auth.types';

/**
 * O VocabularyService entra REAL (é puro, sem banco): assim o teste prova que o
 * vocabulário do pacote chega mesmo ao /me, em vez de só provar que um mock foi
 * chamado. Só o FeatureService é falso, porque ele toca `tenant_feature`.
 */
function makeService(opts: {
  tenant?: Record<string, unknown> | null;
  features?: string[];
} = {}) {
  const tenant =
    opts.tenant === undefined
      ? { id: 't1', slug: 's1', name: 'N1', vertical: 'veiculos', settings: {} }
      : opts.tenant;

  const repo = {
    getTenant: jest.fn(async () => tenant),
    permissionsForRole: jest.fn(async () => ['os.read', 'os.write']),
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
  const billing = {
    getEnabledModules: jest.fn(async () => ['os', 'customers']),
  } as unknown as BillingService;
  const ligadas = jest.fn(async () => opts.features ?? ['os.trackingLink']);
  const features = { ligadas } as unknown as FeatureService;

  const svc = new TenancyService(
    repo,
    authRepo,
    billing,
    new VocabularyService(new VerticalRegistry()),
    features,
  );
  return { svc, ligadas };
}

const user: AuthUser = { userId: 'u1', tenantId: 't1', role: 'owner', jti: 'j' };

describe('TenancyService.me', () => {
  it('assembles user, activeTenant, role, permissions, modules, memberships', async () => {
    const { svc } = makeService();
    const me = await svc.me(user);

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

  it('devolve o vocabulário da vertical do tenant', async () => {
    const { svc } = makeService();
    const me = await svc.me(user);

    expect(me.vertical).toBe('veiculos');
    expect(me.vocab['objeto.singular']).toBe('Veículo');
    expect(me.vocab['objeto.identificador']).toBe('Placa');
    expect(me.vocab['os.status.entregue']).toBe('Veículo entregue');
    // Status que a vertical não redefine tem de vir do pacote padrão.
    expect(me.vocab['os.status.cancelada']).toBe('OS cancelada');
  });

  it('tenant sem vertical cai no pacote padrão', async () => {
    const { svc } = makeService({
      tenant: { id: 't1', slug: 's1', name: 'N1', vertical: null, settings: {} },
    });
    const me = await svc.me(user);

    expect(me.vertical).toBeNull();
    expect(me.vocab['objeto.singular']).toBe('Equipamento');
    expect(me.vocab['os.status.entregue']).toBe('Serviço entregue');
  });

  it('override do tenant ganha da vertical', async () => {
    const { svc } = makeService({
      tenant: {
        id: 't1', slug: 's1', name: 'N1', vertical: 'veiculos',
        settings: { vocabOverrides: { 'objeto.singular': 'Moto' } },
      },
    });
    const me = await svc.me(user);

    expect(me.vocab['objeto.singular']).toBe('Moto');
    expect(me.vocab['objeto.plural']).toBe('Veículos');
  });

  it('passa vertical e módulos habilitados ao resolver as features', async () => {
    // O módulo de verticais não lê tabela alheia: quem tem o dado é a Tenancy,
    // e ela precisa entregá-lo. Se isto quebrar, alguém abriu um forwardRef.
    const { svc, ligadas } = makeService({ features: ['os.trackingLink'] });
    const me = await svc.me(user);

    expect(ligadas).toHaveBeenCalledWith('t1', 'veiculos', ['os', 'customers']);
    expect(me.features).toEqual(['os.trackingLink']);
  });

  it('tenant inexistente não derruba o /me', async () => {
    const { svc } = makeService({ tenant: null });
    const me = await svc.me(user);

    expect(me.activeTenant).toBeNull();
    expect(me.vertical).toBeNull();
    expect(me.vocab['objeto.singular']).toBe('Equipamento');
  });
});
