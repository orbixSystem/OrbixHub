import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { TenantContext } from '../../common/database/tenant-context';

@Injectable()
export class TenancyRepository {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tenant: TenantContext,
  ) {}

  getTenant(tenantId: string) {
    return this.prisma.tenant.findUnique({ where: { id: tenantId } });
  }

  async permissionsForRole(roleKey: string): Promise<string[]> {
    const rows = await this.prisma.$queryRaw<Array<{ key: string }>>`
      SELECT p.key FROM role r
      JOIN role_permission rp ON rp.role_id = r.id
      JOIN permission p ON p.id = rp.permission_id
      WHERE r.key = ${roleKey}
    `;
    return rows.map((r) => r.key);
  }

  /**
   * Enabled module keys for the active tenant. tenant_module is RLS-scoped, so
   * this runs inside withTenantTx (SET LOCAL app.current_tenant_id) and reads
   * the tx-scoped client via getClient(). The module relation is included so we
   * resolve keys in a single query without a follow-up findMany.
   */
  async enabledModules(): Promise<string[]> {
    return this.tenant.withTenantTx(async () => {
      const db = this.tenant.getClient();
      const tms = await db.tenant_module.findMany({
        where: { enabled: true },
        include: { module: true },
      });
      return tms.map((tm) => tm.module.key);
    });
  }
}
