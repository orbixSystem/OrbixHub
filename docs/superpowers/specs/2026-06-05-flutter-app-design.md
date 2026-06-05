# OrbixHub — App Flutter (Agente C) — Design Validado

**Data:** 2026-06-05
**Branch:** `feat/flutter-app`
**Depende de:** API entregue por Agente A (identidade) + Agente B (billing/módulos), já integrada no `back/` (branch `master`).

## Objetivo

App Flutter (web/Windows agora; iOS/Android quando houver Android SDK) que entrega
**apenas**: autenticação + multiempresa + casca navegável gated por papel e módulo
+ tela de planos/assinatura + esqueleto do acompanhamento público. Telas de módulo
de produto (OS, estoque, caixa, fiscal) estão **fora de escopo**.

Consome o **backend real** rodando em `http://localhost:3000/api`.

## Contrato do backend (auditado em 2026-06-05 — bate 100%)

Prefixo global `/api`. Erros no formato `{ statusCode, error, message }`, mensagens
de auth genéricas (anti-enumeração).

| Fluxo | Endpoint | Resposta (campos relevantes) |
|---|---|---|
| Login | `POST /auth/login` | `{ accessToken, refreshToken, user{id,email,fullName}, memberships[{tenantId,tenantSlug,role}] }` |
| Cadastro | `POST /auth/register` | `{ accessToken, refreshToken, user, tenant{id,slug,name} }` (cria trial) |
| Verificar e-mail | `POST /auth/verify-email` | `{ verified: true }` |
| Esqueci senha | `POST /auth/forgot-password` | `{ ok: true }` (sempre 200) |
| Redefinir senha | `POST /auth/reset-password` | `{ ok: true }` |
| Trocar oficina | `POST /auth/switch-tenant` `{tenantId}` | `{ accessToken, refreshToken }` |
| Refresh | `POST /auth/refresh` `{refreshToken}` | `{ accessToken, refreshToken }` (rotativo, tolerância ~10s) |
| Logout | `POST /auth/logout` `{refreshToken}` | 204 |
| Sessão | `GET /me` | `{ user, activeTenant{id,slug,name}, role, permissions[], modules[], memberships[] }` |
| Planos | `GET /billing/plans` | `[{ key, name, billingPeriod, modules[] }]` |
| Assinatura | `GET /billing/subscription` | `{ planKey, status, currentPeriodStart, currentPeriodEnd } \| null` |
| Assinar/trocar (dono) | `POST /billing/{subscribe,change-plan}` `{planKey}` | `SubscriptionView` |

**JWT de acesso** (15min) claims `{ sub, tid, role, jti }`; refresh opaco (14d).
**Tracking público: não existe endpoint** — tela `/t/:token` é esqueleto/mock
(o spec original já prevê isso). IAM (`/iam/*`, convites) existe no backend mas
está **fora de escopo** desta rodada.

## Stack

Flutter 3.44 / Dart 3.12. **Riverpod** (estado + DI), **go_router** (navegação +
deep link), **dio** (HTTP), **freezed** + **json_serializable** (models imutáveis +
unions selados), **flutter_secure_storage** (refresh token). Sem GetX.

## Arquitetura — feature-first, em camadas

`presentation` (telas + Notifiers Riverpod) → `domain` (entidades + interface do
repository) → `data` (impl dio + impl fake + dtos). Regras invioláveis:
- A UI **nunca** chama dio direto; sempre via repository (interface no domain).
- Models imutáveis (freezed); estados de tela como **unions selados**.
- Cada repository tem **interface no domain**, **impl real (dio)** e **impl fake**
  (espelha o contrato) no data — troca por injeção Riverpod (real em runtime, fake
  nos testes).

## Estrutura de `front/lib/`

```
main.dart
core/
  config/      AppConfig — API base URL via --dart-define (default http://localhost:3000/api)
  network/     dioProvider + interceptors: Bearer (access em memória), refresh single-flight, error-mapper
  router/      appRouter (go_router) — redirect ligado à sessão + rota pública /t/:token
  storage/     SecureTokenStore (flutter_secure_storage) — só o refresh token
  error/       AppException (mapeia {statusCode,error,message} p/ tipo de domínio)
  theme/       AppTheme
features/
  auth/
    domain/      User, Membership, Tokens, Me, AuthRepository (interface)
    data/        AuthApi (dio) + AuthRepositoryImpl + FakeAuthRepository + dtos
    presentation/ login, register, verify, forgot, reset, tenant_picker + SessionNotifier
  billing/
    domain/      Plan, Subscription, BillingRepository (interface)
    data/        BillingApi + BillingRepositoryImpl + FakeBillingRepository + dtos
    presentation/ plans_screen (renderiza /billing/plans dinâmico) + subscription status
  tracking/
    domain/      TrackingStatus, TrackingRepository (interface)
    data/        FakeTrackingRepository (mock — sem endpoint real ainda)
    presentation/ public_tracking_screen (/t/:token, sem auth)
  shell/
    presentation/ app_shell — navegação gated por role + modules (lê do /me)
```

## Mecanismos-chave (os que ganham teste)

1. **SessionNotifier** (Riverpod `AsyncNotifier`/`Notifier`): segura
   `user / activeTenant / role / permissions[] / modules[]` (do `/me`). Estado
   selado (freezed union): `loading / authenticated / unauthenticated / error`.
   Router, guards e menu leem daqui. Após login/refresh/switch-tenant → busca `/me`
   e popula.

2. **Refresh single-flight no 401** (`core/network`): interceptor onError(401)
   dispara **uma** chamada de `/auth/refresh`; requests concorrentes que tomaram
   401 **aguardam a mesma `Future`** (não disparam refresh próprio), depois refazem
   a request original com o novo access token. Refresh falhou (401) → limpa sessão
   → redireciona `/login`. Casa com a janela de tolerância ~10s do backend.

3. **Boot silencioso** (`main`/`SessionNotifier.bootstrap`): no start, se há refresh
   token no secure storage → tenta refresh → busca `/me` → decide rota. Access token
   **nunca** persiste — só em memória (um provider).

4. **Navegação gated por papel + módulo** (`shell` + `router`): itens de menu somem
   conforme `role` / `modules`; **rotas são guardadas** (redirect se faltar
   permissão/módulo). Backend é a verdade; `403` → UI trata com elegância
   (mensagem + volta).

5. **Planos dinâmicos** (`billing`): zero hardcode de nome de plano/módulo — render
   a partir de `/billing/plans` e `/me`. Status de `/billing/subscription` com aviso
   quando `past_due`.

## Segurança no cliente

- Refresh token **só** em `flutter_secure_storage`; access token **só** em memória.
- Single-flight no refresh (uma chamada por vez).
- Logout: revoga no backend (`/auth/logout`) + apaga secure storage + zera sessão.
- Sem segredos no código; base URL via `--dart-define`.
- Valida formato do deep-link token antes de chamar a API.

## Bring-up do backend real (pré-requisito pra rodar web)

1. Podman: `orbix-postgres` (postgres:16) `-p 55432:5432`, env
   `app_owner/owner_pw/orbixhub` + `orbix-redis` (redis:7) `-p 6379:6379`.
2. Aplicar `back/sql/auth-multitenant-schema.sql` como `app_owner` (idempotente;
   cria roles app_user/app_migrator, tabelas, RLS, funções e **semeia** módulos +
   planos trial/pro).
3. `npm run start:dev` no `back/` (env do `back/.env`, porta 3000).
4. `CORS_ORIGINS` já inclui `http://localhost:8080` → rodar Flutter web nessa porta.

## Verificação (com evidência)

- `flutter test`: unit/widget cobrindo os 7 critérios — destaque pra **single-flight**
  (N×401 → 1 refresh, demais aguardam) e **secure storage** (access nunca persiste),
  via `FakeAuthRepository`/mock dio.
- `flutter run -d chrome --web-port 8080` contra o backend real: register/login →
  `/me` → casca gated → planos. Screenshot/observação pro usuário.

## Critérios de aceite (do spec original)

1. Login/cadastro/verificação/reset/troca de oficina funcionam contra o contrato.
2. Refresh automático no 401 com single-flight; logout ao falhar refresh.
3. Refresh token só no secure storage; access token nunca persistido.
4. Itens de nav somem por papel+módulo; rota protegida redireciona quando falta.
5. Deep link `/t/:token` abre rota pública **sem login**.
6. Planos renderizados de `/billing/plans` (sem nomes hardcoded).
7. Models/estados imutáveis (freezed); UI só fala com repository.

## Fora de escopo

Telas de módulos de produto (OS/estoque/caixa/fiscal); gestão de membros/convites
(IAM existe no backend mas não nesta rodada); endpoint real de tracking; build
Android/iOS (sem Android SDK na máquina agora).
