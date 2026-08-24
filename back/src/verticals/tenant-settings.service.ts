import { BadRequestException, Injectable } from '@nestjs/common';
import { BillingService } from '../modules/billing/billing.service';
import { TenancyService } from '../modules/tenancy/tenancy.service';
import { FeatureService } from './feature.service';

/**
 * Módulos e funcionalidades de UM tenant, por id — sem depender de quem chama.
 *
 * Existe porque duas superfícies precisam exatamente disso: o dono, pela tela
 * de Configurações (`/settings/modules`), e a Orbix, pelo sistema de admin
 * (`/admin/tenants/:id/modules`). Com a regra escrita uma vez só, não há como
 * o admin ligar uma funcionalidade que a tela do dono recusaria — que é o tipo
 * de divergência que só aparece no suporte, meses depois.
 *
 * Quem chama é responsável por provar quem é: o controller do dono exige
 * `settings.manage`; o do admin exige o token de serviço.
 */
@Injectable()
export class TenantSettingsService {
  constructor(
    private readonly billing: BillingService,
    private readonly tenancy: TenancyService,
    private readonly features: FeatureService,
  ) {}

  /**
   * Módulos contratados + as funcionalidades de cada um. Capacidade
   * indisponível para o nicho não vem na lista: toggle que não faz efeito é
   * pior que toggle ausente.
   */
  async listar(tenantId: string) {
    const modules = await this.billing.listTenantModules(tenantId);
    const habilitados = modules.filter((m) => m.enabled).map((m) => m.key);
    const vertical = await this.tenancy.getTenantVertical(tenantId);
    const features = await this.features.listar(tenantId, vertical, habilitados);
    return {
      vertical,
      modules: modules.map((m) => ({
        ...m,
        features: features.filter((f) => f.moduleKey === m.key),
      })),
    };
  }

  async alternarModulo(
    tenantId: string,
    /** `null` quando quem mexeu foi a Orbix, e não um usuário do tenant. */
    actorUserId: string | null,
    key: string,
    enabled: boolean,
  ) {
    await this.billing.setModuleEnabled(tenantId, actorUserId, key, enabled);
    return this.listar(tenantId);
  }

  async alternarFeature(
    tenantId: string,
    actorUserId: string | null,
    key: string,
    enabled: boolean,
  ) {
    const vertical = await this.tenancy.getTenantVertical(tenantId);
    const modules = await this.billing.listTenantModules(tenantId);
    const habilitados = modules.filter((m) => m.enabled).map((m) => m.key);
    // Recusa ligar o que está indisponível para o nicho, em vez de gravar uma
    // linha que o resolvedor ignoraria depois — toggle fantasma é dívida.
    const disponivel = await this.features.listar(tenantId, vertical, habilitados);
    if (!disponivel.some((f) => f.key === key)) {
      throw new BadRequestException(
        `Funcionalidade indisponível para este tenant: ${key}`,
      );
    }
    await this.features.definir(tenantId, key, enabled, actorUserId ?? undefined);
    return this.listar(tenantId);
  }
}
