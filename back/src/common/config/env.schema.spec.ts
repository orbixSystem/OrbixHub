import { envSchema } from './env.schema';

const base = {
  NODE_ENV: 'test',
  PORT: '3000',
  DATABASE_URL: 'postgresql://app_user:pw@localhost:5432/orbixhub',
  MIGRATION_DATABASE_URL: 'postgresql://app_migrator:pw@localhost:5432/orbixhub',
  REDIS_URL: 'redis://localhost:6379',
  JWT_ACCESS_SECRET: 'x'.repeat(32),
  JWT_ACCESS_TTL: '15m',
  REFRESH_TTL_DAYS: '14',
  CORS_ORIGINS: 'http://localhost:3000,http://localhost:8080',
  ARGON_MEMORY_KIB: '19456',
  ARGON_TIME_COST: '2',
  ARGON_PARALLELISM: '1',
};

describe('billing env knobs', () => {
  it('applies billing defaults', () => {
    const env = envSchema.parse(base);
    expect(env.TRIAL_PLAN_KEY).toBe('trial');
    expect(env.TRIAL_DAYS).toBe(14);
    expect(env.BILLING_REQUIRE_PAYMENT).toBe(false);
    // Régua de status DESLIGADA por padrão: esquecer a variável nunca trava o
    // tenant em somente-leitura enquanto não existe o módulo de assinatura.
    expect(env.BILLING_ENFORCE_SUBSCRIPTION).toBe(false);
  });
  it('parses BILLING_ENFORCE_SUBSCRIPTION="true" as true', () => {
    const env = envSchema.parse({ ...base, BILLING_ENFORCE_SUBSCRIPTION: 'true' });
    expect(env.BILLING_ENFORCE_SUBSCRIPTION).toBe(true);
  });
  it('parses BILLING_ENFORCE_SUBSCRIPTION="false" as boolean false (not truthy string)', () => {
    const env = envSchema.parse({ ...base, BILLING_ENFORCE_SUBSCRIPTION: 'false' });
    expect(env.BILLING_ENFORCE_SUBSCRIPTION).toBe(false);
  });
  it('parses BILLING_REQUIRE_PAYMENT="false" as boolean false (not truthy string)', () => {
    const env = envSchema.parse({ ...base, BILLING_REQUIRE_PAYMENT: 'false' });
    expect(env.BILLING_REQUIRE_PAYMENT).toBe(false);
  });
  it('parses BILLING_REQUIRE_PAYMENT="true" as true', () => {
    const env = envSchema.parse({ ...base, BILLING_REQUIRE_PAYMENT: 'true' });
    expect(env.BILLING_REQUIRE_PAYMENT).toBe(true);
  });
});

describe('envSchema', () => {
  it('parses a valid env', () => {
    const parsed = envSchema.parse(base);
    expect(parsed.PORT).toBe(3000);
    expect(parsed.CORS_ORIGINS).toEqual([
      'http://localhost:3000',
      'http://localhost:8080',
    ]);
  });

  it('rejects a short JWT secret', () => {
    expect(() => envSchema.parse({ ...base, JWT_ACCESS_SECRET: 'short' })).toThrow();
  });

  it('rejects a missing DATABASE_URL', () => {
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const { DATABASE_URL, ...rest } = base;
    expect(() => envSchema.parse(rest)).toThrow();
  });
});

describe('envSchema — Nuvem Fiscal', () => {
  it('aceita nuvemfiscal como FISCAL_PROVIDER e aplica defaults de URL', () => {
    const env = envSchema.parse({ ...base, FISCAL_PROVIDER: 'nuvemfiscal' });
    expect(env.FISCAL_PROVIDER).toBe('nuvemfiscal');
    expect(env.NUVEMFISCAL_BASE_URL).toBe('https://api.nuvemfiscal.com.br');
    expect(env.NUVEMFISCAL_AUTH_URL).toBe('https://auth.nuvemfiscal.com.br/oauth/token');
    expect(env.NUVEMFISCAL_CLIENT_ID).toBe('');
  });
});
