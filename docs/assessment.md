# OrbixHub — Assessment de Arquitetura

> **Data:** 2026-06-27 · **Tipo:** assessment somente-leitura (nenhum código de feature alterado).
> **Fonte de verdade:** o código (`back/src/modules`, `front/lib/features`, `back/sql/auth-multitenant-schema.sql`, `back/prisma/migrations`). Docs em `docs/` usados como referência cruzada.
> **Método:** leitura do schema canônico (24 migrations) + auditoria paralela por cluster de módulos (back e front), checando a regra-mãe "aponta, não invade", RLS+FORCE, vazamento de vertical e segurança.

## 0. Sumário executivo

- **Backend:** 13 módulos implementados — muito além dos "6 módulos" que a skill `orbixhub-arquitetura` ainda lista. O core (auth/iam/tenancy/billing), o host (settings), o dev-only (devtools), **e** os contratados `customers`, `inventory`, `os`, `report`, mais os utilitários genéricos `messages`, `notifications`, `realtime`, estão **prontos e em conformidade arquitetural**.
- **Frontend:** 13 features Flutter, **12 totalmente conformes** e ligadas ao backend real. 1 violação leve do padrão repository (chamadas dio diretas a APIs externas em `settings/company_form.dart`).
- **Arquitetura:** **nenhuma violação ativa** da regra "aponta, não invade" no backend. As 3 violações históricas do `SettingsRepository` (`docs/audit-arquitetura.md`, 2026-06-08) foram corrigidas e **verificadas neste assessment** (o `SettingsRepository` deixou de existir).
- **Multi-tenant:** todas as tabelas de dados de tenant têm **RLS + FORCE + policy `tenant_isolation`**; `tenant_id` sempre do JWT/CLS; fluxos públicos (webhook, tracking, invite, trial-job) resolvem tenant via funções `SECURITY DEFINER`.
- **Divergência principal de docs:** a skill `orbixhub-arquitetura` (seção "Estado atual") está **desatualizada** — descreve um estado anterior à entrega de customers/inventory/os/report. `docs/modulos-v1.md` e `docs/configuracao.md` estão alinhados ao código.
- **Próximo módulo recomendado:** **`cashier` (Caixa)** — fecha o ciclo financeiro da OS (que já é o centro implementado), aponta para `OsService` por id+service público, e é pré-requisito natural de `finance`. Ver §4.

---

## 1. Inventário real × skill/docs

| Fonte | Módulos backend que lista | Status |
|---|---|---|
| Skill `orbixhub-arquitetura` ("Estado atual") | auth, iam, tenancy, billing, settings, devtools (**6**) | **Desatualizada** |
| `docs/modulos-v1.md` | núcleo + customers, inventory, os, report (impl.); tracking/cashier/invoice/finance (planejados) | Alinhada (report/os já como impl.) |
| **Código (real)** | **13**: auth, iam, tenancy, billing, settings, devtools, customers, inventory, os, report, messages, notifications, realtime | Fonte de verdade |

> **Ação sugerida:** atualizar a seção "Estado atual" da skill para refletir os 13 módulos (não altero a skill neste assessment).

---

## 2. Relatório por módulo — Backend

### Núcleo

#### `auth` — Identidade & sessão
- **O que é / tipo:** núcleo, genérico. Registro atômico (tenant+owner+membership+trial), login anti-enumeração + rate-limit, refresh rotativo, verify/forgot/reset, switch-tenant, cnpj-lookup.
- **Tabelas:** `users`, `refresh_token`, `one_time_token`, `login_attempt` — **globais (sem RLS)**, por design (identidade cross-tenant).
- **Endpoints:** `POST /auth/{register,verify-email,login,refresh,logout,forgot-password,reset-password,cnpj-lookup}` (todos `@Public`, sensíveis com throttle 5/min) · `POST /auth/switch-tenant` (JWT).
- **Estado:** **pronto**.
- **Integrações:** injeta `BillingService.createTrial()` dentro da MESMA transação do registro (`auth.repository.ts:231`, via `bindTx`) — trial atômico, sem tocar tabela do billing. ✅
- **Config:** não registra seção. **Pendências:** nenhuma relevante.

#### `iam` — Membros, cargos, convites
- **Tipo:** núcleo, genérico. Membros, papéis, permissões, convites (criar/aceitar/cancelar), reauth em operações sensíveis.
- **Tabelas:** `membership`, `invite` — **RLS + FORCE**.
- **Endpoints:** `GET /iam/{members,roles,permissions}` · `POST /tenants/invites` (`users.manage`) · `POST /invites/accept` (`@Public`) · `GET /employees`, `/employees/assignable`, `/roles` · `PATCH /employees/:id/role` + `POST /employees/:id/{activate,deactivate}` (`users.manage` + **reauth**).
- **Estado:** **pronto**.
- **Integrações:** expõe `resolveMemberName(tenantId, userId)` (service público) consumido por `os`/`report`. ✅
- **Config:** não. **Pendências:** nenhuma.

#### `tenancy` — `GET /me` (dirige a UI)
- **Tipo:** host (dono da tabela `tenant`), genérico. Monta usuário+tenant+role+permissions[]+modules[]+memberships.
- **Tabelas:** `tenant` (global, sem RLS — write deve ser restrito por app). Lê módulos via `BillingService.getEnabledModules()` (**não** toca `tenant_module`). ✅
- **Endpoints:** `GET /me` (JWT).
- **Estado:** **pronto**. Expõe `getCompanySettings/updateCompanySettings/syncCompanyIdentity` para o Settings consumir (em vez de o Settings tocar `tenant`).
- **Config:** não (é consumidor). **Pendências:** nenhuma.

#### `billing` — Modularidade comercial
- **Tipo:** host (dono de subscription/entitlements), genérico. Planos, assinatura, `reconcileTenantModules`, `ModuleAccessGuard` + `@RequiresModule`, webhook HMAC + idempotência, job diário de trial, gateway abstrato (Noop).
- **Tabelas:** `subscription`, `tenant_module` (**RLS + FORCE**); `plan`, `plan_module`, `module`, `billing_webhook_event` (globais).
- **Endpoints:** `GET /billing/{plans,subscription}` · `POST /billing/{subscribe,change-plan}` (`billing.manage`) · `POST /billing/webhook` (`@Public`, assinatura verificada).
- **Estado:** **pronto**.
- **Segurança (webhook):** assinatura HMAC-SHA256 **timing-safe** verificada antes de tudo; `createCheckout()` **fora** de transação de DB; tenant resolvido por `billing_resolve_tenant_by_subscription()` (SECURITY DEFINER) — **nunca** do payload; idempotência por `external_event_id`. ✅
- **Config:** não. **Pendências:** entitlements por *feature* (não só por módulo) — ver `docs/pendencias.md`.

### Host

#### `settings` — Host incremental de configuração
- **Tipo:** host, genérico. Seção núcleo (empresa/branding/fiscal/endereço/aparência) + uma seção por módulo contratado registrada via `SettingsSectionRegistry`.
- **Tabelas:** **nenhuma própria**. Empresa → `tenant.settings` via `TenancyService`; settings de módulo → `tenant_module.settings[key]` via `BillingService`.
- **Endpoints:** `GET /settings` · `PATCH /settings/appearance` · `PATCH /settings/company` + `POST/DELETE /settings/company/logo` (`settings.manage`).
- **Estado:** **pronto**. **Verificação deste assessment:** o `SettingsRepository` foi **removido**; `settings.service.ts` só chama `TenancyService` e `BillingService`. As 3 violações de 2026-06-08 estão **corrigidas e confirmadas**. ✅
- **Config:** é o próprio host. **Pendências:** opção de longo prazo (não adotada) de dar ao settings sua própria tabela `tenant_settings`.

### Dev-only

#### `devtools` — Dev-inbox
- **Tipo:** dev-only. `GET /dev/inbox` (`@Public`).
- **Gating:** o controller só é registrado se `process.env.DEV_TOOLS_ENABLED === 'true'` (`devtools.module.ts`). **Ausente em produção** quando a env está off. ✅

### Contratados (gated por `@RequiresModule`)

#### `customers` — Clientes & Subjects (genérico)
- **Tipo:** contratado, **genérico** (subject + attributes + label por config; "veículo/placa" só em comentários/defaults, nunca no runtime). No plano `trial` e `pro`.
- **Tabelas:** `customer`, `subject` — **RLS + FORCE**. `document` único por tenant (índice parcial). Soft delete (`status='deleted'`).
- **Endpoints:** ~20 — `/customers` CRUD + archive/unarchive + `/customers/config` (read/`settings.manage`) + `/customers/metrics` + `/customers/:id/history` + `/customers/lookups/:fonte` (FIPE) + `/subjects` CRUD. Gated `@RequiresModule('customers')`.
- **Estado:** **pronto**.
- **Integrações:** lê/grava config via `BillingService.getModuleSettings/setModuleSettings` (não toca `tenant_module`). Recebe `SubjectHistoryProvider` (seam) preenchido pelo `os` (`OsSubjectHistoryProvider`) — "aponta, não invade" exemplar. ✅
- **Externo:** FIPE (`https://fipe.parallelum.com.br`) **fora** de transação, cache Redis 24h, degradação graciosa. Sem segredo hardcoded.
- **Config:** registra seção `clientes_veiculos` (`moduleKey: 'customers'`).
- **Pendências:** `SubjectHistoryProvider` default é stub vazio quando o `os` não está no contexto.

#### `inventory` — Estoque & Serviços (genérico)
- **Tipo:** contratado, **genérico** (tipo `produto`|`serviço`; campos da vertical via `itemFields`+`attributes` whitelist). No `trial` e `pro`.
- **Tabelas:** `inventory_item`, `stock_movement` — **RLS + FORCE**; `catalog_product` — **global (sem RLS)**, cache durável EAN→produto (dado público compartilhado). Soft delete (`deleted_at`).
- **Endpoints:** `/inventory/items` CRUD + archive + `/inventory/{config,metrics,lookup,low-stock,sku-suggestion}`. Gated `@RequiresModule('inventory')`.
- **Estado:** **pronto**. Diário `stock_movement` + `reconcileConsumption` (idempotente) para a OS; `stock_applied` deprecado.
- **Integrações:** expõe `getItem/getItemsByIds/incrementStock/decrementStock/reconcileConsumption` para a OS. `NotificationsService` p/ alerta de estoque baixo (fora de tx). Config via `BillingService`. ✅
- **Externo:** Cosmos (`X-Cosmos-Token` da env) e OpenFoodFacts, **fora** de transação, cache em `catalog_product`, degradação graciosa. Sem segredo hardcoded.
- **Config:** registra seção `inventory` (campos escalares vazios; `itemFields` gerida por endpoint próprio).
- **Pendências:** valorização de estoque/curva ABC/fornecedores/kits — backlog em `docs/pendencias.md`.

#### `os` — Ordens de Serviço (centro operacional)
- **Tipo:** contratado, **genérico** (subject vem do `customers`; só guarda id + snapshot). No `trial` e `pro`.
- **Tabelas:** `service_order`, `service_order_item`, `service_order_event` (timeline), `service_order_photo`, `service_order_template`(+`_item`) — **todas RLS + FORCE**. `public_token` único para tracking.
- **Endpoints (autenticados, `@RequiresModule('os')`):** `/os/orders` CRUD + `/os/orders/:id/status` (`os.approve` p/ aprovar/reabrir) + `/items` + `/notes` + `/photos` + `/os/templates` CRUD + `apply-template` + `/os/metrics`. **Públicos (`@Public` + throttle):** `GET /public/track/:token` (+ `/messages` GET/POST).
- **Estado:** **pronto (Fase 1 + chat público + métricas)**. Lentes Fase 2 (revenue/team/top-items) já no `OsMetricsService` e **consumidas pelo `report`**.
- **Integrações:** injeta `CustomersService`, `InventoryService`, `MessagesService`, `IamService`, `AuditService`, `StorageProvider` — todas via service público, chamadas **fora** da transação da OS; storage fora de tx. Resolve público via `os_resolve_by_public_token()` (SECURITY DEFINER). ✅
- **Config:** não registra seção (defaults hardcoded: foto 8MB, page 20).
- **Pendências:** baixa automática por WhatsApp/e-mail do link público (hoje só "copiar link"); config tenant-scoped opcional.

#### `report` — Relatórios (compositor sem tabela)
- **Tipo:** contratado, **genérico**. **Sem tabela própria** — compõe on-the-fly via services públicos. No `trial` e `pro` (grátis hoje; paywall futuro = remover do plano).
- **Tabelas:** **nenhuma** (verificado: 0 leituras de tabela alheia). ✅
- **Endpoints:** `GET /report/{os,os.csv,os.pdf,revenue,team,top-items,inventory,inventory.csv,inventory.pdf,customers}` — `@Permissions('report.read')` + `@RequiresModule('report')`.
- **Estado:** **pronto** (incl. export CSV/PDF com cabeçalho da empresa).
- **Integrações:** injeta `OsMetricsService`, `InventoryMetricsService`, `CustomersMetricsService`, `EmployeesService`, `BillingService` (checa módulo habilitado por relatório). ✅
- **Config:** não. **Pendências:** nenhuma observada.

### Utilitários genéricos (transversais, não contratados)

#### `messages` — Conversas (ref_type/ref_id agnóstico)
- **Tipo:** genérico/utilitário. Hoje alimentado só pela OS, mas serve qualquer módulo.
- **Tabelas:** `conversation`, `message` — **RLS + FORCE**.
- **Endpoints:** `GET /messages/conversations` (+ `/:id`), `POST /messages/conversations/:id/{messages,read}`.
- **Estado:** **pronto**. **Dívida:** permissões reusam `os.read`/`os.write` (v1) — TODO migrar para `messages.*` (comentado no código).
- **Integrações:** `NotificationsService` ao receber mensagem do cliente. ✅

#### `notifications` — Inbox tenant-wide
- **Tipo:** genérico/utilitário (`@Global`).
- **Tabelas:** `notification` — **RLS + FORCE**.
- **Endpoints:** `GET /notifications`, `POST /notifications/:id/read`, `POST /notifications/read-all` (JWT; sem `@RequiresModule`).
- **Estado:** **pronto**. `updateMany` para não vazar 404 entre tenants. ✅

#### `realtime` — WebSocket push
- **Tipo:** genérico/infra. Sem tabela; não toca o banco.
- **Canais:** `subscribe:public` (token público → `OsPublicService.resolveConversationByToken`, SECURITY DEFINER) e `subscribe:staff` (**JWT verificado**, HS256-only; valida `conversationBelongsToTenant`). Rooms namespaced `conv:<id>` / `tenant:<id>`.
- **Estado:** **pronto**. **Segurança:** nenhum `tenant_id` do cliente; isolamento por room + RLS na resolução. ✅

---

## 3. Relatório por feature — Frontend (Flutter)

Padrão geral respeitado: **presentation → domain (interface) → data (impl dio + fake)**; UI só fala com repository; sessão selada; refresh single-flight; gating dinâmico via `gatedNavItems(me)` + guarda no router.

| Feature | Camadas (domain/data/fake) | Estado | Ligada ao back real? | Violações |
|---|---|---|---|---|
| `auth` | ✅ completa | pronto | sim | — |
| `billing` | ✅ completa | pronto | sim (`/billing/plans`, sem hardcode) | — |
| `customers` | ✅ completa | pronto | sim | "Veículo/placa" vêm da config (não hardcoded) |
| `inventory` | ✅ completa | pronto | sim | — |
| `os` | ✅ completa | pronto | sim | "Veículo" como label/fallback em telas **da OS** (módulo-específico, aceitável) |
| `report` | ✅ completa | pronto | sim (gated `report.read`) | — |
| `dashboard` | ✅ completa | pronto | sim | — |
| `messages` | ✅ completa | pronto | sim (+ WS) | — |
| `notifications` | ✅ completa | pronto | sim (+ WS) | — |
| `team` | ✅ completa | pronto | sim | — |
| `settings` | ✅ + CompanyForm | pronto | sim | **dio direto** a APIs externas (ver abaixo) |
| `shell` | presentation-only | pronto | nav via `/me` | módulos nunca hardcoded |
| `tracking` | domain/data (dio "bare") | pronto | sim (`/public/track/*`) | sem fake (ok p/ rota pública) |

> **Nota:** memórias antigas marcam `tracking` como "mock/skeleton". **No código atual o tracking está ligado ao backend real** (`/public/track/*` via dio sem interceptor de auth). Divergência de memória, não do código.

**Violação leve (padrão repository):** `front/lib/features/settings/presentation/company_form.dart`
- `:3` `import 'package:dio/dio.dart'` · `:42-49` dio direto → IBGE CNAE (`servicodados.ibge.gov.br/...`) · `:326-372` dio direto → ViaCEP (`viacep.com.br/...`).
- São APIs **externas públicas** (não o backend OrbixHub), mas a UI deveria passar por um repository (ex.: `ExternalLookupsRepository`) em vez de instanciar dio na tela. **Severidade: baixa.**

---

## 4. Diagnóstico de arquitetura (mini-audit)

### 4.1 "Aponta, não invade"
- **Backend: nenhuma violação ativa.** Todo cross-módulo é por **id + service público** (OS→Customers/Inventory/Messages/Iam; Tenancy→Billing; Settings→Tenancy/Billing; Report→Os/Inventory/Customers/Employees/Billing).
- **Histórico:** 3 violações do `SettingsRepository` (`settings.repository.ts:13-34`, lendo/escrevendo `tenant`/`tenant_module`/`module`) — **corrigidas em 2026-06-08 e verificadas agora** (repositório removido; `settings.service.ts` usa `TenancyService`+`BillingService`).
- **Observação menor (não é violação):** `PermissionsGuard` e `os.service.ts` consultam `role`/`role_permission`/`permission` via `getClient()`. São tabelas **globais sem `tenant_id`** (catálogo de RBAC), logo RLS não as filtra e não há vazamento — apenas seria mais limpo usar `this.prisma` direto. Sem ação obrigatória.

### 4.2 Isolamento multi-tenant
- **Todas** as tabelas de dados de tenant têm **RLS + FORCE + policy `tenant_isolation` (`tenant_id = current_tenant_id()`)**: `membership`, `invite`, `subscription`, `tenant_module`, `audit_log`, `customer`, `subject`, `inventory_item`, `stock_movement`, `service_order(+_item/_event/_photo/_template/_template_item)`, `conversation`, `message`, `notification`. ✅
- **Globais (sem RLS, por design):** `tenant`, `users`, `role`, `permission`, `role_permission`, `refresh_token`, `one_time_token`, `login_attempt`, `module`, `plan`, `plan_module`, `billing_webhook_event`, `catalog_product`. Coerente (identidade/catálogo cross-tenant).
- **`tenant_id` sempre do JWT/CLS** (`TenantInterceptor` lê de `req.user.tenantId` setado pelo `JwtAuthGuard`); `withTenantTx`/`runWithTenant` fazem `SET LOCAL app.current_tenant_id` via `$executeRaw` parametrizado. **Nenhum** `tenant_id` vindo de body/query.
- **App conecta como `app_user` (NOBYPASSRLS)**; migrations `app_migrator` (BYPASSRLS); DDL `app_owner`. Fluxos públicos via SECURITY DEFINER (`auth_find_user_memberships`, `auth_find_invite_by_hash`, `auth_membership_active`, `billing_resolve_tenant_by_subscription`, `billing_find_expired_trials`, `os_resolve_by_public_token`).

### 4.3 Vazamento de vertical
- Módulos genéricos **não** vazam termos de oficina no runtime: `customers`/`inventory`/`os` usam `subject`+`attributes`+`itemFields`+label por config. "Placa"/"veículo" aparecem só em **comentários/defaults de exemplo** e em telas **da OS** (módulo-específico, aceitável). Permissões são genéricas (`customer.*`, `subject.*`, `os.*`, `inventory.*`, `report.read`…).

### 4.4 Segurança
- **Segredos:** só via env (Zod `env.schema.ts`): `JWT_ACCESS_SECRET` (≥32), `BILLING_WEBHOOK_SECRET` (≥16; default só em dev), `COSMOS_TOKEN`, `S3_*`. Nenhum segredo no código.
- **Chamada externa em transação:** **nenhuma** — FIPE/Cosmos/OpenFoodFacts e `createCheckout` do gateway rodam **fora** de tx; resultados cacheados.
- **SQL:** ORM/Prisma parametrizado; `inventory.repository.ts` usa `Prisma.sql` (template parametrizado) p/ agregação de valor de estoque. Sem concatenação.
- **Dev-tools:** `devtools` gated por `DEV_TOOLS_ENABLED`; `DevMailerService`/dev-inbox idem. Front usa `--dart-define=DEV_TOOLS`. Ausentes em prod.
- **Sem hard delete:** `status='disabled'/'archived'/'deleted'`, `canceled_at`, `deleted_at`, `access_expires_at`.
- **Mutações sensíveis:** `@Permissions` + `AuditService.log` + reauth (IAM).

### 4.5 Consistência docs × código
| Divergência | Detalhe |
|---|---|
| **Skill `orbixhub-arquitetura` "Estado atual"** | Lista 6 módulos; o real são 13. **Atualizar.** |
| **Memória "tracking = mock"** | Código tem tracking ligado ao backend real (`/public/track/*`). |
| `docs/modulos-v1.md` | **Alinhado** (os/report já como implementados; cashier/invoice/finance planejados). |
| `docs/configuracao.md` | **Alinhado** (seções customers/inventory/invoice-planejado). |
| `docs/audit-arquitetura.md` | **Alinhado** e confirmado (violações fechadas). |
| Seed no `auth-multitenant-schema.sql` (linhas 245-280) | Bloco "0000" semeia só roles `owner`/`mechanic` e perms básicas; cargos `gerente`/`caixa` e perms genéricas vêm no bloco "0003" (linhas 364-407) do **mesmo arquivo idempotente**. Consistente, mas o leitor precisa ler o arquivo inteiro. |

---

## 5. Mapa de dependências

```
                         ┌─────────────┐
                         │   billing   │ (entitlements, ModuleAccessGuard)
                         └──────┬──────┘
        ┌───────────────┬───────┼───────────────┬──────────────┐
        │               │       │               │              │
     auth ──trial──►    tenancy │   settings ───┘ (Tenancy+Billing)
   (BillingService)   (Billing) │
                                 │
   iam ◄── resolveMemberName ── os ──► customers (SubjectHistory seam, getCustomer/Subject)
                                 ├────► inventory (getItem, reconcileConsumption)
                                 ├────► messages (createConversation)  ──► notifications
                                 └────► realtime (via OsPublicService / MessagesService)

   report ──► os(metrics) · inventory(metrics) · customers(metrics) · iam(employees) · billing(enabled)
```

- **Quem aponta pra quem (sempre por id + service público):** `auth→billing`; `tenancy→billing`; `settings→{tenancy,billing}`; `os→{customers,inventory,messages,iam}`; `messages→notifications`; `realtime→{os-public,messages}`; `report→{os,inventory,customers,iam,billing}`.
- **Sem ciclos.** O `os` é o hub operacional; o `report` é o agregador de leitura.

### Existe × falta (vs `docs/modulos-v1.md`)
| Módulo | Plano (doc) | Realidade no código |
|---|---|---|
| auth/iam/tenancy/billing/settings | núcleo/host | ✅ pronto |
| `customers` | impl. | ✅ pronto |
| `inventory` | impl. | ✅ pronto |
| `os` | contratável | ✅ **pronto** (doc já reflete) |
| `report` | impl. (backend) | ✅ pronto (back + front + export) |
| `messages`/`notifications`/`realtime` | (não listados como "módulo") | ✅ prontos (utilitários genéricos) |
| `tracking` | planejado | **servido pelo `os`** (public controller) + front pronto; não é um `module` de billing separado |
| `cashier` | planejado | ❌ só permissões semeadas (`cashier.*`) |
| `invoice` | planejado | ❌ só permissão (`invoice.issue`) + fronteira de config documentada |
| `finance` | planejado | ❌ só permissões (`finance.*`) |

---

## 6. Recomendação — próximo módulo

**Recomendado: `cashier` (Caixa).** Justificativa:

1. **Dependência já satisfeita.** O `cashier` consome o **total/itens da OS** — e a OS está **pronta**, expondo `OsService`/`OsMetricsService` por id+service público. Construir caixa agora é "apontar" para algo que já existe, sem novas fundações.
2. **Fecha o ciclo de valor.** Hoje a OS calcula `total`/`discount` mas **não há recebimento**. Caixa transforma "OS concluída" em "dinheiro recebido" — é o elo que falta entre **OS → relatórios financeiros**.
3. **Pré-requisito de `finance`.** Financeiro (fluxo de caixa, contas a pagar/receber) depende de uma fonte de lançamentos; o caixa é essa fonte. Fazer `finance` antes seria construir relatório sem dado.
4. **Permissões e seeds já existem** (`cashier.read`/`cashier.write`, cargo `caixa`), reduzindo atrito de fundação.
5. **Diferencial percebido:** "abrir/fechar caixa do dia" é dor concreta de oficina pequena e gera retenção.

**Sequência sugerida:** `cashier` → `finance` (consome lançamentos do caixa) → `invoice/fiscal` (já em andamento pela equipe; aponta para `tenant.settings` fiscais + itens da OS). **Agenda** é ortogonal e pode correr em paralelo (aponta para `os.scheduled_start/end` + `customers`).

> **Atenção de plataforma antes do paywall:** quando `cashier`/`finance` virarem "pro", considerar a camada de **entitlements por feature** (`plan_feature`/`features[]` em `/me`) descrita em `docs/pendencias.md` — hoje o gating é por **módulo inteiro**.

---

## 7. Itens acionáveis (priorizados)

| # | Severidade | Item | Onde | Status |
|---|---|---|---|---|
| 1 | Baixa | UI chamava dio direto para IBGE/ViaCEP — movido para `ExternalLookupsRepository` (interface no domain + impl dio + provider no `di.dart`); `flutter analyze` limpo | `front/.../settings/{domain/external_lookups_repository.dart,data/external_lookups_repository_impl.dart,presentation/company_form.dart}` | ✅ **Corrigido (2026-06-27)** |
| 2 | Baixa (dívida) | `messages` reusa permissões `os.*` — migrar para `messages.*` (criar perms + seed nos 3 lugares + remapear cargos) | `messages.service.ts` (TODO no código) | ⏳ Pendente (merece spec próprio — migration aditiva) |
| 3 | Doc | Atualizar "Estado atual" da skill (6 → 13 módulos) | `.claude/skills/orbixhub-arquitetura/SKILL.md` | ✅ **Corrigido (2026-06-27)** |
| 4 | Doc | Corrigir memória "tracking = mock" (está real) | memória `flutter-app-status` | ✅ **Corrigido (2026-06-27)** |
| 5 | Limpeza (opcional) | `PermissionsGuard`/`os.service.ts` usar `this.prisma` em vez de `getClient()` p/ tabelas globais de RBAC | `common/auth/permissions.guard.ts`, `os.service.ts` | ⏳ Opcional (sem impacto de segurança) |
| 6 | Limpeza | `service_order.stock_applied` deprecado (substituído por `stock_movement`) — remover quando seguro | `service_order` + `os.service.ts` | ⏳ Pendente |

---

### Critérios de aceite — checagem
1. ✅ Todos os módulos (13 back + 13 front) com estado real.
2. ✅ Violações com arquivo:linha (1 leve no front; 0 ativas no back; históricas referenciadas).
3. ✅ Mapa de dependências + recomendação justificada (`cashier`).
4. ✅ Divergências docs×código apontadas (skill desatualizada; memória tracking).
5. ✅ Nenhum código de feature alterado (só criado este `docs/assessment.md`).
