---
name: orbixhub-frontend-flutter
description: Use when building or changing anything in the OrbixHub Flutter app (front/**) — screens, Notifiers, repositories, routing, session, responsiveness, or the planned offline layer. Encodes the real feature-complete state, the feature-first layering, API integration rules, the mandatory-responsiveness requirement, and the offline plan.
---

# OrbixHub — Frontend Flutter

> Estado real (2026-07-17): o app **NÃO** é esqueleto — está **feature-complete** para o núcleo.
> Features: `auth`, `billing`, `os`, `customers`, `inventory`, **`sales`** (Vendas/caixa),
> **`invoice`** (Notas Fiscais — lista/detalhe/emitir de OS e venda/PDF-XML/cancelar),
> **`schedule`** (Agenda), `messages`, `notifications`, `report`, `settings`, `dashboard`,
> `tracking` (público), `team`, `shell`. ~129 arquivos Dart.

## Stack real (`front/pubspec.yaml`)

- **flutter_riverpod** 3 — estado/DI (sem codegen).
- **go_router** 17 — navegação + deep link.
- **dio** 5 — HTTP para a API NestJS (`/api`).
- **freezed** 3 + **json_serializable** — models imutáveis + unions selados.
- **flutter_secure_storage** — só o refresh token. **shared_preferences** — prefs não-sensíveis.
- **socket_io_client** — WebSocket (chat/tracking). **audioplayers** — som de notificação.
- **google_fonts** (Sora/Manrope), **fl_chart** (dashboard/relatórios), **pdf**/**printing**/**csv**/**archive**
  (export incl. xlsx), **file_picker**, **url_launcher** (abrir PDF/XML da NF), **animations**, **intl**.

## Arquitetura — feature-first em camadas

`presentation` (telas + Notifiers) → `domain` (entidades freezed + **interface** do repository) →
`data` (impl dio + **impl fake** + dtos). **Regra dura: a UI nunca chama dio direto — sempre via
repository.** Troca de impl por injeção no `di.dart` (composition root de todos os providers).

- `core/`: `network/` (dio + interceptor: bearer em memória, refresh single-flight no 401),
  `router/` (go_router com guards de auth/papel/módulo; rotas literais `/m/<key>` antes do genérico
  `/m/:moduleKey`), `storage/` (SecureTokenStore — só refresh token, Keychain legado no macOS),
  `ui/` (`ui.dart` = barrel do **design system neumórfico**: `NeuSurface/NeuCard/NeuButton/NeuField/
  NeuChip/NeuList/NeuChart/NeuNetworkImage` + `adaptive.dart`), `theme/` (**NeuTokens** ThemeExtension
  via `context.neu`, `AppTheme.light/dark({seed})`, **10 paletas por seed**, Sora/Manrope), `realtime/`
  (`RealtimeChat` socket.io), `error/` (AppException), `widgets/`, `config/` (base URL via `--dart-define`).
  **⚠️ `AppColors` (grafite+tangerina) é LEGADO/descontinuado — use `context.neu`.** Design detalhado:
  spec `docs/superpowers/specs/2026-07-04-neumorphic-redesign-design.md`.
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
- breakpoints (`core/ui/adaptive.dart`: `tablet 600`, `desktop 1100`) → **sidebar navy fixa ≥1100px**,
  drawer entre 600–1100, bottom-bar + menu "Mais" abaixo de 600 (padrão do `AppShell`);
- tabelas colapsam em cards no mobile; alvos de toque adequados; use `AdaptiveBody(mobile:, desktop:)`;
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
