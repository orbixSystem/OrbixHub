import { Injectable } from '@nestjs/common';
import { TenancyRepository } from './tenancy.repository';
import { AuthRepository } from '../auth/auth.repository';
import { BillingService } from '../billing/billing.service';
import { VocabularyService } from '../../verticals/vocabulary.service';
import { FeatureService } from '../../verticals/feature.service';
import type { AuthUser } from '../../common/auth/auth.types';

@Injectable()
export class TenancyService {
  constructor(
    private readonly repo: TenancyRepository,
    private readonly authRepo: AuthRepository,
    private readonly billing: BillingService,
    private readonly vocabulary: VocabularyService,
    private readonly features: FeatureService,
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

    // Nicho e capacidades. A Tenancy é dona da tabela `tenant`, então o
    // `vertical` e os overrides saem daqui e são PASSADOS para o módulo de
    // verticais — ele não lê tabela alheia e a dependência não vira ciclo.
    // `vocab` dirige os textos da UI; `features` gateia o que ela mostra, do
    // mesmo jeito que `modules` já faz — nada hardcoded no front.
    const vertical = tenant?.vertical ?? null;
    const vocabOverrides = (tenant?.settings as Record<string, unknown> | null)
      ?.vocabOverrides as Record<string, unknown> | undefined;
    const vocab = this.vocabulary.vocab(vertical, vocabOverrides);
    const features = await this.features.ligadas(user.tenantId, vertical, modules);

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
      vertical,
      vocab,
      features,
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

  /**
   * Visão mesclada da empresa para pré-preenchimento de formulário:
   * fallbacks derivados das colunas tipadas do tenant (nome, razão social, cnpj)
   * são sobrescritos pelos valores salvos no JSONB. Assim, um tenant recém-
   * registrado já vê seus dados básicos no formulário, sem precisar salvar
   * nada antes.
   *
   * Não deve ser usado como base de merge no updateCompany — o merge usa
   * getCompanySettings (JSONB puro) para evitar que os fallbacks sejam
   * persistidos no JSONB desnecessariamente.
   */
  async getCompanyView(tenantId: string): Promise<Record<string, unknown>> {
    const t = await this.repo.getTenant(tenantId);
    const settings = (t?.settings as Record<string, unknown>) ?? {};
    const fallbacks: Record<string, unknown> = {};
    if (t?.trade_name ?? t?.name) fallbacks.companyName = t?.trade_name ?? t?.name;
    if (t?.legal_name) fallbacks.legalName = t.legal_name;
    if (t?.cnpj) fallbacks.taxId = t.cnpj;
    return { ...fallbacks, ...settings };
  }

  updateCompanySettings(tenantId: string, merged: Record<string, unknown>): Promise<void> {
    return this.repo.updateTenantSettings(tenantId, merged);
  }

  /** Sincroniza colunas tipadas a partir do company settings (chamado pelo Settings). */
  async syncCompanyIdentity(
    tenantId: string,
    id: { tradeName?: string; legalName?: string; cnpj?: string },
  ): Promise<void> {
    const data: { trade_name?: string; legal_name?: string; cnpj?: string; name?: string } = {};
    if (id.tradeName !== undefined) { data.trade_name = id.tradeName; data.name = id.tradeName; }
    if (id.legalName !== undefined) data.legal_name = id.legalName;
    if (id.cnpj !== undefined) data.cnpj = id.cnpj;
    if (Object.keys(data).length === 0) return;
    await this.repo.updateTenantIdentity(tenantId, data);
  }
}
