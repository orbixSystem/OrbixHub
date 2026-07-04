---
name: orbixhub-frontend-flutter
description: Use when building or changing anything in the OrbixHub Flutter app (front/**) — screens, Notifiers, repositories, routing, session, responsiveness, or the planned offline layer. Encodes the real feature-complete state, the feature-first layering, API integration rules, the mandatory-responsiveness requirement, and the offline plan.
---

# OrbixHub — Frontend Flutter

> Estado real: o app **NÃO** é esqueleto — está **feature-complete** para o núcleo. Features:
> `auth`, `billing`, `os`, `customers`, `inventory`, `messages`, `notifications`, `report`,
> `settings`, `dashboard`, `tracking` (público), `team`, `shell`.
>
> ⚠️ **Bloqueador:** `pubspec.yaml` exige Dart `^3.12.1`; se `flutter pub get` falhar, rode
> `flutter upgrade`. (A feature `invoice` do front ainda não existe — é o próximo passo.)

## Stack real (`front/pubspec.yaml`)

- **flutter_riverpod** 3 — estado/DI (sem codegen).
- **go_router** 17 — navegação + deep link.
- **dio** 5 — HTTP para a API NestJS (`/api`).
- **freezed** 3 + **json_serializable** — models imutáveis + unions selados.
- **flutter_secure_storage** — só o refresh token. **shared_preferences** — prefs não-sensíveis.
- **socket_io_client** — WebSocket (chat/tracking). **audioplayers** — som de notificação.
- **google_fonts** (Sora/Manrope), **fl_chart** (dashboard), **pdf**/**printing**/**csv** (export),
  **file_picker**.

## Arquitetura — feature-first em camadas

`presentation` (telas + Notifiers) → `domain` (entidades freezed + **interface** do repository) →
`data` (impl dio + **impl fake** + dtos). **Regra dura: a UI nunca chama dio direto — sempre via
repository.** Troca de impl por injeção no `di.dart` (composition root de todos os providers).

- `core/`: `network/` (dio + interceptor: bearer em memória, refresh single-flight no 401),
  `router/` (go_router com guards de auth/papel/módulo), `storage/` (SecureTokenStore),
  `theme/` (AppColors grafite+tangerina, AppTheme Sora/Manrope), `realtime/` (`RealtimeChat`
  socket.io), `error/` (AppException), `widgets/`, `config/` (base URL via `--dart-define`).
- Sessão: `SessionController` (`Notifier<SessionState>` selado: loading/authenticated/
  unauthenticated/error). Após login/refresh/switch-tenant busca `/me` e popula.
- Navegação gated: `gatedNavItems(me)` (função pura, testada) decide o menu por papel+módulo; o
  router **também** guarda as rotas. Esconder ≠ proteger — o backend é a verdade; 403 com elegância.
  Label/ícone em `shell/presentation/nav_items.dart`.

## Integração com a API

- Access token (JWT 15m) em `Authorization: Bearer ...`; **só em memória**. Refresh token **só no
  secure storage**. No 401 → **refresh single-flight**; falhou → limpa sessão → `/login`.
- **Nunca** envie `tenantId` manualmente — o servidor deriva do JWT. Troca de oficina via
  `POST /api/auth/switch-tenant`.
- Planos e módulos **nunca** hardcoded — vêm de `/me` e `/billing/plans` em runtime.

## RESPONSIVIDADE — REQUISITO OBRIGATÓRIO (agora)

Toda tela nova ou alterada funciona em **desktop, web e mobile**. Critério de aceite:
- breakpoints (sidebar fixa ≥1000px, drawer abaixo — padrão do `AppShell`);
- tabelas colapsam em cards no mobile; alvos de toque adequados;
- o shell é dono da moldura; telas de conteúdo devolvem só o corpo.

## Offline (planejado para o MVP)

- CRUD básico (clientes, OS, caixa, estoque) offline via **drift** (SQLite) + **outbox**; nova impl
  `LocalFirst` de cada repository (sem mudar telas). Sincroniza ao reconectar (last-write-wins).
- **Bloqueado offline:** chat, link em tempo real e **emissão de NF** (exigem rede) → desabilitar
  com aviso "Requer conexão".
- **Indicador online/offline em tempo real:** `connectivity_plus` + saúde do socket → controller
  Riverpod expõe `online | offline | syncing` + badge de "dados dessincronizados".
- Web = online-only; offline vale só para desktop/mobile (SQLite no web exige WASM — fora do MVP).

## Qualidade

`flutter analyze` sem issues + `flutter test`. Models freezed; estados de tela como unions selados.
Strings de usuário em **PT-BR**. Prefira o servidor Dart MCP (hot reload, analyze, format, test).
