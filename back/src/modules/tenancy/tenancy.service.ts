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
    // Sequential on purpose. getEnabledModules() opens a short $transaction
    // (maxWait 2s); under CPU/pool pressure it can time out and reject. With
    // Promise.all the first rejection is surfaced (→ handled 500) but the other
    // queries reject AFTER the combinator settled, becoming UNHANDLED rejections
    // that crash the whole process. Awaiting one at a time keeps a single
    // in-flight promise, caps peak connections per request at 1, and turns any
    // failure into a clean 500 instead of a server crash.
    const u = await this.authRepo.findUserById(user.userId);
    const tenant = await this.repo.getTenant(user.tenantId);
    const permissions = await this.repo.permissionsForRole(user.role);
    const modules = await this.billing.getEnabledModules(user.tenantId);
    const memberships = await this.authRepo.findUserMemberships(user.userId);
    return {
      user: {
        id: u?.id,
        email: u?.email_normalized,
        fullName: u?.full_name,
        emailVerified: !!u?.email_verified_at,
      },
      activeTenant: tenant
        ? {
            id: tenant.id,
            slug: tenant.slug,
            name: tenant.name,
            cnpj: tenant.cnpj ?? null,
            legalName: tenant.legal_name ?? null,
            tradeName: tenant.trade_name ?? null,
          }
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
