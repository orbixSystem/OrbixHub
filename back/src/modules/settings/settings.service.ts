import { Injectable } from '@nestjs/common';
import { SettingsRepository } from './settings.repository';
import { SettingsSectionRegistry, COMPANY_SECTION } from './settings.section-registry';
import { AuditService } from '../../common/audit/audit.service';
import { UpdateCompanyDto } from './dto/settings.dto';
import type { AuthUser } from '../../common/auth/auth.types';

@Injectable()
export class SettingsService {
  constructor(
    private readonly repo: SettingsRepository,
    private readonly registry: SettingsSectionRegistry,
    private readonly audit: AuditService,
  ) {}

  async getSettings(user: AuthUser) {
    const [company, enabled] = await Promise.all([
      this.repo.getCompany(user.tenantId),
      this.repo.enabledModuleKeys(),
    ]);
    const moduleSections = this.registry
      .moduleSections()
      .filter((s) => s.moduleKey && enabled.includes(s.moduleKey));
    return { company, sections: [COMPANY_SECTION, ...moduleSections] };
  }

  async updateCompany(user: AuthUser, dto: UpdateCompanyDto) {
    const current = await this.repo.getCompany(user.tenantId);
    const merged = { ...current, ...JSON.parse(JSON.stringify(dto)) };
    await this.repo.updateCompany(user.tenantId, merged);
    await this.audit.log(user.tenantId, user.userId, 'settings_change', 'company');
    return { company: merged };
  }
}
