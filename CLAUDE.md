# OrbixHub — Guia do Projeto (para agentes e humanos)

> Este arquivo é a fonte de verdade sobre **o que é o OrbixHub**, como ele está
> organizado e **como executar tarefas nele**. Agentes: leiam isto antes de
> mexer no código. Detalhes de setup/endpoints do backend estão no
> [`README.md`](./README.md); designs aprovados estão em `docs/superpowers/specs/`.

> **Skill obrigatória:** antes de construir/alterar qualquer coisa (módulo, endpoint,
> tela, migration, plano, refactor), carregue a skill **`orbixhub-arquitetura`**
> (`.claude/skills/orbixhub-arquitetura/SKILL.md`). Ela codifica as regras de ouro, o
> inventário real (módulos/cargos/planos) e o playbook de módulo novo. Regras-mãe em
> uma linha:
> 1. **Módulos independentes — "aponta, não invade":** guarde só o *id* de entidades
>    de outro módulo e busque via *service público*; **nunca** leia/escreva a *tabela*
>    alheia. 2. Multi-tenant via **RLS** (`tenant_id` do JWT, `withTenantTx`). 3. Migrations
>    **aditivas** nos 3 lugares. 4. Genérico, sem casca de vertical vazando. 5. Planos/módulos
>    **nunca** hardcoded no front (vêm de `/me` + `/billing/plans`). 6. **Sem hard delete**.
>    7. Mutações sensíveis: `@Permissions` + auditadas. 8. Front: UI só via repository.

---

## 1. O que é o OrbixHub

**SaaS de gestão multi-tenant e modular**, pensado para atender **vários tipos de
empresa**. O primeiro vertical é **oficina mecânica**, mas a arquitetura é
deliberadamente genérica: cada cliente (tenant) habilita os **módulos** que
precisa, e a régua do que ele vê é definida pelo **plano** que assina.

**Objetivo de produto:** uma única plataforma onde cada empresa tem seu espaço
isolado, seus usuários com papéis, e um conjunto de **módulos de produto**
(ordens de serviço, clientes, estoque, caixa, fiscal, …) que podem ser ligados
ou desligados por plano/assinatura. Começa em oficinas; a mesma base serve
outros verticais trocando/adicionando módulos — **nada do core é específico de
oficina**.

Três pilares:
1. **Multiempresa (multi-tenant) com isolamento real** — via Postgres Row-Level
   Security (RLS), não apenas filtro de aplicação.
2. **Identidade & acesso** — autenticação, papéis (roles) e permissões por tenant.
3. **Modularidade comercial** — planos → módulos habilitados (entitlements);
   billing/assinatura controla o que cada tenant pode usar.

---

## 2. Monorepo — estrutura de pastas

```
OrbixHub/
├─ back/                # API NestJS (TypeScript) — identidade, tenancy, IAM, billing
│  ├─ src/
│  │  ├─ main.ts        # bootstrap (prefixo global /api, CORS, rawBody p/ webhook)
│  │  ├─ app.module.ts  # composição dos módulos
│  │  ├─ modules/       # domínios de negócio (ver §3)
│  │  │  ├─ auth/       # registro, login, refresh, verify, reset, switch-tenant
│  │  │  ├─ iam/        # membros, papéis, permissões, convites
│  │  │  ├─ tenancy/    # GET /me (dirige a UI)
│  │  │  └─ billing/    # assinaturas, planos→módulos, webhook, job de trial
│  │  └─ common/        # infra transversal (ver §3)
│  ├─ sql/auth-multitenant-schema.sql   # SCHEMA CANÔNICO (idempotente): roles, tabelas, RLS, funções, seeds
│  ├─ prisma/           # schema.prisma (mapeado à mão) + migrations/ (SQL cru)
│  ├─ scripts/ci-db-setup.ts            # aplica o schema canônico como app_owner
│  └─ test/             # e2e (jest + supertest + testcontainers)
├─ front/               # App Flutter (web/Windows; iOS/Android quando houver SDK)
│  └─ lib/              # ver §4
├─ docs/superpowers/specs/              # designs aprovados (auth, billing, flutter)
├─ README.md            # setup detalhado do backend + endpoints + testes de aceite
└─ CLAUDE.md            # este guia
```

Monorepo gerenciado por **npm workspaces** (não pnpm). DB/cache locais sob
**Podman** (não Docker).

---

## 3. Backend (`back/`) — NestJS

### Módulos de negócio (`src/modules`)
- **`auth`** — identidade: `register` (cria tenant + owner + membership + trial,
  atômico), `verify-email`, `login` (genérico/anti-enumeração + rate-limit),
  `refresh` (rotativo, reuso fora da janela revoga a família), `logout`,
  `forgot/reset-password`, `switch-tenant`. JWT de acesso 15min
  (`{ sub, tid, role, jti }`), refresh opaco 14 dias.
- **`iam`** — gestão de acesso: membros, papéis (roles), permissões, convites.
- **`tenancy`** — `GET /me`: usuário, tenant ativo, papel, **permissions[]**,
  **modules[]**, memberships. **Esse endpoint é a fonte de verdade que dirige a UI.**
- **`billing`** — modularidade comercial:
  - planos (`GET /billing/plans`) e assinatura (`GET/POST /billing/...`);
  - **`reconcileTenantModules`**: ao assinar/trocar plano, recalcula os módulos
    habilitados do tenant (módulos do plano ∪ `is_core`; addons/manual preservados);
  - **`ModuleAccessGuard` + `@RequiresModule('chave')`**: protege rotas de módulos
    de produto (past_due libera leitura e bloqueia escrita; canceled bloqueia tudo;
    `is_core` ignora o flag enabled mas respeita o status);
  - **webhook** de pagamento (assinatura HMAC obrigatória + idempotência);
  - **job diário** de expiração de trial; gateway de pagamento abstrato (hoje Noop).

### Infra transversal (`src/common`)
`audit` (log de mudanças), `auth` (guards/decorators JWT + `@Permissions`),
`config` (validação de env com Zod), `crypto`, `database` (Prisma + `TenantContext`),
`filters` (formato de erro `{ statusCode, error, message }`), `jobs` (@nestjs/schedule),
`mailer`, `observability` (`/health`), `redis`, `tenant` (CLS), `throttler` (rate-limit).

### Multi-tenancy / RLS (não-negociável)
- O `tid` do JWT verificado vai pro **CLS** por request; todo acesso a tabela
  tenant-scoped roda numa transação curta que começa com
  `SET LOCAL app.current_tenant_id`.
- A app conecta como **`app_user`** (NOBYPASSRLS → RLS é aplicada de fato).
- Migrations rodam como **`app_migrator`** (BYPASSRLS). DDL/baseline aplicado como
  **`app_owner`** (dono das tabelas).
- Fluxos públicos sem JWT (webhook, tracking) resolvem o tenant no servidor via
  funções `SECURITY DEFINER` — nunca confiando em input do cliente.

### Banco
- **Schema canônico = `back/sql/auth-multitenant-schema.sql`** (idempotente): cria
  roles, tabelas, políticas RLS, funções e **seeds** (módulos `os`/`customers`/
  `inventory`; planos `trial`/`pro`; `plan_module`). É aplicado por
  `scripts/ci-db-setup.ts` como `app_owner` — **NÃO** use `prisma migrate deploy`
  pra subir o schema local.
- `prisma/schema.prisma` é mantido **à mão** em paralelo (Prisma é client/tipos, não
  o dono das migrations). Migrations em `prisma/migrations/*/migration.sql` são SQL
  cru e **aditivas**.

---

## 4. Frontend (`front/`) — Flutter

App Flutter (web/Windows agora) que consome a API real. **Escopo atual:** auth +
multiempresa + casca (shell) navegável gated por papel/módulo + tela de planos +
esqueleto público de acompanhamento. **Fora de escopo:** telas dos módulos de
produto (OS, estoque, …) — só placeholders.

### Stack
Riverpod 3 (estado/DI, sem codegen) · go_router 17 (navegação + deep link) ·
dio 5 (HTTP) · freezed 3 + json_serializable (models imutáveis + unions selados) ·
flutter_secure_storage (refresh token) · google_fonts (Sora + Manrope).

### Arquitetura — feature-first em camadas
`presentation` (telas + Notifiers) → `domain` (entidades + **interface** do
repository) → `data` (impl dio + **impl fake** + dtos). **Regra dura: a UI nunca
chama dio direto — sempre via repository.** Repositórios têm interface no domain,
impl real (dio) e fake; troca por injeção Riverpod.

```
front/lib/
├─ main.dart            # ProviderScope + MaterialApp.router
├─ di.dart              # composition root: TODOS os providers (stores, dio+interceptor, repos, sessão)
├─ core/
│  ├─ config/           # AppConfig — base URL via --dart-define
│  ├─ network/          # dio, bearer em memória, refresh single-flight no 401, mapeamento de erro
│  ├─ router/           # go_router: redirect ligado à sessão, rota pública /t/:token, gating por módulo
│  ├─ storage/          # SecureTokenStore (só o refresh token)
│  ├─ theme/            # AppColors + AppTheme (grafite + tangerina; Sora/Manrope)
│  ├─ widgets/          # BrandMark, BrandPanel, SplashScreen
│  └─ error/            # AppException (mapeia o erro do backend)
└─ features/
   ├─ auth/             # login/register/verify/forgot/reset/picker + SessionController (dirige a UI via /me)
   ├─ billing/          # planos dinâmicos (/billing/plans) + status da assinatura
   ├─ shell/            # AppShell (sidebar/drawer responsivo) + dashboard + nav gated (gatedNavItems)
   └─ tracking/         # /t/:token público (mock — sem endpoint real ainda)
```

### Mecanismos-chave
- **Sessão**: `SessionController` (Riverpod `Notifier<SessionState>`); estado selado
  `loading/authenticated/unauthenticated/error`. Após login/refresh/switch-tenant
  busca `/me` e popula. Router/guards/menu leem daqui.
- **Refresh single-flight**: no 401, **uma** chamada de `/auth/refresh`; requests
  concorrentes esperam o mesmo resultado e refazem a original. Falhou → limpa
  sessão → `/login`.
- **Segurança no cliente**: access token **só em memória**; refresh token **só no
  secure storage**; nunca persista o access.
- **Navegação gated**: `gatedNavItems(me)` (função pura, testada) decide o menu por
  papel+módulo; o router **também guarda** as rotas. Esconder ≠ proteger — o backend
  é a verdade; 403 é tratado com elegância.

### Design system
Direção B2B "warm-industrial": canvas claro, **sidebar grafite**, acento
**tangerina Orbix**, tipografia **Sora** (títulos) + **Manrope** (corpo). Tokens em
`core/theme/app_colors.dart`; tema em `app_theme.dart`. Responsivo (sidebar fixo
≥1000px, drawer abaixo). O shell é dono da "moldura"; telas de conteúdo só devolvem
o corpo.

---

## 5. Como rodar

### Backend (porta 3000 por padrão)
Ver [`README.md`](./README.md) §1–5 (Podman, schema, `.env`, `npm run back:dev`).
Resumo:
```bash
podman start orbix-postgres orbix-redis      # PG em :55432, Redis em :6379
npm install                                   # raiz (workspaces)
# aplica o schema canônico (idempotente) como app_owner — ver README §3
npm run back:dev                              # → http://localhost:3000/api
```

### Frontend (web no Chrome)
```bash
cd front
flutter pub get
dart run build_runner build                   # gera *.freezed.dart / *.g.dart
flutter run -d chrome --web-port 8090 \
  --dart-define=API_BASE_URL=http://localhost:3000/api
```
`http://localhost:8090` precisa estar em `CORS_ORIGINS` do backend.

---

## 6. Como testar / verificar (evidência antes de afirmar "pronto")

**Backend:**
```bash
npm run back:test           # unit (jest)
npm run back:lint           # 0 warnings
npm run back:test:e2e       # e2e — FLUSHALL no redis antes (ver README §6)
```
**Frontend (`cd front`):**
```bash
flutter analyze             # deve dar "No issues found!"
flutter test                # unit/widget
```
Nunca diga que algo passa sem rodar e ver o output.

---

## 7. Regras de ouro (LEIA antes de codar)

1. **Não recrie a fundação.** Auth/IAM/tenancy/RLS e billing já existem. Construa
   em cima; não duplique.
2. **Multi-tenant via RLS, sempre.** Nada de "filtrar por tenant na query" como
   substituto de RLS. Acesso tenant-scoped passa pelo `TenantContext`.
3. **Migrations são ADITIVAS** e refletidas em 3 lugares mantidos juntos:
   `sql/auth-multitenant-schema.sql` (canônico/idempotente), `prisma/migrations/…`,
   e `prisma/schema.prisma`. Não quebre o baseline.
4. **Planos e módulos NUNCA são hardcoded no front.** Tudo vem de `/me` e
   `/billing/plans` em runtime.
5. **Mutações sensíveis são owner-only** (`@Permissions('billing.manage')` etc.) e
   **auditadas** (`audit.log`).
6. **Webhook**: verificação de assinatura é obrigatória; idempotência por
   `external_event_id`. Nunca chame gateway de pagamento dentro de transação de DB.
7. **Segredos só via env** (validados por Zod em `common/config`). Nada no código.
8. **No front: UI só fala com repository** (interface no domain). Models imutáveis
   (freezed). Estados de tela como unions selados.
9. **Strings de usuário em PT-BR**; comentários técnicos podem ser em inglês
   (siga o padrão do arquivo vizinho).
10. **Qualidade**: backend lint 0 warnings; front `flutter analyze` 0 issues.
    Cubra com testes o que tem lógica (e rode-os).

---

## 8. Playbooks (como executar tarefas comuns)

- **Novo módulo de produto (ex.: `caixa`)** — backend: adicione o módulo no seed
  (`module`), inclua-o no(s) plano(s) via `plan_module`, e proteja as rotas com
  `@RequiresModule('caixa')` + `ModuleAccessGuard`. Front: ele aparece sozinho no
  menu (vem de `me.modules`); o label/ícone fica em `shell/presentation/nav_items.dart`.
- **Novo endpoint backend** — crie no módulo certo (controller fino → service →
  repository); respeite RLS/`TenantContext`; permissões via `@Permissions`; erros
  no formato padrão; cubra com unit + e2e.
- **Nova tela Flutter** — feature-first: `domain` (modelos freezed + interface do
  repo), `data` (impl dio + fake), `presentation` (tela + Notifier). Registre
  providers em `di.dart` e a rota em `core/router/app_router.dart`.
- **Novo plano** — adicione no seed (`plan` + `plan_module`); o front renderiza
  automático (sem hardcode).
- **Mudança de schema** — escreva SQL aditivo no baseline canônico E numa migration;
  atualize `schema.prisma`; rode `prisma:generate`.

---

## 9. Ambiente local (ESTA máquina — Windows)

- **Postgres** sob Podman na porta **55432** (a 5432 é de um PG nativo).
  Redis em 6379. Containers: `orbix-postgres`, `orbix-redis`.
- **Flutter SDK** em `C:\Users\KaueSobral\develop\flutter` e **não está no PATH** —
  invoque por caminho completo (`...\flutter\bin\flutter.bat`). Sem Android SDK:
  verifique por **web (Chrome)** + `flutter test`.
- **Atenção à porta 3000**: o VS Code desta máquina faz **port-forward de
  `localhost:3000` para um ambiente remoto (SysOne)**. Para testar o backend local
  no navegador, rode o Nest numa porta alternativa (ex.: `PORT=4400`) e aponte o
  Flutter com `--dart-define=API_BASE_URL=http://localhost:4400/api` (some 4400 ao
  `CORS_ORIGINS`). Nunca mate processo por porta sem checar a identidade antes.
- Conta de teste semeada em dev: `dono@teste.com` / `senha12345` (owner, trial).

---

## 10. Convenções de trabalho

- **Branches**: trabalhe em `feat/...` (ex.: `feat/flutter-app`). Não commite direto
  na `main`/`master` sem pedir.
- **Commits**: mensagem clara no escopo (`feat(billing): …`, `fix(front): …`).
- **Antes de "pronto"**: rode lint/analyze + testes e cite o resultado real.
- **Ponteiros**: setup detalhado → `README.md`; designs → `docs/superpowers/specs/`.
