import { z } from 'zod';

export const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(3000),
  DATABASE_URL: z.string().url(),
  MIGRATION_DATABASE_URL: z.string().url(),
  REDIS_URL: z.string().url(),
  JWT_ACCESS_SECRET: z.string().min(32),
  JWT_ACCESS_TTL: z.string().default('15m'),
  REFRESH_TTL_DAYS: z.coerce.number().int().positive().default(30),
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
  // --- Nota Fiscal (módulo invoice) ---
  // Gateway fiscal. 'noop' = autoriza sintético em dev (sem chamada externa);
  // 'govbr' = API NFS-e Nacional (gov.br), gratuita — impl real.
  FISCAL_PROVIDER: z.enum(['noop', 'govbr', 'nuvemfiscal']).default('noop'),
  // Ambiente fiscal default de novas notas.
  FISCAL_ENVIRONMENT: z.enum(['homologacao', 'producao']).default('homologacao'),
  // HMAC do webhook fiscal (assinatura sobre o corpo cru). Secret — nunca no front.
  INVOICE_WEBHOOK_SECRET: z.string().min(16).default('dev_invoice_webhook_secret_change_me'),
  // --- Nuvem Fiscal (provedor BaaS fiscal; credenciais globais da plataforma) ---
  NUVEMFISCAL_CLIENT_ID: z.string().default(''),
  NUVEMFISCAL_CLIENT_SECRET: z.string().default(''),
  NUVEMFISCAL_BASE_URL: z.string().default('https://api.nuvemfiscal.com.br'),
  NUVEMFISCAL_AUTH_URL: z
    .string()
    .default('https://auth.nuvemfiscal.com.br/oauth/token'),
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
  // --- Consulta de placas (apiplacas.com.br, servida em wdapi2.com.br) ---
  // Kill-switch: false = nunca chama fora (endpoint responde 503 "não configurada").
  // NB: z.coerce.boolean() treats the string "false" as TRUE. Parse explicitly.
  PLACAS_ENABLED: z
    .string()
    .default('false')
    .transform((s) => s.toLowerCase() === 'true'),
  // Token da conta na API Placas (secret — nunca enviado ao front).
  PLACAS_TOKEN: z.string().optional(),
  PLACAS_BASE_URL: z.string().default('https://wdapi2.com.br'),
  // Cota mensal contratada — o backend bloqueia consultas acima disto (contador
  // atômico em plate_lookup_usage; cache por placa não consome).
  PLACAS_MONTHLY_LIMIT: z.coerce.number().int().positive().default(1000),
  // --- Atualização do app instalado (Android/Windows) ---
  // Kill-switch: false = o endpoint responde "sem atualização" e nada é
  // consultado no GitHub.
  // NB: z.coerce.boolean() treats the string "false" as TRUE. Parse explicitly.
  APP_UPDATE_ENABLED: z
    .string()
    .default('false')
    .transform((s) => s.toLowerCase() === 'true'),
  // "owner/repo" de onde saem as releases.
  GITHUB_RELEASES_REPO: z.string().optional(),
  // Token de leitura do repositório PRIVADO (secret — nunca vai para o app;
  // o cliente recebe só a URL assinada que o servidor resolve).
  GITHUB_RELEASES_TOKEN: z.string().optional(),
  // --- Object storage (fotos da OS, etc.) ---
  // 'local' = disco (back/.storage, servido por GET /files/* — default dev, sem container);
  // 'minio' = S3-compatible (MinIO em dev / S3 em prod).
  STORAGE_PROVIDER: z.enum(['local', 'minio']).default('local'),
  // Base pública usada pelo provider local para montar a URL (rota GET /files/*).
  STORAGE_PUBLIC_URL: z.string().default('http://localhost:4400'),
  // Config do provider S3-compatible (opcional — só usada quando STORAGE_PROVIDER=minio).
  S3_ENDPOINT: z.string().optional(), // ex.: http://localhost:9000
  S3_REGION: z.string().default('us-east-1'),
  S3_ACCESS_KEY: z.string().optional(), // secret — nunca enviado ao front
  S3_SECRET_KEY: z.string().optional(), // secret — nunca enviado ao front
  S3_BUCKET: z.string().optional(), // ex.: orbix-os
  S3_PUBLIC_URL: z.string().optional(), // base pública p/ servir objetos (ex.: http://localhost:9000)
});

export type Env = z.infer<typeof envSchema>;
