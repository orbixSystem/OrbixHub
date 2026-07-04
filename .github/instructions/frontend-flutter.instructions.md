---
applyTo: "front/**"
description: "Frontend Flutter: estado real (feature-complete), convenções, responsividade obrigatória e plano offline."
---

# Frontend Flutter

> Estado real (validado): o app **NÃO** é mais esqueleto — está **feature-complete** para o núcleo.
> Features implementadas: `auth`, `billing`, `os`, `customers`, `inventory`, `messages`,
> `notifications`, `report`, `settings`, `dashboard`, `tracking` (público), `team`, `shell`.
>
> ⚠️ **Bloqueador atual:** `pubspec.yaml` exige Dart `^3.12.1`, mas a máquina tem 3.11.3 →
> `flutter pub get` falha. Rode `flutter upgrade` antes de trabalhar no app.

## Stack real (`front/pubspec.yaml`)

- **flutter_riverpod** 3 — estado/DI (sem codegen).
- **go_router** 17 — navegação + deep link.
- **dio** 5 — HTTP para a API NestJS (`/api`).
- **freezed** 3 + **json_serializable** — models imutáveis + unions selados.
- **flutter_secure_storage** — só o refresh token. **shared_preferences** — prefs não-sensíveis.
- **socket_io_client** — WebSocket (chat/tracking em tempo real). **audioplayers** — som de notificação.
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
  unauthenticated/error). Após login/refresh/switch-tenant busca `/me` e popula. Router/menu leem daqui.
- Navegação gated: `gatedNavItems(me)` (função pura, testada) decide o menu por papel+módulo; o
  router **também** guarda as rotas. Esconder ≠ proteger — o backend é a verdade; 403 tratado com elegância.

## Integração com a API

- Access token (JWT 15m) em `Authorization: Bearer ...`; **só em memória**. Refresh token **só no
  secure storage**. No 401 → **refresh single-flight** (uma chamada, requests concorrentes esperam);
  falhou → limpa sessão → `/login`.
- **Nunca** envie `tenantId` manualmente — o servidor deriva do JWT. Troca de oficina via
  `POST /api/auth/switch-tenant`.
- Planos e módulos **nunca** hardcoded — vêm de `/me` e `/billing/plans` em runtime.

## RESPONSIVIDADE — REQUISITO OBRIGATÓRIO (agora)

Toda tela nova ou alterada deve funcionar em **desktop, web e mobile**. Critério de aceite:
- breakpoints (sidebar fixa ≥1000px, drawer abaixo — padrão do `AppShell`);
- tabelas colapsam em cards no mobile; alvos de toque adequados;
- o shell é dono da moldura; telas de conteúdo devolvem só o corpo.

## Offline (planejado para o MVP — ver mvp-roadmap.instructions.md)

- CRUD básico (clientes, OS, caixa, estoque) funciona offline via **drift** (SQLite) + **outbox**;
  nova impl `LocalFirst` de cada repository (sem mudar telas). Sincroniza ao reconectar (last-write-wins).
- **Bloqueado offline:** chat, link em tempo real e emissão de NF (exigem rede) → desabilitar com
  aviso "Requer conexão".
- **Indicador online/offline em tempo real:** `connectivity_plus` + saúde do socket → controller
  Riverpod expõe `online | offline | syncing` para o shell + badge de "dados dessincronizados".

## Qualidade

`flutter analyze` sem issues + `flutter test`. Models freezed; estados de tela como unions selados.
Strings de usuário em **PT-BR**. Ao trabalhar aqui, prefira as ferramentas do servidor Dart MCP
(hot reload, analyze, format, test) quando disponíveis.
