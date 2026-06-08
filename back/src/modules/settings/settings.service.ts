import { Injectable } from '@nestjs/common';
import { SettingsSectionRegistry, COMPANY_SECTION } from './settings.section-registry';
import { BillingService } from '../billing/billing.service';
import { TenancyService } from '../tenancy/tenancy.service';
import { AuditService } from '../../common/audit/audit.service';
import { UpdateCompanyDto } from './dto/settings.dto';
import type { AuthUser } from '../../common/auth/auth.types';

@Injectable()
export class SettingsService {
  constructor(
    private readonly registry: SettingsSectionRegistry,
    private readonly billing: BillingService,
    private readonly tenancy: TenancyService,
    private readonly audit: AuditService,
  ) {}

  async getSettings(user: AuthUser) {
    // Tudo vem de service público de outro módulo — Settings não toca tabela
    // alheia: company de tenancy (tenant.settings), módulos do billing.
    const [company, enabled] = await Promise.all([
      this.tenancy.getCompanySettings(user.tenantId),
      this.billing.getEnabledModules(user.tenantId),
    ]);
    const moduleSections = this.registry
      .moduleSections()
      .filter((s) => s.moduleKey && enabled.includes(s.moduleKey));
    return { company, sections: [COMPANY_SECTION, ...moduleSections] };
  }

  async updateCompany(user: AuthUser, dto: UpdateCompanyDto) {
    const current = await this.tenancy.getCompanySettings(user.tenantId);
    const merged = { ...current, ...JSON.parse(JSON.stringify(dto)) };
    await this.tenancy.updateCompanySettings(user.tenantId, merged);
    await this.audit.log(user.tenantId, user.userId, 'settings_change', 'company');
    return { company: merged };
  }
}
