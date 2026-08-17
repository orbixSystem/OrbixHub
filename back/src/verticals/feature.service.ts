import { BadRequestException, Injectable } from '@nestjs/common';
import { FeatureCatalog, VerticalRegistry } from './vertical.registry';
import { TenantFeatureRepository } from './tenant-feature.repository';
import { AuditService } from '../common/audit/audit.service';
import {
  featureDisponivel,
  featureLigada,
  featuresLigadas,
  type ContextoFeature,
} from './vertical.resolve';

/** Uma capacidade como a tela de configuração precisa vê-la. */
export interface FeatureView {
  key: string;
  moduleKey: string;
  nome: string;
  descricao: string;
  /** Efetivamente ligada agora. */
  enabled: boolean;
  /** O dono mexeu explicitamente? false = está herdando o pacote do nicho. */
  explicito: boolean;
}

/**
 * Resolve capacidades por tenant. Como no VocabularyService, os dados de outros
 * módulos (`verticalKey` da Tenancy, `modulosHabilitados` do Billing) vêm pelo
 * CHAMADOR — este módulo não lê tabela alheia e não abre forwardRef.
 */
@Injectable()
export class FeatureService {
  constructor(
    private readonly registry: VerticalRegistry,
    private readonly catalog: FeatureCatalog,
    private readonly repo: TenantFeatureRepository,
    private readonly audit: AuditService,
  ) {}

  private async contexto(
    tenantId: string,
    verticalKey: string | null | undefined,
    modulosHabilitados: string[],
  ): Promise<ContextoFeature> {
    return {
      modulosHabilitados,
      comImplementacao: this.registry.comImplementacao(),
      toggles: await this.repo.toggles(tenantId),
      verticalKey,
    };
  }

  /** Chaves ligadas — é o `features[]` do /me. */
  async ligadas(
    tenantId: string,
    verticalKey: string | null | undefined,
    modulosHabilitados: string[],
  ): Promise<string[]> {
    const ctx = await this.contexto(tenantId, verticalKey, modulosHabilitados);
    return featuresLigadas(this.catalog.todas(), ctx, this.registry.pacotes());
  }

  /**
   * Lista para a tela "Módulos e funcionalidades". Capacidade INDISPONÍVEL não
   * entra: mostrar um toggle que não faz efeito é pior que não mostrar nada.
   */
  async listar(
    tenantId: string,
    verticalKey: string | null | undefined,
    modulosHabilitados: string[],
  ): Promise<FeatureView[]> {
    const ctx = await this.contexto(tenantId, verticalKey, modulosHabilitados);
    const pacotes = this.registry.pacotes();
    return this.catalog
      .todas()
      .filter((d) => featureDisponivel(d, ctx))
      .map((d) => ({
        key: d.key,
        moduleKey: d.moduleKey,
        nome: d.nome,
        descricao: d.descricao,
        enabled: featureLigada(d, ctx, pacotes),
        explicito: ctx.toggles.has(d.key),
      }))
      .sort((a, b) => a.key.localeCompare(b.key));
  }

  /**
   * Liga/desliga explicitamente. Recusa chave fora do catálogo em vez de gravar
   * calado: linha órfã em `tenant_feature` seria um toggle fantasma que ninguém
   * consegue explicar depois.
   */
  async definir(
    tenantId: string,
    featureKey: string,
    enabled: boolean,
    actorUserId?: string,
  ): Promise<void> {
    if (!this.catalog.achar(featureKey)) {
      throw new BadRequestException(`Funcionalidade desconhecida: ${featureKey}`);
    }
    await this.repo.definir(tenantId, featureKey, enabled);
    if (actorUserId) {
      await this.audit.log(tenantId, actorUserId, 'feature_toggle', featureKey, {
        enabled,
      });
    }
  }

  /** Remove o toggle: volta a herdar o pacote da vertical. */
  async voltarAoPadrao(tenantId: string, featureKey: string): Promise<void> {
    if (!this.catalog.achar(featureKey)) {
      throw new BadRequestException(`Funcionalidade desconhecida: ${featureKey}`);
    }
    await this.repo.voltarAoPadrao(tenantId, featureKey);
  }
}
