import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';

@Injectable()
export class SettingsRepository {
  constructor(private readonly prisma: PrismaService) {}

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
}
