import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../database/prisma.service';

@Injectable()
export class CleanupService {
  private readonly log = new Logger('Cleanup');
  constructor(private readonly prisma: PrismaService) {}

  @Cron(CronExpression.EVERY_DAY_AT_3AM)
  async scheduled() {
    const res = await this.runCleanup();
    this.log.log(`cleanup: ${JSON.stringify(res)}`);
  }

  async runCleanup() {
    const now = Date.now();
    const ninetyDays = new Date(now - 90 * 86_400_000);
    const thirtyDays = new Date(now - 30 * 86_400_000);

    const la = await this.prisma.login_attempt.deleteMany({
      where: { created_at: { lt: ninetyDays } },
    });
    const ott = await this.prisma.one_time_token.deleteMany({
      where: {
        OR: [{ expires_at: { lt: new Date(now) } }, { consumed_at: { not: null } }],
      },
    });
    const rt = await this.prisma.refresh_token.deleteMany({
      where: {
        OR: [
          { expires_at: { lt: new Date(now) } },
          { revoked_at: { lt: thirtyDays } },
        ],
      },
    });
    return {
      loginAttempts: la.count,
      oneTimeTokens: ott.count,
      refreshTokens: rt.count,
    };
  }
}
