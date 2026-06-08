import { Injectable } from '@nestjs/common';
import { TenancyRepository } from './tenancy.repository';
import { AuthRepository } from '../auth/auth.repository';
import { BillingService } from '../billing/billing.service';
import type { AuthUser } from '../../common/auth/auth.types';

@Injectable()
export class TenancyService {
  constructor(
    private readonly repo: TenancyRepository,
    private readonly authRepo: AuthRepository,
    private readonly billing: BillingService,
  ) {}

  async me(user: AuthUser) {
    const [u, tenant, permissions, modules, memberships] = await Promise.all([
      this.authRepo.findUserById(user.userId),
      this.repo.getTenant(user.tenantId),
      this.repo.permissionsForRole(user.role),
      this.billing.getEnabledModules(user.tenantId),
      this.authRepo.findUserMemberships(user.userId),
    ]);
    return {
      user: {
        id: u?.id,
        email: u?.email_normalized,
        fullName: u?.full_name,
        emailVerified: !!u?.email_verified_at,
      },
      activeTenant: tenant
        ? { id: tenant.id, slug: tenant.slug, name: tenant.name }
        : null,
      role: user.role,
      permissions,
      modules,
      memberships: memberships.map((m) => ({
        tenantId: m.tenant_id,
        tenantSlug: m.tenant_slug,
        role: m.role_key,
      })),
    };
  }

  /**
   * Settings da empresa (JSONB em tenant.settings). Tenancy é dono da tabela
   * `tenant` — outros módulos (ex.: Settings) leem/escrevem por aqui, não direto.
   */
  getCompanySettings(tenantId: string): Promise<Record<string, unknown>> {
    return this.repo.getTenantSettings(tenantId);
  }

  updateCompanySettings(tenantId: string, merged: Record<string, unknown>): Promise<void> {
    return this.repo.updateTenantSettings(tenantId, merged);
  }
}
