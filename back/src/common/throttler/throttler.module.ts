import { Module } from '@nestjs/common';
import { ThrottlerModule } from '@nestjs/throttler';
import { ThrottlerStorageRedisService } from '@nest-lab/throttler-storage-redis';
import Redis from 'ioredis';
import { ENV } from '../config/config.module';
import type { Env } from '../config/env.schema';

@Module({
  imports: [
    ThrottlerModule.forRootAsync({
      inject: [ENV],
      useFactory: (env: Env) => ({
        throttlers: [
          // Global IP-only limit, enforced by the global ThrottlerGuard.
          { name: 'default', ttl: 60000, limit: 120 },
          // Strict per IP+account limit, enforced ONLY by AuthThrottlerGuard
          // on register/login/forgot. Kept off the global guard so a shared
          // egress IP is not clamped to 5/min on those routes.
          { name: 'auth', ttl: 60000, limit: 5 },
          // Tight per-IP limit for public unauthenticated writes (chat do
          // cliente no link de acompanhamento). Enforced ONLY by
          // PublicThrottlerGuard; off the global guard.
          { name: 'public', ttl: 60000, limit: 10 },
        ],
        storage: new ThrottlerStorageRedisService(new Redis(env.REDIS_URL)),
      }),
    }),
  ],
  exports: [ThrottlerModule],
})
export class AppThrottlerModule {}
