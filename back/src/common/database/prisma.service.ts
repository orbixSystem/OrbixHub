import {
  Injectable,
  OnModuleDestroy,
  OnModuleInit,
  Inject,
} from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { ENV } from '../config/config.module';
import type { Env } from '../config/env.schema';

/**
 * Ensures the DATABASE_URL has `connection_limit=20` set.
 * Appends the param defensively — preserves existing `?schema=public` or any
 * other query params already present.
 */
function withConnectionLimit(url: string, limit = 20): string {
  if (url.includes('connection_limit=')) return url;
  const sep = url.includes('?') ? '&' : '?';
  return `${url}${sep}connection_limit=${limit}`;
}

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  constructor(@Inject(ENV) env: Env) {
    // Connects as app_user (RLS enforced) via DATABASE_URL.
    // connection_limit=20 avoids "Unable to start a transaction in the given
    // time" under burst load (e.g. settings page opening several concurrent
    // requests).
    super({ datasources: { db: { url: withConnectionLimit(env.DATABASE_URL) } } });
  }
  async onModuleInit() {
    await this.$connect();
  }
  async onModuleDestroy() {
    await this.$disconnect();
  }
}
