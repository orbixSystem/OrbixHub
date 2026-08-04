import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { SettingsSectionRegistry, COMPANY_SECTION } from './settings.section-registry';
import { BillingService } from '../billing/billing.service';
import { TenancyService } from '../tenancy/tenancy.service';
import { AuditService } from '../../common/audit/audit.service';
import { STORAGE_PROVIDER, StorageProvider } from '../../common/storage/storage.provider';
import { UpdateAppearanceDto, UpdateCompanyDto } from './dto/settings.dto';
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

    // Para cada seção de módulo, obtém os valores efetivos via callback registrado.
    // O callback é invocado sem transação RLS aberta — cada módulo é responsável
    // por usar runWithTenant/withTenantTx internamente se precisar.
    // Falha isolada de um módulo não deve derrubar o GET /settings inteiro.
    const sectionsWithValues = await Promise.all(
      moduleSections.map(async (section) => {
        // eslint-disable-next-line @typescript-eslint/no-unused-vars
        const { getValues, setValues, ...rest } = section;
        // `editable` diz à UI se a seção aceita PATCH — sem isso a tela teria de
        // adivinhar, e um toggle que não salva é pior que um toggle ausente.
        const editable = setValues != null;
        if (!getValues) return { ...rest, editable, values: {} };
        let values: Record<string, unknown> = {};
        try {
          values = await getValues(user.tenantId);
        } catch (err) {
          console.warn(`[settings] getValues para seção '${section.key}' falhou (best-effort):`, err);
        }
        return { ...rest, editable, values };
      }),
    );

    // A seção company não tem getValues — values omitido (ou {}) no response.
    return { company, sections: [COMPANY_SECTION, ...sectionsWithValues] };
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
    // Audit é best-effort: falha de infra transitória (pool esgotado, timeout)
    // não deve fazer o save retornar 500 — os dados já foram persistidos acima.
    try {
      await this.audit.log(user.tenantId, user.userId, 'settings_change', 'company');
    } catch (err) {
      console.warn('[settings] audit.log falhou (best-effort):', err);
    }
    return { company: await this.tenancy.getCompanyView(user.tenantId) };
  }

  async updateAppearance(user: AuthUser, dto: UpdateAppearanceDto) {
    const current = await this.tenancy.getCompanySettings(user.tenantId);
    // Merge apenas os campos de aparência — nada de empresa vaza por aqui.
    const merged = { ...current };
    if (dto.themePreset !== undefined) (merged as Record<string, unknown>).themePreset = dto.themePreset;
    if (dto.primaryColor !== undefined) (merged as Record<string, unknown>).primaryColor = dto.primaryColor;
    if (dto.secondaryColor !== undefined) (merged as Record<string, unknown>).secondaryColor = dto.secondaryColor;
    await this.tenancy.updateCompanySettings(user.tenantId, merged);
    try {
      await this.audit.log(user.tenantId, user.userId, 'settings_change', 'appearance');
    } catch (err) {
      console.warn('[settings] audit.log falhou (best-effort):', err);
    }
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
    try {
      await this.audit.log(user.tenantId, user.userId, 'settings_change', 'company.logo');
    } catch (err) {
      console.warn('[settings] audit.log falhou (best-effort):', err);
    }
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
    try {
      await this.audit.log(user.tenantId, user.userId, 'settings_change', 'company.logo');
    } catch (err) {
      console.warn('[settings] audit.log falhou (best-effort):', err);
    }
    if (key) { try { await this.storage.remove(key); } catch { /* best-effort */ } }
    return { company: await this.tenancy.getCompanyView(user.tenantId) };
  }
  /**
   * Aplica um patch nos valores de uma seção de módulo. O host NÃO conhece a
   * config do módulo: encaminha para o `setValues` que ele registrou, que valida
   * e persiste. Seção sem `setValues` é somente-leitura e recusa explicitamente.
   */
  async updateSection(
    user: AuthUser,
    key: string,
    patch: Record<string, unknown>,
  ): Promise<Record<string, unknown>> {
    const section = this.registry.section(key);
    if (!section) {
      throw new NotFoundException(`Seção de configuração desconhecida: ${key}`);
    }
    if (!section.setValues) {
      throw new BadRequestException(
        `A seção '${key}' é somente leitura.`,
      );
    }
    // Só chaves DECLARADAS no schema da seção: um patch com campo inventado é
    // erro do chamador, não algo a persistir calado.
    const declaradas = new Set(section.fields.map((f) => f.key));
    const desconhecidas = Object.keys(patch).filter((k) => !declaradas.has(k));
    if (desconhecidas.length) {
      throw new BadRequestException(
        `Campos não pertencem à seção '${key}': ${desconhecidas.join(', ')}`,
      );
    }
    const values = await section.setValues(user, patch);
    await this.audit.log(user.tenantId, user.userId, 'settings_change', key, {
      campos: Object.keys(patch),
    });
    return values;
  }
}
