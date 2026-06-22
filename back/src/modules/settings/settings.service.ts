import { BadRequestException, Inject, Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { SettingsSectionRegistry, COMPANY_SECTION } from './settings.section-registry';
import { BillingService } from '../billing/billing.service';
import { TenancyService } from '../tenancy/tenancy.service';
import { AuditService } from '../../common/audit/audit.service';
import { STORAGE_PROVIDER, StorageProvider } from '../../common/storage/storage.provider';
import { UpdateCompanyDto } from './dto/settings.dto';
import type { AuthUser } from '../../common/auth/auth.types';
import { UploadedImage } from './settings.types';

@Injectable()
export class SettingsService {
  private static readonly MAX_LOGO_BYTES = 4 * 1024 * 1024;

  constructor(
    private readonly registry: SettingsSectionRegistry,
    private readonly billing: BillingService,
    private readonly tenancy: TenancyService,
    private readonly audit: AuditService,
    @Inject(STORAGE_PROVIDER) private readonly storage: StorageProvider,
  ) {}

  async getSettings(user: AuthUser) {
    // Tudo vem de service público de outro módulo — Settings não toca tabela
    // alheia: company de tenancy (tenant.settings), módulos do billing.
    // Sequential, not Promise.all: getEnabledModules() opens a $transaction that
    // can reject under load; alongside a sibling in Promise.all that sibling's
    // late rejection becomes an unhandled rejection that crashes the process.
    const company = await this.tenancy.getCompanyView(user.tenantId);
    const enabled = await this.billing.getEnabledModules(user.tenantId);
    const moduleSections = this.registry
      .moduleSections()
      .filter((s) => s.moduleKey && enabled.includes(s.moduleKey));
    return { company, sections: [COMPANY_SECTION, ...moduleSections] };
  }

  async updateCompany(user: AuthUser, dto: UpdateCompanyDto) {
    const current = await this.tenancy.getCompanySettings(user.tenantId);
    const merged = { ...current, ...JSON.parse(JSON.stringify(dto)) };
    await this.tenancy.updateCompanySettings(user.tenantId, merged);
    await this.tenancy.syncCompanyIdentity(user.tenantId, {
      tradeName: dto.companyName,
      legalName: dto.legalName,
      cnpj: dto.taxId,
    });
    await this.audit.log(user.tenantId, user.userId, 'settings_change', 'company');
    return { company: await this.tenancy.getCompanyView(user.tenantId) };
  }

  async uploadLogo(user: AuthUser, file: UploadedImage | undefined) {
    if (!file?.buffer) throw new BadRequestException('Arquivo de imagem é obrigatório.');
    if (!file.mimetype?.startsWith('image/')) throw new BadRequestException('O arquivo deve ser uma imagem.');
    if (file.size > SettingsService.MAX_LOGO_BYTES) throw new BadRequestException('Imagem muito grande (máx. 4 MB).');

    const ext = (file.mimetype.split('/')[1] || 'png').replace(/[^a-z0-9]/gi, '');
    const key = `tenant/${user.tenantId}/logo/${randomUUID()}.${ext}`;
    // I/O FORA de transação (regra de ouro).
    await this.storage.put(key, file.buffer, file.mimetype);
    const url = this.storage.url(key);

    const current = await this.tenancy.getCompanySettings(user.tenantId);
    const oldKey = (current.logoStorageKey as string | undefined) ?? null;
    const merged = { ...current, logoUrl: url, logoStorageKey: key };
    await this.tenancy.updateCompanySettings(user.tenantId, merged);
    await this.audit.log(user.tenantId, user.userId, 'settings_change', 'company.logo');
    if (oldKey && oldKey !== key) { try { await this.storage.remove(oldKey); } catch { /* best-effort */ } }
    return { company: await this.tenancy.getCompanyView(user.tenantId) };
  }

  async removeLogo(user: AuthUser) {
    const current = await this.tenancy.getCompanySettings(user.tenantId);
    const key = current.logoStorageKey as string | undefined;
    const merged = { ...current };
    delete (merged as Record<string, unknown>).logoUrl;
    delete (merged as Record<string, unknown>).logoStorageKey;
    await this.tenancy.updateCompanySettings(user.tenantId, merged);
    await this.audit.log(user.tenantId, user.userId, 'settings_change', 'company.logo');
    if (key) { try { await this.storage.remove(key); } catch { /* best-effort */ } }
    return { company: await this.tenancy.getCompanyView(user.tenantId) };
  }
}
