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
  DEV_TOOLS_ENABLED: z
    .string()
    .default('false')
    .transform((s) => s.toLowerCase() === 'true'),
  APP_PUBLIC_URL: z.string().default('http://localhost:8090'),
  // --- Inventory catalog lookup (código-first) ---
  // External GTIN/EAN catalog provider. 'noop' = always empty (validation phase).
  CATALOG_PROVIDER: z.enum(['noop', 'cosmos', 'openfoodfacts']).default('noop'),
  // Master kill-switch: false = never call out, providers return null.
  // NB: z.coerce.boolean() treats "false" as TRUE; parse explicitly.
  CATALOG_ENABLED: z
    .string()
    .default('false')
    .transform((s) => s.toLowerCase() === 'true'),
  // Bearer token for cosmos.bluesoft.com.br (secret — never sent to the front).
  COSMOS_TOKEN: z.string().optional(),
  // User-Agent exigido pela Cosmos (fornecido na sua conta ao logar).
  COSMOS_USER_AGENT: z.string().default('OrbixHub/1.0 (+https://orbixhub)'),
});

export type Env = z.infer<typeof envSchema>;
