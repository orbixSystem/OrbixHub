import type { Config } from 'jest';
const config: Config = {
  moduleFileExtensions: ['js', 'json', 'ts'],
  rootDir: '..',
  testRegex: 'test/.*\\.e2e-spec\\.ts$',
  transform: { '^.+\\.ts$': 'ts-jest' },
  testEnvironment: 'node',
  testTimeout: 120000,
  // The throttler-storage-redis ioredis client and the global REDIS ioredis
  // provider are created via `new Redis(...)` and are NOT registered as Nest
  // lifecycle providers, so `app.close()` in each spec's afterAll does not
  // disconnect them. Those sockets keep the Node event loop alive and Jest
  // would otherwise hang after the suite finishes (Phase 7 used a CLI
  // --forceExit). Setting forceExit here makes the e2e run terminate on its
  // own everywhere (local `npm run test:e2e` and the CI step) without relying
  // on a CLI flag. Each spec still calls `await app.close()` so Prisma and the
  // HTTP server shut down cleanly before the process exits.
  // O autocadastro nasce DESLIGADO (ver `SELF_SIGNUP_ENABLED`), mas 21 suítes
  // usam `POST /auth/register` como fixture — é o caminho mais curto para ter
  // um tenant com dono e trial. Liga só aqui: produção continua fechada.
  setupFiles: ['<rootDir>/test/env.e2e.ts'],
  forceExit: true,
};
export default config;
