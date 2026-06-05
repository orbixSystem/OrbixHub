import { z } from 'zod';

export const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(3000),
  DATABASE_URL: z.string().url(),
  MIGRATION_DATABASE_URL: z.string().url(),
  REDIS_URL: z.string().url(),
  JWT_ACCESS_SECRET: z.string().min(32),
  JWT_ACCESS_TTL: z.string().default('15m'),
  REFRESH_TTL_DAYS: z.coerce.number().int().positive().default(14),
  CORS_ORIGINS: z
    .string()
    .transform((s) => s.split(',').map((o) => o.trim()).filter(Boolean)),
  ARGON_MEMORY_KIB: z.coerce.number().int().positive().default(19456),
  ARGON_TIME_COST: z.coerce.number().int().positive().default(2),
  ARGON_PARALLELISM: z.coerce.number().int().positive().default(1),
  TRIAL_PLAN_KEY: z.string().default('trial'),
  TRIAL_DAYS: z.coerce.number().int().positive().default(14),
  // NB: z.coerce.boolean() treats the string "false" as TRUE. Parse explicitly.
  BILLING_REQUIRE_PAYMENT: z
    .string()
    .default('false')
    .transform((s) => s.toLowerCase() === 'true'),
  BILLING_WEBHOOK_SECRET: z.string().min(16).default('dev_billing_webhook_secret_change_me'),
});

export type Env = z.infer<typeof envSchema>;
