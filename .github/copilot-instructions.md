# OrbixHub — Copilot Instructions

OrbixHub é um **SaaS multi-tenant de gestão modular**, organizado como um
monorepo: `back/` (NestJS + Prisma + Postgres + Redis) e `front/` (Flutter — esqueleto).

> **Visão de produto**: sistema de gestão **modular** (módulos habilitados por plano/tenant),
> com **oficinas mecânicas** como vertical inicial. Posicionamento: concorrente do **SG Master**.
> A modularidade (`module` / `plan_module` / `tenant_module` + `ModuleAccessGuard`) é central —
> novos verticais e funcionalidades entram como módulos ativáveis, não como forks do core.

> O isolamento entre tenants é garantido **no banco**, via Postgres Row-Level Security (RLS).
> Quase tudo que importa em segurança e correção do projeto gira em torno dessa decisão.

---

## Visão geral da arquitetura

```
OrbixHub/
├── back/                       # API NestJS (TypeScript, Node >= 20)
│   ├── prisma/                 # schema.prisma + migrations (baseline + invite-lookup + billing)
│   ├── sql/                    # auth-multitenant-schema.sql = fonte única de roles/RLS/funcs/seeds
│   ├── scripts/ci-db-setup.ts  # aplica o schema SQL de forma idempotente (roles + RLS + seeds)
│   ├── src/
│   │   ├── common/             # infraestrutura transversal (ver abaixo)
│   │   └── modules/            # domínios: auth, iam, tenancy, billing
│   └── test/                   # e2e (supertest) — 9 critérios de aceitação
├── front/                      # Flutter (Riverpod + go_router + dio + freezed) — placeholder
├── docker-compose.yml          # Postgres 16 + Redis 7 (porta 5432 / 6379)
└── .github/workflows/ci.yml    # lint → prisma generate → db-setup → unit → e2e
```

### Camada `common/` (infraestrutura)

| Pasta | Responsabilidade |
|-------|------------------|
| `config/` | Validação de env com **Zod** (`env.schema.ts`); provider `ENV` |
| `database/` | `PrismaService` (conecta como `app_user`, RLS ativo) + `TenantContext` (CLS) |
| `auth/` | `JwtAuthGuard`, `PermissionsGuard`, `AccessTokenService` (HS256), decorators |
| `crypto/` | `PasswordService` (**argon2id**), tokens opacos + hash |
| `tenant/` | `TenantInterceptor` — injeta o `tid` do JWT verificado no CLS |
| `throttler/` | Rate limiting global (120/min) com storage no Redis |
| `mailer/` | Envio de e-mail (dev: log) |
| `audit/` | `AuditService.log()` — grava `audit_log` em tx própria |
| `jobs/` | Tarefas agendadas (`@nestjs/schedule`): limpeza, expiração de trial |
| `observability/` | `/health`, `RequestIdMiddleware` |

### Módulos de domínio (`src/modules/`)

- **auth** — register, login, refresh (rotação + revogação de família), verify-email,
  forgot/reset-password, logout, switch-tenant.
- **iam** — membros, papéis, permissões, convites (create + accept).
- **tenancy** — `GET /me` (usuário, tenant ativo, papel, permissões, módulos, memberships).
- **billing** — planos, assinatura, trial, webhooks de pagamento, guard de acesso a módulos.

---

## Stack & bibliotecas

**Backend** (`back/package.json`):
- NestJS 10 (`@nestjs/common|core|platform-express`), Express, Helmet
- Prisma 5 (`@prisma/client`) + `pg` para SQL bruto/transações
- `nestjs-cls` 4 — Continuation-Local Storage (contexto de tenant por request)
- `@nestjs/jwt` + `jsonwebtoken` (HS256), `argon2` (hash de senha)
- `@nestjs/throttler` + `@nest-lab/throttler-storage-redis` + `ioredis`
- `zod` (validação de env), `class-validator` + `class-transformer` (DTOs)
- `@nestjs/schedule` (jobs cron)
- Testes: Jest + ts-jest, Supertest, Testcontainers

**Frontend** (`front/` — ainda esqueleto): Flutter com Riverpod, go_router, dio, freezed.

---

## Modelo de dados (Prisma / Postgres)

Tabelas **com RLS** (isoladas por tenant): `tenant`, `membership`, `invite`, `subscription`,
`tenant_module`, `audit_log`. Tabelas **globais** (sem RLS): `users`, `role`, `permission`,
`role_permission`, `module`, `plan`, `plan_module`, `one_time_token`, `refresh_token`,
`login_attempt`, `billing_webhook_event`.

- Papéis (`RoleKey`): `'owner' | 'mechanic'`.
- IDs são UUID (`gen_random_uuid()`), timestamps `Timestamptz`.
- Um `users` pode ter várias `membership` (multi-oficina) → `switch-tenant`.

---

## Regras inegociáveis (leia antes de mexer no backend)

1. **Tenant ID vem SEMPRE do JWT verificado** (`claims.tid` → `req.user.tenantId`).
   Nunca aceite tenant id vindo do corpo, query ou header do cliente.
2. **Todo acesso a tabela com RLS** deve passar por `TenantContext`:
   - `withTenantTx(fn)` — usa o tenant do request atual (CLS).
   - `runWithTenant(tenantId, fn)` — fluxos públicos (webhooks) com tenant resolvido no servidor.
   - Repositórios usam `tenant.getClient()` (nunca `PrismaService` direto em tabela com RLS).
3. **A app conecta como `app_user`** (RLS imposto). Migrations rodam como `app_migrator`
   (BYPASSRLS). Sem `SET LOCAL app.current_tenant_id`, tabelas com RLS retornam **zero linhas**.
4. **Anti-enumeração**: login/forgot-password retornam resposta genérica e idêntica,
   existindo ou não o e-mail (inclusive `dummyVerify` para resistir a timing).
5. **JWT só HS256** com allowlist de algoritmos (rejeita `alg:none` e confusão de chave).
6. **Ordem dos guards (global, em `app.module.ts`)**: `GlobalThrottlerGuard` →
   `JwtAuthGuard` (popula `req.user`) → `PermissionsGuard` (lê `req.user`). O
   `TenantInterceptor` roda depois dos guards.

---

## Convenções de código

- **Controllers** finos: validam DTO e delegam ao service. Rotas públicas com `@Public()`;
  protegidas exigem token. Permissões via `@Permissions('users.manage')`.
- **Services** orquestram regra de negócio; **repositories** isolam acesso a dados.
- I/O externo (e-mail, gateway de pagamento) acontece **fora** da transação e **após** o commit;
  falha de e-mail nunca faz rollback do cadastro.
- `audit.log()` abre tx própria → chame **por último**, fora de qualquer tx aberta.
- DTOs validados com `class-validator`; `ValidationPipe` global usa
  `whitelist + forbidNonWhitelisted + transform`.
- Prefixo global de rotas: `/api`. Mensagens ao usuário em **português**.

---

## Comandos (npm workspaces — use `npm`, não pnpm)

```bash
npm install                              # raiz do repo
npm run back:dev                         # nest start --watch → http://localhost:3000/api
npm run test --workspace back            # unit
npm run test:e2e --workspace back        # e2e (--runInBand, forceExit)
npm run build --workspace back           # nest build
npm run lint  --workspace back           # eslint --max-warnings 0
npm run prisma:generate --workspace back
```

DB local roda sob **Podman** na porta **55432** (Postgres) / **6379** (Redis); CI e
`docker-compose.yml` usam **5432**. Aplique o schema base com:
`ADMIN_DATABASE_URL=... npx ts-node scripts/ci-db-setup.ts`.

> Antes de usar tipos/componentes novos do Prisma, rode `prisma:generate`.
> Ao alterar o schema, atualize `sql/auth-multitenant-schema.sql` (fonte única) **e** as migrations.

---

## Estado atual & MVP (IMPORTANTE — consultar em todo prompt)

> O núcleo de oficina já está **implementado** (backend + Flutter feature-complete): além de
> `auth`/`iam`/`tenancy`/`billing`, existem `os`, `customers`, `inventory`, `messages`,
> `notifications`, `report`, `realtime` (WebSocket socket.io), `settings`, `devtools`.
> O front tem features de auth, os, customers, inventory, messages, report, settings, dashboard,
> tracking público, team e shell responsivo.

**O MVP exige fiscal + offline** (decisão do dono). Faltam:
- **Módulo `invoice`** (emissão de NF, online-only, via gateway fiscal abstrato) — não existe ainda.
- **Offline-first** (SQLite/drift + outbox + sync) para CRUD básico (clientes, OS, caixa, estoque),
  com indicador **online/offline em tempo real** e aviso de dados dessincronizados. Chat, link em
  tempo real e NF ficam **bloqueados offline**.
- **Destrave:** `flutter pub get` falha por Dart `^3.12.1` vs 3.11.3 → `flutter upgrade`.

**Regras transversais decididas:** (1) **responsividade é requisito AGORA** — toda tela para
desktop/web/mobile; (2) **auditoria de UI/UX/Design** só na **fase final**, quando tudo funcionar.

> Detalhes completos e decisões pendentes em
> `.github/instructions/mvp-roadmap.instructions.md` — **leia-o em toda tarefa**.

## Onde aprofundar

Há arquivos de contexto detalhados em `.github/instructions/` que se aplicam
automaticamente por pasta (mvp-roadmap, multi-tenancy/RLS, segurança de auth, billing, padrões de
backend, testes e frontend Flutter) e a skill `.claude/skills/orbixhub-arquitetura/SKILL.md`
(fonte de verdade da arquitetura). Consulte-os ao trabalhar em cada área.
