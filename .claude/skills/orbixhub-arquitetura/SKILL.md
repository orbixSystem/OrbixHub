---
name: orbixhub-arquitetura
description: Use when building or changing anything in the OrbixHub repo (back/ NestJS or front/ Flutter) — new module, endpoint, screen, migration, plan, or refactor. Encodes the non-negotiable architecture rules, the "módulos independentes — aponta, não invade" law, the real module/role/plan inventory, and the new-module playbook.
---

# OrbixHub — Arquitetura & Convenções

## Contexto do produto

OrbixHub é um **SaaS de gestão multi-tenant e modular**. Primeiro vertical: **oficina
mecânica**, mas o core é genérico por design — a mesma base atende outros verticais
(petshop, salão, clínica) trocando/adicionando **módulos**. Cada tenant habilita os
módulos do seu **plano**; a régua do que ele vê vem de `/me` em runtime.

Três pilares: **multi-tenant com isolamento real (Postgres RLS)** · **identidade & acesso
por tenant** · **modularidade comercial (plano → módulos habilitados)**.

## Arquitetura geral

Monorepo npm workspaces:
- **`back/`** — NestJS, **monolito modular**, PostgreSQL + RLS, Redis. Camadas por módulo:
  **Controller fino → Service (lógica) → Repository (único que toca o banco)**. "DDD-lite":
  sem CQRS, sem event sourcing, sem aggregates.
- **`front/`** — Flutter (web/Windows). Riverpod 3 · go_router · dio · freezed. Feature-first:
  **presentation → domain (interface do repo) → data (impl dio + impl fake)**.

## Regras de ouro (NÃO-NEGOCIÁVEIS)

1. **MÓDULOS INDEPENDENTES — "aponta, não invade".** Um módulo guarda só o **id** de
   entidades de outro módulo (ex.: a OS guarda `cliente_id`, `veiculo_id`, `funcionario_id`)
   e busca os dados **via o service público** do outro módulo. **NUNCA** lê nem escreve a
   **tabela** de outro módulo. Apontar (FK + id) é saudável; tocar a tabela alheia é proibido.
   - ✅ `BillingService.getEnabledModules(tid)` ← assim a Tenancy lê módulos.
   - ❌ `db.tenant_module.findMany(...)` dentro de outro módulo (ver mini-audit em
     `docs/audit-arquitetura.md`).
2. **Snapshot histórico quando fizer sentido.** Registro transacional (ex.: OS) pode guardar
   um *retrato* de campos no momento da criação (nome do cliente, placa de então) para
   preservar histórico — apontando para o estado atual **e** sendo dono do próprio registro.
   Não fere a independência.
3. **Multi-tenant via RLS, sempre.** `tenant_id` vem **sempre do JWT verificado** (CLS),
   nunca do cliente. Toda operação tenant-scoped roda sob `withTenantTx`/`runWithTenant`
   (que faz `SET LOCAL app.current_tenant_id`). Tabelas de tenant têm **RLS + FORCE**. A app
   conecta como `app_user` (NOBYPASSRLS); migrations como `app_migrator`; DDL como `app_owner`.
   Fluxos públicos (webhook, tracking) resolvem o tenant no servidor via funções
   `SECURITY DEFINER` — nunca confiando em input do cliente.
4. **Genérico, sem casca de vertical vazando.** Nada de termo de oficina (ex.: "placa")
   hardcoded em módulo genérico. O específico do vertical fica isolado (entidade genérica
   `subject` + `attributes` jsonb + rótulo por config).
5. **Segurança.** Queries parametrizadas/ORM (nunca concatenar SQL); validação de input por
   whitelist (class-validator); segredos só via env (Zod em `common/config`); **nenhuma chamada
   externa dentro de transação de banco**; dev-tools (dev-inbox/"besouro") **só em dev**
   (`DEV_TOOLS_ENABLED` no back; `--dart-define=DEV_TOOLS` no front), ausentes em produção.
6. **Sem hard delete.** Arquivar/desativar (`status='disabled'`, `canceled_at`,
   `access_expires_at`), nunca apagar — preserva histórico.
7. **Mutações sensíveis são owner/permission-only** (`@Permissions('billing.manage')`, etc.)
   e **auditadas** (`AuditService.log`). Reauth (senha atual) em operações sensíveis de IAM.
8. **Front: UI só fala com repository** (interface no domain). Models imutáveis (freezed);
   estados de tela como unions selados. Strings de usuário em **PT-BR**.
9. **Migrations são ADITIVAS** e refletidas em 3 lugares mantidos juntos:
   `sql/auth-multitenant-schema.sql` (canônico/idempotente) + `prisma/migrations/NNNN_*/migration.sql`
   + `prisma/schema.prisma` (mantido à mão). Não quebre o baseline. **NÃO** use `prisma migrate
   deploy` pra subir o schema local — use `scripts/ci-db-setup.ts` como `app_owner`.
10. **Planos e módulos NUNCA são hardcoded no front.** Tudo vem de `/me` e `/billing/plans`.

> **Violar a letra das regras é violar o espírito das regras.**

## Taxonomia de módulo

- **Núcleo** (sempre ligado): `auth`, `iam`, `tenancy`, `billing`.
- **Host** (agrega os outros: config, dashboard, menu): `settings` (registry incremental).
- **Contratado** (gated por `tenant_module` + `@RequiresModule('chave')` + `ModuleAccessGuard`):
  módulos de produto (`os`, `customers`, `inventory`, …).
- **Dev-only**: `devtools` (dev-inbox), gated por env, ausente em prod.
- Eixo transversal: **genérico** (serve qualquer vertical) vs **casca de vertical** (isolada).

## Padrões transversais (use, não reinvente)

**Backend** (`back/src/common`):
- `database/tenant-context.ts` — `withTenantTx(fn)` (tenant do CLS), `runWithTenant(tid, fn)`
  (tenant explícito p/ webhook/job), `getClient()` (SEMPRE no repo — nunca injete `PrismaService`
  direto em tabela RLS), `bindTx`.
- `auth/` — `JwtAuthGuard`, `PermissionsGuard` + `@Permissions(...)`, `ActiveMembershipGuard`
  (revoga acesso mid-sessão via `auth_membership_active`), `@Public`, `@CurrentUser`.
- `billing/` — `ModuleAccessGuard` + `@RequiresModule('chave')` (past_due = leitura;
  canceled = bloqueia; `is_core` ignora flag enabled mas respeita status).
- `filters/` — erro no formato `{ statusCode, error, message }`.
- `config/` — env validado por Zod (`envSchema`). Segredos só aqui.
- `audit/` — `AuditService.log(tenantId, actorUserId, action, target?, metadata?)`.
- `mailer/` — `MailerService` abstrato; `DevMailerService` grava no dev-inbox só se `DEV_TOOLS_ENABLED`.

**Config é um host incremental:** cada módulo **registra** sua própria seção via
`SettingsSectionRegistry.register({ key, title, moduleKey, fields })` (`moduleKey:null` = núcleo;
senão aparece só se o módulo estiver habilitado). O host monta `/settings` a partir das seções
registradas+habilitadas — módulo novo só registra a sua seção. Documente em `docs/configuracao.md`.

**Dashboard e menu** seguem o mesmo padrão: cada módulo publica seu card/item; os hosts montam
conforme `me.modules[]`. No front, label/ícone em `shell/presentation/nav_items.dart`;
`gatedNavItems(me)` (função pura, testada) decide o menu por papel+módulo, e o router **também**
guarda as rotas (esconder ≠ proteger — o backend é a verdade; 403 tratado com elegância).

**Frontend** (`front/lib`): `di.dart` é o composition root (todos os providers). Sessão em
`SessionController` (Notifier<SessionState> selado: loading/authenticated/unauthenticated/error);
refresh single-flight no 401; access token só em memória, refresh só no secure storage.
Permissões genéricas (`customer.*`, `subject.*`, `os.*`…), nunca por vertical.

## Playbook — criar um módulo novo (checklist)

1. Branch `feat/<modulo>`; pasta `back/src/modules/<modulo>` (controller→service→repository) e,
   no app, feature `front/lib/features/<modulo>` (domain→data→presentation).
2. Entidades **genéricas** (sem termo de vertical); o específico em `attributes`/casca.
3. Migration **aditiva** (próximo número após o último) nos **3 lugares** (regra 9); **RLS + FORCE**
   nas tabelas de tenant; índices em `tenant_id` e nas buscas. Sem hard delete.
4. Permissões genéricas + mapeamento nos cargos (seed). Mutações sensíveis: `@Permissions` + auditar.
5. **Contratado?** Seed em `module` + `plan_module`; gate com `@RequiresModule('chave')` +
   `ModuleAccessGuard`. **Núcleo?** Sempre on (`is_core`). O front mostra sozinho via `me.modules`.
6. **Referenciar outros módulos por id + service público** — NUNCA a tabela deles (regra 1).
7. **Registrar a seção de config** no `SettingsSectionRegistry` + documentar em `docs/configuracao.md`.
8. Atualizar `docs/modulos-v1.md` se o estado/inventário mudar.
9. Front: registre providers em `di.dart` e a rota em `core/router/app_router.dart`; repo com
   interface no domain + impl dio + impl fake; models freezed; estado selado.
10. **Testes obrigatórios:** isolamento de tenant (A não vê B), autorização por cargo, guardrails do
    módulo. Sem I/O externo em transação; nenhuma dev-tool em prod.
11. **Evidência antes de "pronto":** `npm run back:lint` (0 warnings) + `back:test` + `back:test:e2e`;
    `flutter analyze` (0 issues) + `flutter test`. Cite o output real.

## Estado atual (código = fonte de verdade)

**Backend — 6 módulos:** `auth`, `iam`, `tenancy`, `billing` (núcleo) · `settings` (host, gated por
`@RequiresModule('settings')`) · `devtools` (dev-only). Detalhe e endpoints no `README.md`/`CLAUDE.md`.

**DB — tabelas RLS+FORCE:** `membership`, `invite`, `subscription`, `tenant_module`, `audit_log`
(policy `tenant_id = current_tenant_id()`). Globais sem RLS: `tenant`, `users`, `role`, `permission`,
`role_permission`, `refresh_token`, `one_time_token`, `login_attempt`, `module`, `plan`,
`plan_module`, `billing_webhook_event`. Roles PG: `app_owner` (dono/DDL), `app_migrator` (BYPASSRLS),
`app_user` (NOBYPASSRLS, runtime). Funções `SECURITY DEFINER`: `current_tenant_id`,
`auth_find_user_memberships`, `auth_find_invite_by_hash`, `billing_resolve_tenant_by_subscription`,
`billing_find_expired_trials`, `auth_membership_active`.

**Seeds reais (use estes nomes, não invente):**
- **Cargos (`role`):** `owner` (Dono), `mechanic` (Mecânico), `gerente` (Gerente),
  `caixa` (Caixa / Atendente).
- **Planos (`plan`):** `trial` (os, customers) · `pro` (os, inventory, customers).
- **Módulos (`module`):** `os`, `inventory`, `customers`.
- **Permissões genéricas:** `os.*`, `inventory.*`, `customer.*`, `subject.*`, `cashier.*`,
  `invoice.issue`, `finance.*`, `report.read`, `tracking.manage`, `users.manage`, `billing.manage`,
  `tenant.manage`, `settings.manage`.

**Módulos planejados (em `docs/modulos-v1.md`):** `tracking`, `cashier`, `invoice`, `finance`,
`report` — permissões já semeadas, sem implementação de backend ainda.

**Documentos canônicos:** o código + `docs/modulos-v1.md` + `docs/configuracao.md` + `README.md`.
Specs antigas em `docs/superpowers/` podem ter divergido — **não** são fonte de verdade.
