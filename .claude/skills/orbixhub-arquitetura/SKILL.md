---
name: orbixhub-arquitetura
description: >
  LOAD PROACTIVELY at the start of every session in this repository — do not wait
  to be asked. Use when building or changing anything in OrbixHub (back/ NestJS or
  front/ Flutter): new module, endpoint, screen, migration, plan, or refactor.
  Encodes the non-negotiable architecture rules, the "módulos independentes — aponta,
  não invade" law, the real module/role/plan inventory, and the new-module playbook.
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

## Estado atual (código = fonte de verdade — atualizado 2026-07-04)

> O **código está à frente dos docs**: `docs/modulos-v1.md`/`pendencias.md` ainda listam
> `tracking`/`report` como "planejado", mas já estão implementados (ver abaixo). Em conflito,
> vale o que está wired em `back/src/app.module.ts` e em `front/lib/features/`.

**Backend — módulos wired em `app.module.ts` (15 + infra comum):**
- **Núcleo:** `auth`, `iam` (+ `employees`, `invites`, `reauth`), `tenancy` (`/me`), `billing`.
- **Host:** `settings` (registry incremental de seções de config).
- **Contratável implementado:** `os`, `customers` (+ `subjects`), `inventory` (+ catálogo EAN), `report`,
  `invoice` (**Nota Fiscal — backend**: emite NF da OS, online-only, via gateway fiscal abstrato Noop;
  ver skill `orbixhub-fiscal-invoice`).
- **Transversais implementados:** `messages` (chat/conversation), `notifications` (+ sino),
  `realtime` (**WebSocket/socket.io** — `@SubscribeMessage('subscribe:public'|'subscribe:staff')`,
  salas por conversa e por tenant, emite `message`), `storage` (`/files`, providers local/MinIO — **fotos da OS**).
- **Dev-only:** `devtools` (dev-inbox/"besouro", gated por `DEV_TOOLS_ENABLED`).
- **Rotas (`@Controller`):** `auth`, `billing`, `customers`, `subjects`, `inventory`, `os`,
  `public/track` (acompanhamento público via `public_token` + função `SECURITY DEFINER`),
  `messages`, `notifications`, `report`, `settings`, `files`, `health`.

**Tracking (acompanhamento cliente↔mecânico):** **funciona** via `os` (`public_token`) +
`public/track` + `realtime` (websocket) + tela `tracking/public_tracking_screen` no front,
**porém `tracking` ainda NÃO é um `module` semeado/gated** — é recurso da OS, não módulo comercial separado.

**DB — 45 tabelas** (conferido no banco em 2026-08-03; a contagem anterior de "35" estava
defasada). As **29 com RLS+FORCE** (policy `tenant_id = current_tenant_id()`):
`audit_log`, `business_hours`, `cash_entry`, `cash_expense_template`, `cash_session`,
`conversation`, `customer`, `inventory_item`, `invite`, `invoice`, `invoice_event`,
`invoice_line`, `membership`, `message`, `notification`, `sale`, `sale_item`, `service_order`,
`service_order_event`, `service_order_item`, `service_order_photo`,
`service_order_photo_comment`, `service_order_template`, `service_order_template_item`,
`stock_movement`, `subject`, `subscription`, `sync_mutation`, `tenant_module`.
`cash_expense_template` = despesas fixas (modelos de lançamento do caixa): **preset, não
agendador** — `amount = 0` significa "o valor varia".
Globais sem RLS: `tenant`, `users`, `role`, `permission`, `role_permission`, `refresh_token`,
`one_time_token`, `login_attempt`, `module`, `plan`, `plan_module`, `billing_webhook_event`,
`invoice_webhook_event`, `catalog_product` (cache EAN global 60d). Roles PG: `app_owner` (dono/DDL),
`app_migrator` (BYPASSRLS), `app_user` (NOBYPASSRLS, runtime).

**Seeds reais (use estes nomes, não invente):**
- **Cargos (`role`):** `owner`, `mechanic`, `gerente`, `caixa`.
- **Planos (`plan`):** `trial` (os, customers, invoice) · `pro` (os, inventory, customers, report, invoice).
- **Módulos semeados (`module`):** `os`, `inventory`, `customers`, `report`, `invoice`.
- **Permissões:** `os.*`, `inventory.*`, `customer.*`, `subject.*`, `cashier.*`, `invoice.issue`,
  `invoice.read`, `finance.*`, `report.read`, `tracking.manage`, `users.manage`, `billing.manage`,
  `tenant.manage`, `settings.manage`.

**Frontend — app Flutter completo (web + Windows).** Riverpod 3 · go_router 17 · dio · freezed ·
`socket_io_client` (realtime) · `printing`/`pdf` (export OS/relatórios) · `fl_chart` (dashboards) ·
`flutter_secure_storage` (refresh token) · `file_picker`. Features em `front/lib/features/`:
`auth` (login/register/verify/forgot/reset/accept-invite/tenant-picker), `shell` (app_shell, sidebar,
`gatedNavItems`), `dashboard` (widgets operacional/gestão, donut, métricas), `os` (lista/detalhe/form/
templates/PDF), `customers`, `inventory`, `report` (catálogo + CSV/PDF), `messages` (inbox+thread),
`notifications` (sino), `team` (membros/convite/troca de cargo/reauth/guards), `billing` (planos),
`settings` (aparência/empresa/seções dinâmicas), `tracking` (tela pública). Cada feature tem
`domain` (interface), `data` (impl dio **+ impl fake** p/ dev/teste) e `presentation`. ~30 testes em `front/test/`.

### Paralelo — PRONTO vs FALTA

✅ **Pronto:** plataforma SaaS (auth/RLS/RBAC/billing/módulos) · OS completa (itens, timeline,
fotos, templates, métricas) · clientes+subjects · estoque com diário (`stock_movement`) e catálogo
EAN · relatórios (6 endpoints + CSV/PDF) · chat + notificações · **tempo real (websocket)** ·
acompanhamento público da OS · storage de fotos · front multiplataforma (web/Windows) com todas as telas acima.

🚧 **Falta (backlog em `docs/pendencias.md` + brainstorm):**
- **Offline-first / sync (SQLite local ↔ nuvem)** — **NÃO existe** (sem sqflite/drift/hive no front;
  os "fake repositories" são p/ dev/teste, não persistência offline). Requisito do MVP.
- Módulo `invoice`: **backend pronto**; falta config sensível (certificado A1/série/CSC), testes e2e,
  `GovBrNfseGateway` real e a feature no front. Módulos **planejados sem backend:** `cashier`, `finance`.
- `tracking` como **módulo comercial gated** (hoje é recurso da OS).
- Entitlements por feature (freemium intra-módulo: `plan_feature`/`features[]` em `/me`).
- OS: envio do link público por **WhatsApp/e-mail** (hoje só "copiar link").
- Estoque avançado/pro: valorização, curva ABC, fornecedores, kits/combos, import CSV, IA de preço.

**Documentos canônicos:** o código + `docs/modulos-v1.md` + `docs/pendencias.md` +
`docs/configuracao.md` + `docs/audit-arquitetura.md` + `README.md`. Specs antigas em
`docs/superpowers/` podem ter divergido — **não** são fonte de verdade.

## Setup local desta máquina (sem container)

Não há Podman/Docker aqui — usamos **Postgres nativo (Homebrew) na porta 5432** (não 55432) e
**Redis nativo** (`brew services`). O `back/.env` aponta para `localhost:5432`. Fluxo:
`npm install` (raiz) → `ADMIN_DATABASE_URL=postgresql://app_owner:owner_pw@localhost:5432/orbixhub
npx ts-node scripts/ci-db-setup.ts` (cria roles+tabelas+RLS+seeds) → `npm run prisma:generate
--workspace back` → `npm run back:dev`. Health em `GET /api/health`. Regenerar o Prisma client
após qualquer mudança no schema (senão o build do back quebra).

**Front:** Flutter **3.44.4** (stable) em `~/Documents/flutter` (Dart 3.12+ — o projeto exige
`sdk ^3.12.1`). `cd front && flutter pub get && flutter analyze && flutter test`. Alvo runnable
nesta máquina = **web** (Chrome não instalado → `web-server`; targets do projeto: `web`+`windows`,
sem `macos`). `.vscode/launch.json`: "Back: dev/build/e2e", "Front: Flutter web (8090)" e
"Front: Flutter (chrome)". Porta 8090 já está em `CORS_ORIGINS` do back e em `APP_PUBLIC_URL`.
