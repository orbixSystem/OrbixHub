import {
  Injectable,
  OnModuleDestroy,
  OnModuleInit,
  Inject,
} from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { ENV } from '../config/config.module';
import type { Env } from '../config/env.schema';

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  constructor(@Inject(ENV) env: Env) {
    // Connects as app_user (RLS enforced) via DATABASE_URL.
    super({ datasources: { db: { url: env.DATABASE_URL } } });
  }
  async onModuleInit() {
    await this.$connect();
  }
  async onModuleDestroy() {
    await this.$disconnect();
  }
}
