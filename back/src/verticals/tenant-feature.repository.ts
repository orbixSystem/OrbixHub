import { Injectable } from '@nestjs/common';
import { TenantContext } from '../common/database/tenant-context';

/**
 * Único lugar que toca `tenant_feature`. Tabela tenant-scoped: todo acesso roda
 * sob `runWithTenant` (SET LOCAL app.current_tenant_id) — o filtro por tenant é
 * da RLS, não da query.
 *
 * Lembrete do design: linha só existe quando o dono mexeu no toggle. Ausência
 * NÃO é "desligado", é "herda do pacote da vertical".
 */
@Injectable()
export class TenantFeatureRepository {
  constructor(private readonly tenant: TenantContext) {}

  /** Toggles explícitos do tenant. Mapa vazio = ninguém mexeu em nada. */
  async toggles(tenantId: string): Promise<Map<string, boolean>> {
    return this.tenant.runWithTenant(tenantId, async () => {
      const db = this.tenant.getClient();
      const rows = await db.tenant_feature.findMany();
      return new Map(rows.map((r) => [r.feature_key, r.enabled] as const));
    });
  }

  /** Grava o toggle explícito. `source` marca quem decidiu (dono, plano, addon). */
  async definir(
    tenantId: string,
    featureKey: string,
    enabled: boolean,
    source = 'manual',
  ): Promise<void> {
    await this.tenant.runWithTenant(tenantId, async () => {
      const db = this.tenant.getClient();
      await db.tenant_feature.upsert({
        where: { tenant_id_feature_key: { tenant_id: tenantId, feature_key: featureKey } },
        create: { tenant_id: tenantId, feature_key: featureKey, enabled, source },
        update: { enabled, source, updated_at: new Date() },
      });
    });
  }

  /**
   * Apaga o toggle — o tenant volta a herdar o pacote da vertical. É a única
   * exclusão física do projeto e é deliberada: preferência de toggle não é
   * registro histórico (ver o GRANT na migration 0047).
   */
  async voltarAoPadrao(tenantId: string, featureKey: string): Promise<void> {
    await this.tenant.runWithTenant(tenantId, async () => {
      const db = this.tenant.getClient();
      await db.tenant_feature.deleteMany({ where: { feature_key: featureKey } });
    });
  }
}
