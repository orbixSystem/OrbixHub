import { Controller, Get, Inject } from '@nestjs/common';
import Redis from 'ioredis';
// TODO(phase2): re-enable after PrismaService exists (Phase 2 Task 2.4)
// import { PrismaService } from '../database/prisma.service';
import { REDIS } from '../redis/redis.module';

@Controller('health')
export class HealthController {
  constructor(
    // TODO(phase2): re-enable after PrismaService exists (Phase 2 Task 2.4)
    // private readonly prisma: PrismaService,
    @Inject(REDIS) private readonly redis: Redis,
  ) {}

  @Get()
  async check() {
    const [db, cache]: [string, string] = await Promise.all([
      // TODO(phase2): re-enable PG check once PrismaService exists (Phase 2 Task 2.4)
      // this.prisma.$queryRaw`SELECT 1`.then(() => 'up').catch(() => 'down'),
      Promise.resolve('down'),
      this.redis.ping().then(() => 'up').catch(() => 'down'),
    ]);
    const status = db === 'up' && cache === 'up' ? 'ok' : 'degraded';
    return { status, db, cache };
  }
}
