import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { TenantContext } from '../../common/database/tenant-context';

@Injectable()
export class SettingsRepository {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tenant: TenantContext,
  ) {}

  async getCompany(tenantId: string): Promise<Record<string, unknown>> {
    const t = await this.prisma.tenant.findUnique({ where: { id: tenantId } });
    return (t?.settings as Record<string, unknown>) ?? {};
  }

  async updateCompany(tenantId: string, merged: Record<string, unknown>): Promise<void> {
    await this.prisma.tenant.update({
      where: { id: tenantId },
      data: { settings: merged as Prisma.InputJsonValue },
    });
  }

  /** Module keys ENABLED for the active tenant (tenant_module is RLS). */
  async enabledModuleKeys(): Promise<string[]> {
    return this.tenant.withTenantTx(async () => {
      const db = this.tenant.getClient();
      const rows = await db.tenant_module.findMany({ where: { enabled: true } });
      const ids = rows.map((r) => r.module_id);
      const mods = await this.prisma.module.findMany({ where: { id: { in: ids } } });
      return mods.map((m) => m.key);
    });
  }
}
