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
    const { DATABASE_URL, ...rest } = base;
    expect(() => envSchema.parse(rest)).toThrow();
  });
});
