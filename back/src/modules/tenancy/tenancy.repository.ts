import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';

@Injectable()
export class TenancyRepository {
  constructor(private readonly prisma: PrismaService) {}

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

}
