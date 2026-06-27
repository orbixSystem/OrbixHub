import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';

@Injectable()
export class TenancyRepository {
  constructor(private readonly prisma: PrismaService) {}

  getTenant(tenantId: string) {
    return this.prisma.tenant.findUnique({ where: { id: tenantId } });
  }

  async getTenantSettings(tenantId: string): Promise<Record<string, unknown>> {
    const t = await this.prisma.tenant.findUnique({ where: { id: tenantId } });
    return (t?.settings as Record<string, unknown>) ?? {};
  }

  async updateTenantSettings(tenantId: string, merged: Record<string, unknown>): Promise<void> {
    await this.prisma.tenant.update({
      where: { id: tenantId },
      data: { settings: merged as Prisma.InputJsonValue },
    });
  }

  async updateTenantIdentity(
    tenantId: string,
    data: { trade_name?: string | null; legal_name?: string | null; cnpj?: string | null; name?: string },
  ): Promise<void> {
    await this.prisma.tenant.update({ where: { id: tenantId }, data });
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

}
