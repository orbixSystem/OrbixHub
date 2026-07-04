---
name: orbixhub-testing
description: Use when writing or running OrbixHub backend tests (back/**) — unit (Jest) or e2e (Supertest). Encodes how to run them, why forceExit is needed, the 9 acceptance criteria mapping, and rules for RLS-touching tests.
---

# OrbixHub — Testes do Backend

## Tipos

- **Unit** (`*.spec.ts` ao lado do código): Jest + ts-jest. `npm run test --workspace back`.
- **E2E** (`back/test/*.e2e-spec.ts`): Supertest contra o app real + Postgres/Redis.
  `npm run test:e2e --workspace back` (roda com `--runInBand` e `forceExit: true`).

## Por que `forceExit`

O client Redis do throttler-storage e o provider Redis global são criados com `new Redis(...)` e
**não** são providers do ciclo de vida do Nest; `app.close()` não os desconecta e os sockets
manteriam o event loop vivo. `forceExit` garante o término do Jest local e na CI.

## Rodando e2e localmente

```bash
podman exec orbix-redis redis-cli FLUSHALL     # limpe o Redis antes
cd back && \
  DATABASE_URL=postgresql://app_user:app_user_pw@localhost:55432/orbixhub \
  MIGRATION_DATABASE_URL=postgresql://app_migrator:app_migrator_pw@localhost:55432/orbixhub \
  REDIS_URL=redis://localhost:6379 \
  JWT_ACCESS_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \
  CORS_ORIGINS=http://localhost:3000 \
  npm run test:e2e
```

> Local usa Postgres na **55432** (Podman). CI usa **5432**. Sempre limpe o Redis entre runs
> para não herdar contadores de rate limit.

## 9 critérios de aceitação (mapeamento)

- `tenant-isolation.e2e-spec.ts` — **1** (dados de A invisíveis para B), **2** (sem contexto, RLS
  retorna zero linhas — prova que roda como `app_user`), **9** (write cross-tenant barrado pela
  policy `WITH CHECK`).
- `auth.e2e-spec.ts` — **3** (refresh rotaciona; revogação de família no reuso é coberta pelo unit
  do `RefreshService`), **4** (login rate-limited → 429), **5** (login não revela e-mail → 401
  genérico), **6** (register cria tenant+owner+membership+trial atomicamente), **7** (register
  persiste; `GET /me` reflete), **8** (slug inválido/reservado → 400).
- `iam.e2e-spec.ts` — membros, roles/permissions, criar + aceitar convite.
- `me.e2e-spec.ts` — shape do `GET /me`.

## Ao escrever testes novos

- E2E que tocam tabelas com RLS devem autenticar e usar o tenant do token — não tente setar
  `app.current_tenant_id` manualmente.
- Use os helpers em `back/test/helpers/db.ts` para preparar/limpar estado.
- Mantenha cada spec capaz de chamar `app.close()` no `afterAll`.
- Módulos novos devem cobrir: **isolamento de tenant**, **autorização por cargo**, **guardrails do
  módulo** e (se houver webhook) **idempotência**. Ex.: o `invoice` deve testar OS cancelada/sem
  itens, nota duplicada e webhook idempotente.
