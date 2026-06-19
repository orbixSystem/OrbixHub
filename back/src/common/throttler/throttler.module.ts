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
          // Limite para rotas públicas sem auth (página de acompanhamento da
          // OS: track + mensagens + chat do cliente). Enforçado SOMENTE pelo
          // PublicThrottlerGuard, que chaveia pelo TOKEN do link (não por IP) —
          // assim clientes atrás do mesmo IP de NAT/operadora não colidem. O
          // budget cobre o polling (track+mensagens a cada 15s ≈ 8/min) com
          // folga para os envios. Fica fora do guard global (default).
          { name: 'public', ttl: 60000, limit: 60 },
        ],
        storage: new ThrottlerStorageRedisService(new Redis(env.REDIS_URL)),
      }),
    }),
  ],
  exports: [ThrottlerModule],
})
export class AppThrottlerModule {}
