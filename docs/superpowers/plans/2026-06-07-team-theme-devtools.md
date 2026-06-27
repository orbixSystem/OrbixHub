# Equipe & Convite + Tema claro/escuro + Painel de Debug — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Sobre a master consolidada (auth/iam + equipe-backend + app Flutter), entregar: (1) tela de Equipe + fluxo de convite no Flutter; (2) tema claro/escuro no app inteiro; (3) painel de debug "besouro" dev-only (+ `GET /dev/inbox` no backend). Branch `feat/team-theme-devtools`.

**Architecture:** Backend em camadas + RLS; Flutter feature-first (Riverpod/go_router/dio/freezed). Migration aditiva `0004` (invite.canceled_at + expires_at nullable). Dev-tools protegidos por env (`DEV_TOOLS_ENABLED` default false → rota não registrada em prod) e por const de compilação no Flutter (`!kReleaseMode` → tree-shaken do release).

**Decisões travadas:** soft-cancel (`canceled_at`); expiração escolhível (15min/30min/1d/15d/sem); `never`→`expires_at` NULL; dev inbox em memória; reenviar = rotaciona token; tema semeado pela `primaryColor` da oficina (de `GET /settings`) com fallback; link de convite montado com `APP_PUBLIC_URL`.

---

## Estrutura de arquivos

**Backend — DB:**
- Modify `back/sql/auth-multitenant-schema.sql` (append 0004 + atualizar a função `auth_find_invite_by_hash`)
- Create `back/prisma/migrations/0004_invite_lifecycle/migration.sql`
- Modify `back/prisma/schema.prisma` (invite.canceled_at; expires_at nullable)
- Modify `back/src/common/config/env.schema.ts` (`DEV_TOOLS_ENABLED`, `APP_PUBLIC_URL`)
- Modify `back/.env` (dev: `DEV_TOOLS_ENABLED=true`, `APP_PUBLIC_URL=http://localhost:8090`)

**Backend — convites (estende iam):**
- Modify `back/src/modules/iam/dto/iam.dto.ts` (expiresIn no CreateInviteDto; ResendInviteDto)
- Modify `back/src/modules/iam/iam.repository.ts` (listPendingInvites, getInvite, rotateInviteToken, cancelInvite, expiresAt helper)
- Modify `back/src/modules/iam/iam.service.ts` (createInvite usa expiresIn; listPendingInvites; resendInvite; cancelInvite; accept rejeita canceled/expired)
- Create `back/src/modules/iam/invites.controller.ts` (GET /invites, POST /invites/:id/resend, DELETE /invites/:id)

**Backend — dev inbox:**
- Create `back/src/modules/devtools/dev-inbox.service.ts` (singleton em memória, último de cada tipo)
- Modify `back/src/common/mailer/dev-mailer.service.ts` (grava no DevInbox além de logar)
- Create `back/src/modules/devtools/dev.controller.ts` (`GET /dev/inbox`)
- Create `back/src/modules/devtools/devtools.module.ts` (registra a controller SÓ se DEV_TOOLS_ENABLED)
- Modify `back/src/app.module.ts` (importa DevtoolsModule)

**Flutter — equipe:**
- `front/lib/features/team/domain/` team_models.dart (Employee, PendingInvite, RoleOption), team_repository.dart
- `front/lib/features/team/data/` team_repository_impl.dart, fake_team_repository.dart
- `front/lib/features/team/presentation/` team_screen.dart, invite_dialog.dart, change_role_dialog.dart, reauth_dialog.dart, team_providers.dart
- `front/lib/features/auth/presentation/accept_invite_screen.dart` (rota pública /convite/:token)

**Flutter — tema:**
- `front/lib/core/theme/app_theme.dart` (add dark) + `front/lib/core/theme/theme_controller.dart` (ThemeMode + persistência) + `front/lib/core/theme/branding.dart` (seed por primaryColor)
- Modify `front/lib/main.dart` (themeMode + darkTheme), `front/lib/di.dart`, `front/lib/core/router/app_router.dart` (rota /convite), `front/lib/features/shell/presentation/nav_items.dart` (item Equipe), `app_shell.dart` (toggle de tema)

**Flutter — debug:**
- `front/lib/core/devtools/dev_flag.dart` (const kDevTools), dev_inbox_repository.dart, dev_inbox_overlay.dart (besouro), dev_inbox_modal.dart
- Modify `front/lib/main.dart` (envolver com o overlay quando kDevTools)

---

## PARTE 0 — DB + env

### Task 1: Migration 0004 (invite lifecycle) + função + env

**Files:** os 3 lugares de schema + env.schema + .env

- [ ] **Step 1: DDL aditiva** (append no baseline + arquivo de migration):
```sql
-- 0004 — invite lifecycle (soft-cancel + expiração opcional)
ALTER TABLE invite ADD COLUMN IF NOT EXISTS canceled_at timestamptz;
ALTER TABLE invite ALTER COLUMN expires_at DROP NOT NULL;  -- NULL = sem expiração

-- a função de lookup precisa expor canceled_at (e expires_at agora pode ser NULL).
-- RETURNS TABLE muda de assinatura → DROP + CREATE.
DROP FUNCTION IF EXISTS auth_find_invite_by_hash(text);
CREATE FUNCTION auth_find_invite_by_hash(p_hash text)
RETURNS TABLE (invite_id uuid, tenant_id uuid, email_normalized text,
               role_id uuid, expires_at timestamptz, accepted_at timestamptz,
               canceled_at timestamptz)
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT id, tenant_id, email_normalized, role_id, expires_at, accepted_at, canceled_at
  FROM invite WHERE token_hash = p_hash
$$;
REVOKE ALL ON FUNCTION auth_find_invite_by_hash(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth_find_invite_by_hash(text) TO app_user;
```
> IMPORTANTE: leia o bloco atual de `auth_find_invite_by_hash` em `auth-multitenant-schema.sql` e replique exatamente o estilo/grants existentes; só adicione `canceled_at`. No baseline, SUBSTITUA o CREATE FUNCTION antigo (não duplique) — mantenha idempotência (DROP FUNCTION IF EXISTS antes do CREATE).

- [ ] **Step 2: schema.prisma** — no model `invite`: `canceled_at DateTime?` e tornar `expires_at DateTime?` (nullable). Leia o model e mantenha o estilo.

- [ ] **Step 3: env.schema.ts** — adicionar (seguindo o padrão de `BILLING_REQUIRE_PAYMENT`):
```ts
DEV_TOOLS_ENABLED: z.string().default('false').transform((s) => s.toLowerCase() === 'true'),
APP_PUBLIC_URL: z.string().default('http://localhost:8090'),
```

- [ ] **Step 4: back/.env** — adicionar `DEV_TOOLS_ENABLED=true` e `APP_PUBLIC_URL=http://localhost:8090`.

- [ ] **Step 5: aplicar + gerar + verificar idempotência**
```bash
podman exec -i orbix-postgres psql -U app_owner -d orbixhub -v ON_ERROR_STOP=1 < back/prisma/migrations/0004_invite_lifecycle/migration.sql
podman exec -i orbix-postgres psql -U app_owner -d orbixhub -v ON_ERROR_STOP=1 < back/prisma/migrations/0004_invite_lifecycle/migration.sql  # 2x = idempotente
npm run prisma:generate --workspace back
podman exec orbix-postgres psql -U app_owner -d orbixhub -c "\d invite" -c "\df auth_find_invite_by_hash"
```
Expected: `invite` tem `canceled_at` e `expires_at` nullable; a função retorna 7 colunas. Build: `npm run build --workspace back` OK.

- [ ] **Step 6: Commit** — `feat(db): 0004 invite canceled_at + nullable expiry + dev-tools/app-public-url env`

---

## PARTE 1 — Backend de convites (listar/reenviar/cancelar + expiração)

### Task 2: DTOs + expiresIn helper
**Files:** `dto/iam.dto.ts`
- [ ] DTO: adicionar ao `CreateInviteDto` `@IsOptional() @IsIn(['15min','30min','1day','15days','never']) expiresIn?` (default tratado no service = '15days'). Criar `ResendInviteDto { currentPassword; @IsOptional() expiresIn? }` (reauth também). Mapa minutos: `{ '15min':15, '30min':30, '1day':1440, '15days':21600, never:null }`. Commit.

### Task 3: Repository — invite lifecycle
**Files:** `iam.repository.ts`
- [ ] Métodos (todos RLS via `withTenantTx`): `listPendingInvites()` → invites onde `accepted_at IS NULL AND canceled_at IS NULL AND (expires_at IS NULL OR expires_at > now())`, com join role (global) → `{id, email, role, expiresAt, createdAt}`. `getInvite(id)`. `rotateInviteToken(id, tokenHash, expiresAt)` (update). `cancelInvite(id)` (set `canceled_at = now()`). Reaproveitar o padrão de `createInvite` para aceitar `expiresAt: Date | null`. Build + commit.

### Task 4: Service — createInvite(expiresIn) + list/resend/cancel + accept rejeita canceled
**Files:** `iam.service.ts`
- [ ] `createInvite` passa a calcular `expiresAt` a partir de `dto.expiresIn` (default '15days'); demais comportamentos iguais (reauth já existe). `listPendingInvites(tenantId)` → repo. `resendInvite(tenantId, actor, inviteId, dto)` → reauth, rotaciona token (novo `generateOpaqueToken`+hash, novo expiresAt), re-`mailer.send({to: invite.email, token: raw, kind:'invite'})`, audit 'invite' . `cancelInvite(tenantId, actor, inviteId)` → repo.cancelInvite + audit (use action 'invite' ou adicione 'invite_cancel' ao AuditAction). **accept**: além de `accepted_at`/`expires_at`, rejeitar se `canceled_at` setado; e tratar `expires_at` NULL como "nunca expira" (não rejeitar por expiração). Unit test do accept (canceled → 400; expired → 400; null-expiry → não rejeita por isso). Commit.

### Task 5: invites.controller.ts + wiring
**Files:** `invites.controller.ts`, `iam.module.ts`
- [ ] `@Controller()`: `GET /invites` (`@Permissions('users.manage')`) → listPendingInvites; `POST /invites/:id/resend` (`users.manage`, body ResendInviteDto, HttpCode 200); `DELETE /invites/:id` (`users.manage`, HttpCode 200, body ReauthDto → reauth no service? spec não exige reauth p/ cancelar — manter só users.manage; mas resend exige reauth pois reenvia credencial de acesso). Registrar controller no módulo. Build + commit.

---

## PARTE 2 — Dev inbox (backend, dev-only)

### Task 6: DevInboxService (memória) + dev-mailer grava nele
**Files:** `devtools/dev-inbox.service.ts`, `mailer/dev-mailer.service.ts`
- [ ] `DevInboxService` (`@Injectable`, singleton): `Map<kind, {type,label,value,createdAt}>`; `record(kind, value)` (sobrescreve); `list()` → array. Labels PT: invite→"Link de convite", email_verify→"Token de verificação de e-mail", password_reset→"Token de reset de senha". Para `invite`, `value` = `${APP_PUBLIC_URL}/#/convite/${token}` (injeta ENV); para os outros, `value` = token cru.
- [ ] `DevMailerService.send` passa a chamar `this.devInbox.record(kind, ...)` ALÉM do log atual. Injetar DevInboxService + ENV. (Manter o log.) Unit test: enviar 'invite' grava link; reenviar sobrescreve (só o último). Commit.

### Task 7: DevController + DevtoolsModule (gated por env)
**Files:** `devtools/dev.controller.ts`, `devtools/devtools.module.ts`, `app.module.ts`
- [ ] `DevController`: `@Public() @Get('dev/inbox')` → `devInbox.list()` (sem auth — facilita testar fluxos deslogados; a proteção é o env).
- [ ] `DevtoolsModule`: providers `[DevInboxService]`, exports `[DevInboxService]` (o DevMailer precisa). **controllers**: incluir `DevController` **somente se** `process.env.DEV_TOOLS_ENABLED?.toLowerCase()==='true'` (avaliar no `@Module` via spread condicional: `controllers: devEnabled ? [DevController] : []`). Assim a rota **não é registrada** em prod. DevInboxService precisa ser visível ao MailerModule — torne DevtoolsModule `@Global()` ou exporte e importe no MailerModule.
- [ ] e2e (Task 12) prova: com DEV_TOOLS_ENABLED=true → 200; simular off → 404. Build + commit.

---

## PARTE 3 — Flutter: tema claro/escuro

### Task 8: AppTheme.dark + ThemeController (persistido) + branding seed
**Files:** `core/theme/app_theme.dart`, `core/theme/theme_controller.dart`, `core/theme/branding.dart`, `di.dart`, `main.dart`
- [ ] Adicionar `flutter pub add shared_preferences`.
- [ ] `app_theme.dart`: extrair um builder `ThemeData _build(Brightness, Color seed)` e expor `AppTheme.light({Color? seed})` e `AppTheme.dark({Color? seed})` (ColorScheme.fromSeed com brightness; manter Sora/Manrope; cards/inputs/etc. legíveis nos dois). Default seed = AppColors.brand.
- [ ] `ThemeController extends Notifier<ThemeMode>`: `build()` lê de shared_preferences (chave `theme_mode`, default system); `set(ThemeMode)` persiste. Provider em di.dart.
- [ ] `branding.dart`: `brandingSeedProvider` (FutureProvider<Color>) que lê `GET /settings` (via um settings repo simples ou direto no dio) → `company.primaryColor` (hex) → Color; fallback AppColors.brand. (Só quando autenticado; senão fallback.)
- [ ] `main.dart`: `MaterialApp.router(theme: AppTheme.light(seed), darkTheme: AppTheme.dark(seed), themeMode: ref.watch(themeControllerProvider))`, onde seed vem do brandingSeedProvider (`.maybeWhen(data:..., orElse: brand)`). Commit. (Critério 6)

### Task 9: Toggle de tema na UI
**Files:** `app_shell.dart` (e telas de auth se quiser)
- [ ] No sidebar/footer, um controle claro/escuro/sistema (PopupMenu ou SegmentedButton) chamando `themeController.set(...)`. Visível e acessível. Commit.

---

## PARTE 4 — Flutter: Equipe + convite

### Task 10: domain + data (models freezed + repo interface + impl dio + fake)
**Files:** `features/team/domain/*`, `features/team/data/*`
- [ ] Models freezed: `RoleOption{key,name,permissions}`, `Employee{membershipId,userId,fullName,email,role,status,lastAccess}`, `PendingInvite{id,email,role,expiresAt,createdAt}`. `TeamRepository` (interface): `roles()`, `employees()`, `pendingInvites()`, `invite({email,role,expiresIn})`, `resendInvite(id,{expiresIn})`, `cancelInvite(id)`, `changeRole(membershipId, role, currentPassword)`, `deactivate(membershipId, currentPassword)`, `activate(membershipId, currentPassword)`. Impl dio (mapeia erro→AppException) + Fake. Providers no di.dart. Build (`flutter analyze`) + commit. (Critérios 1–4 backend-facing)

### Task 11: telas — lista de equipe + diálogos (convite, trocar cargo, reauth, ativar/desativar) + guardrails na UI
**Files:** `features/team/presentation/*`, `nav_items.dart`, `app_router.dart`
- [ ] `team_providers.dart`: FutureProviders p/ employees, pendingInvites, roles. `team_screen.dart`: duas seções — Funcionários (cards: nome/email/cargo/status/últ35 acesso + menu de ações) e Convites pendentes (email/cargo/etiqueta "pendente" + reenviar/cancelar). `invite_dialog.dart` (email + dropdown cargo de `roles()` + dropdown expiração 15min/30min/1d/15d/sem). `change_role_dialog.dart` (dropdown cargo + campo senha atual). `reauth_dialog.dart` (campo senha, reutilizável p/ activate/deactivate). **Guardrails na UI**: esconder/desabilitar "rebaixar/desativar" do último dono ativo (calcular owners ativos da lista), esconder "alterar próprio cargo" (comparar com `session.me.user.id`), só owner vê opção de atribuir 'owner' (checar `me.role=='owner'`). Erros 403/guardrail → SnackBar amigável. Invalidate providers após mutação.
- [ ] Adicionar item "Equipe" em `gatedNavItems` quando `me.hasPermission('users.manage')` (rota `/equipe`); registrar rota no shell. Build + commit. (Critérios 1–4)

### Task 12: Aceitar convite (rota pública /convite/:token)
**Files:** `features/auth/presentation/accept_invite_screen.dart`, `app_router.dart`
- [ ] Rota pública `/convite/:token` (igual a `/t/:token` no redirect: sem auth). Tela: valida formato do token; form (nome se necessário + senha + confirmar) → `authRepository`/novo método `acceptInvite(token, fullName, password)` (POST /invites/accept) → grava tokens na sessão → `context.go('/')`. Trata 400 "convite inválido/expirado/já usado" com mensagem genérica clara. Adicionar `acceptInvite` ao AuthRepository (interface + impl dio + fake). Build + commit. (Critério 5)

---

## PARTE 5 — Flutter: painel de debug (besouro, dev-only)

### Task 13: gating + repo + overlay + modal
**Files:** `core/devtools/*`, `main.dart`
- [ ] `dev_flag.dart`: `const bool kDevTools = bool.fromEnvironment('DEV_TOOLS', defaultValue: !kReleaseMode);` (release sem o define → false → tree-shaken).
- [ ] `dev_inbox_repository.dart`: `GET /dev/inbox` (dio, base já configurada) → `List<DevInboxEntry{type,label,value,createdAt}>`.
- [ ] `dev_inbox_overlay.dart`: um wrapper que põe um FAB com ícone besouro (`Icons.bug_report`) no **canto superior direito** sobre o `child` (Stack + Positioned), presente em todas as telas. **Só monta o besouro se `kDevTools`** (senão retorna `child` puro → nada compilado no release).
- [ ] `main.dart`: envolver o `MaterialApp.router`'s builder com `DevInboxOverlay` (via `builder:` do MaterialApp para cobrir todas as rotas).
- [ ] `dev_inbox_modal.dart`: bottom sheet — aviso topo "Ferramenta de desenvolvimento — não aparece em produção"; um card por tipo (label + valor monoespaçado selecionável/quebrando linha + botão copiar com feedback "copiado!" via Clipboard + timestamp "gerado há X"); botão atualizar (re-fetch); estado vazio ("nada gerado ainda"); respeita tema. Build + commit. (Critérios 7,8)

---

## PARTE 6 — Testes & gate

### Task 14: e2e backend (convites + dev inbox + prod-gate)
**Files:** `back/test/invites.e2e-spec.ts`, `back/test/devtools.e2e-spec.ts`
- [ ] invites e2e: criar convite com `expiresIn:'15min'` → aparece em `GET /invites`; reenviar (token muda, link antigo morto → accept do antigo 400); cancelar → some de pendentes e accept 400; `expiresIn:'never'` → expires_at null e aceita normalmente; aceitar consome (reuse → 400). Isolamento A↔B.
- [ ] devtools e2e: `GET /dev/inbox` (DEV_TOOLS_ENABLED=true no .env) após gerar um convite → 200 com entry type 'invite' (value contém `/convite/`); reenviar → só o último. **Prod-gate (Critério 9):** subir um segundo Nest app de teste com `DEV_TOOLS_ENABLED` desligado (override via `process.env` no `beforeAll` de um describe separado OU testar a montagem condicional do módulo) → `GET /dev/inbox` retorna **404**. Documentar como o teste força o ambiente off.
- [ ] FLUSHALL + env + `npm run back:test:e2e -- "invites|devtools"` verde. Commit.

### Task 15: testes Flutter (tema persistência + dev flag + guardrail UI util)
**Files:** `front/test/*`
- [ ] Teste do ThemeController (persiste/lê via SharedPreferences.setMockInitialValues). Teste util de guardrail (função pura que decide ações permitidas dado `me` + lista). `flutter test` verde. Commit.

### Task 16: gate final
- [ ] back: idempotência 0004 (2x), lint 0, build, unit, e2e (FLUSHALL+env) — todos verdes.
- [ ] front: `flutter analyze` 0 issues, `flutter test` verde.
- [ ] **Revisão final** (subagente) com foco em: o gate dev-only realmente remove a rota em prod e o besouro do release; reauth nas mutações; guardrails na UI + tratamento de 403; isolamento. Corrigir achados.

---

## Critérios de aceite → Tasks
1. lista funcionários + convites pendentes (reenviar/cancelar) → T3,T5,T10,T11
2. convidar (email+cargo) cria convite, pendente → T4,T5,T11
3. trocar cargo/ativar/desativar com reautenticação; desativar não apaga → T4(accept invariants),T10,T11
4. guardrails na UI (último dono, sem auto-cargo, só owner→owner) + 403 elegante → T11
5. aceitar convite (público) define senha + inicia sessão; uso único; expirado/cancelado rejeitado → T1,T4,T12,T14
6. tema claro/escuro/sistema persistido; todas as telas legíveis; seed pela cor da oficina → T8,T9,T15
7. besouro canto superior direito, todas as telas, só dev → T13
8. modal: último de cada tipo (label+mono+copiar+timestamp), sem histórico, atualizar, vazio → T6,T13
9. **prod: besouro ausente e GET /dev/inbox 404** → T7,T13,T14
10. isolamento de tenant; suíte verde + lint → T14,T16
