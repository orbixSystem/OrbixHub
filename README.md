# OrbixHub

SaaS de gestão multi-tenant (oficinas mecânicas), monorepo: `back/` (NestJS) + `front/` (Flutter).

Multi-tenant isolation is enforced at the database via Postgres Row-Level Security (RLS):
the verified JWT `tid` is stored in CLS per request, and all tenant-scoped DB work runs in
short interactive transactions that begin with `SET LOCAL app.current_tenant_id`. The app
connects as the non-privileged `app_user` (RLS enforced); migrations run as `app_migrator`
(BYPASSRLS).

Package manager is **npm workspaces** (`npm`, not pnpm). The local DB/cache run under
**Podman**; CI and `docker-compose.yml` use the standard ports.

---

## Local setup (npm + Podman)

### 1. Start the containers

Postgres 16 and Redis 7 run under Podman. On this machine they are already created and
healthy as `orbix-postgres` and `orbix-redis` — do not recreate them. To check / (re)start:

```bash
podman ps                       # both should be Up
podman start orbix-postgres orbix-redis   # if stopped
```

Port mapping (LOCAL / Podman):
- Postgres: host **55432** → container 5432 (`app_owner` / `owner_pw`, db `orbixhub`).
  Native PG already owns 5432 on this host, hence 55432.
- Redis: host **6379** → container 6379.

> CI and `docker-compose.yml` use **5432** for Postgres (services/compose). Only local
> Podman uses 55432. Keep your local `.env` on 55432.

### 2. Install dependencies

```bash
npm install            # run at repo root (npm workspaces)
```

### 3. Apply the baseline schema (roles + tables + RLS + functions + seeds)

The single source of truth is `back/sql/auth-multitenant-schema.sql` (also copied to the
Prisma baseline migration). Apply it as the table owner via the setup script — it creates
`app_user` / `app_migrator`, all tables, RLS policies, functions and seeds:

```bash
cd back
ADMIN_DATABASE_URL=postgresql://app_owner:owner_pw@localhost:55432/orbixhub \
  npx ts-node scripts/ci-db-setup.ts
```

**Run this again whenever you pull a new module.** The script is idempotent and safe on a
database that already has data: every DDL is guarded (`IF NOT EXISTS`, `OR REPLACE`,
`DROP ... IF EXISTS`) and the whole file runs in one implicit transaction, so a failure
applies nothing.

Re-running is how a database created earlier picks up the *backfills* of newer modules —
each module seeds `tenant_module` for existing tenants. Skipping this is why a module can
silently fail to appear in the menu: the navigation is gated by `me.modules`, so a tenant
without the `tenant_module` row simply doesn't see the screen, with no error anywhere.

Then generate the Prisma client:

```bash
npm run prisma:generate --workspace back
```

### 4. Environment variables

Copy `back/.env.example` to `back/.env` and keep it on port 55432 locally:

```
NODE_ENV=development
PORT=3000
# App connects as the NON-privileged app_user (RLS enforced)
DATABASE_URL=postgresql://app_user:app_user_pw@localhost:55432/orbixhub?schema=public
# Migrations run as app_migrator (BYPASSRLS)
MIGRATION_DATABASE_URL=postgresql://app_migrator:app_migrator_pw@localhost:55432/orbixhub?schema=public
REDIS_URL=redis://localhost:6379
JWT_ACCESS_SECRET=change_me_to_a_random_32_byte_minimum_secret_string
JWT_ACCESS_TTL=15m
REFRESH_TTL_DAYS=14
CORS_ORIGINS=http://localhost:3000,http://localhost:8080
ARGON_MEMORY_KIB=19456
ARGON_TIME_COST=2
ARGON_PARALLELISM=1
```

### 5. Run the API

```bash
npm run back:dev                # nest start --watch → http://localhost:3000/api
```

### 6. Tests, build, lint

```bash
# Unit suite
npm run test --workspace back

# Build + lint (0 warnings)
npm run build --workspace back
npm run lint  --workspace back

# e2e suite — flush redis first, then run with the local (55432) env inline.
podman exec orbix-redis redis-cli FLUSHALL
cd back && \
  DATABASE_URL=postgresql://app_user:app_user_pw@localhost:55432/orbixhub \
  MIGRATION_DATABASE_URL=postgresql://app_migrator:app_migrator_pw@localhost:55432/orbixhub \
  REDIS_URL=redis://localhost:6379 \
  JWT_ACCESS_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \
  CORS_ORIGINS=http://localhost:3000 \
  npm run test:e2e
```

> The e2e jest config sets `forceExit: true`. The throttler-storage Redis client and the
> global Redis provider are created with `new Redis(...)` and are not Nest lifecycle
> providers, so `app.close()` (called in each spec's `afterAll`) does not disconnect them
> and their sockets would otherwise keep the event loop alive — causing Jest to hang.
> `forceExit` guarantees the e2e run terminates on its own both locally and in CI.

---

## Identity endpoints (HTTP API, prefix `/api`)

Auth (`back/src/modules/auth`):
- `POST /api/auth/register` — create tenant + owner user + membership + trial subscription (atomic); returns access + refresh tokens.
- `POST /api/auth/verify-email` — consume an email-verify one-time token.
- `POST /api/auth/login` — authenticate; generic error (does not reveal whether an email exists); rate-limited.
- `POST /api/auth/refresh` — rotate the refresh token (reuse outside tolerance revokes the family).
- `POST /api/auth/logout` — revoke the current refresh token.
- `POST /api/auth/forgot-password` — issue a password-reset one-time token (generic response).
- `POST /api/auth/reset-password` — consume the reset token and set a new password.
- `POST /api/auth/switch-tenant` — issue tokens for another tenant the user belongs to.

IAM (`back/src/modules/iam`):
- `GET /api/iam/members` — list members of the active tenant.
- `DELETE /api/iam/members/:id` — remove a membership.
- `GET /api/iam/roles` — role catalog.
- `GET /api/iam/permissions` — permission catalog.
- `POST /api/tenants/invites` — create an invite for the active tenant.
- `POST /api/invites/accept` — accept an invite (joins the tenant).

Tenancy (`back/src/modules/tenancy`):
- `GET /api/me` — current user, active tenant, role, permissions, enabled modules, memberships.

Observability:
- `GET /api/health` — liveness/readiness (`pg` + `redis` status).

---

## Acceptance tests

The 9 mandatory acceptance criteria are covered by the e2e suites under `back/test/`:

- **`tenant-isolation.e2e-spec.ts`** — RLS isolation:
  - Criterion 1: data written under tenant A is invisible under tenant B (and a cross-tenant write under A is blocked by the `WITH CHECK` policy).
  - Criterion 2: without tenant context, RLS tables return zero rows (proves the app runs as `app_user`, not a BYPASSRLS role).
  - Criterion 9: cross-tenant write attempt is rejected by RLS `WITH CHECK` (the write-block assertion in this suite).
- **`auth.e2e-spec.ts`** — identity flows:
  - Criterion 3: refresh rotates and the rotated token works (family-revocation-on-reuse is owned by the `RefreshService` unit test).
  - Criterion 4: login is rate-limited (strict 5/min trips → 429).
  - Criterion 5: login does not reveal whether an email exists (identical generic 401).
  - Criterion 6: register creates tenant + owner + membership + trial atomically.
  - Criterion 7: register persists; `GET /me` reflects the committed identity.
  - Criterion 8: invalid / reserved slug is rejected (400).
- **`iam.e2e-spec.ts`** — members, roles/permissions, invite create + accept.
- **`me.e2e-spec.ts`** — `GET /me` shape (user, active tenant, role, permissions, modules, memberships).

See `docs/superpowers/specs/2026-06-01-orbixhub-auth-multitenant-design.md` for the full design.
