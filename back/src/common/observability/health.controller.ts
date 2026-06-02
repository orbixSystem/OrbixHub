import { Controller, Get, Inject } from '@nestjs/common';
import Redis from 'ioredis';
import { PrismaService } from '../database/prisma.service';
import { REDIS } from '../redis/redis.module';

@Controller('health')
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: Redis,
  ) {}

  @Get()
  async check() {
    const [db, cache]: [string, string] = await Promise.all([
      this.prisma.$queryRaw`SELECT 1`.then(() => 'up').catch(() => 'down'),
      this.redis.ping().then(() => 'up').catch(() => 'down'),
    ]);
    const status = db === 'up' && cache === 'up' ? 'ok' : 'degraded';
    return { status, db, cache };
  }
}
