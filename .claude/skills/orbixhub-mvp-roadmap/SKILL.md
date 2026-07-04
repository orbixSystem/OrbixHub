---
name: orbixhub-mvp-roadmap
description: Use in EVERY OrbixHub task to keep scope in mind — what is MVP, what is done, what remains, and the cross-cutting rules decided by the product owner (fiscal + offline are required; responsiveness is required now; UI/UX audit is the final phase). Read alongside orbixhub-arquitetura.
---

# OrbixHub — Escopo & Roadmap do MVP

Sistema de **gestão modular multi-tenant**, vertical inicial **oficina mecânica**, posicionado como
**concorrente enxuto do SG Master** (simples, fácil, focado em oficina). Módulos ativáveis por
plano, nunca forks.

## Definição de MVP (decidida)

O MVP **precisa ter fiscal + offline**, além do núcleo de oficina já implementado.

### ✅ Já implementado (núcleo + fiscal-backend)
- Plataforma: multi-tenant RLS, auth/IAM, billing modular, settings (host incremental), dashboard.
- Vertical oficina: `os` (ordens + templates + fotos + métricas), `customers` (clientes +
  subjects/veículos + FIPE), `inventory` (produto/serviço + baixa por OS + catálogo EAN).
- Diferencial: **link público de acompanhamento + chat em tempo real** (WebSocket socket.io;
  tenant resolvido no servidor por função `SECURITY DEFINER`).
- Transversais: `messages`, `notifications`, `report`, `realtime`, `devtools` (dev-only).
- **NOVO — módulo `invoice` (backend):** emissão de NF a partir da OS, online-only, via gateway
  fiscal abstrato (Noop em dev). Ver skill `orbixhub-fiscal-invoice`. Falta config sensível,
  testes e2e, gateway real gov.br e a feature no front.

### ❌ Falta para o MVP

**0. Destrave do front:** `pubspec.yaml` exige Dart `^3.12.1`; se `flutter pub get` falhar,
`flutter upgrade` antes de mexer no app.

**1. Fiscal — completar o módulo `invoice`:** DECISÕES do dono — documento **NFS-e** (serviço;
NFC-e/NF-e de produto depois, mas o design já é agnóstico e cobre produto+serviço); gateway =
**API NFS-e Nacional gov.br (gratuita)**, impl real futura `GovBrNfseGateway`; ressalvas: exige
**certificado A1** do lojista + **município aderido ao ADN** + leiaute novo. Detalhes na skill
`orbixhub-fiscal-invoice`.

**2. Offline-first + SQLite + Sync:** offline cobre **CRUD básico** (clientes, OS, caixa, estoque):
salva local e avisa "dados dessincronizados". **Bloqueado offline** (exige rede): link em tempo
real, chat, **emissão de NF**. Indicador online/offline em tempo real (`connectivity_plus` + saúde
do WebSocket → controller Riverpod `online|offline|syncing`). Front: `drift` (SQLite) +
`sqlite3_flutter_libs`, impl `LocalFirst` de cada repository, **outbox** com `client_mutation_id`.
Backend: `GET /sync/changes?since=` (pull) + `POST /sync/push` (idempotente); conflito
**last-write-wins** por `updated_at` no v1; RLS continua imposto. **Web = online-only**; offline só
desktop/mobile.

## Regras transversais (decididas)

- **RESPONSIVIDADE É REQUISITO AGORA.** Toda tela — nova ou alterada — para **desktop, web e
  mobile**. Critério de aceite: breakpoints, sidebar↔drawer, tabelas↔cards, alvos de toque.
- **Auditoria de UI/UX/Design = fase FINAL.** Só depois que tudo estiver funcionando. Não bloqueia
  o desenvolvimento; é o último épico antes do lançamento.

## Ordem de execução sugerida

1. Destravar Flutter SDK. 2. **Fiscal** (isolado, menor risco) — completar `invoice`. 3. **Offline**
(transversal, mexe em todos os repositórios) + indicador de conexão. 4. WhatsApp/e-mail do link
público (hoje só "copiar link"). 5. **Auditoria de UI/UX/Design** (fase final).

> Ao implementar qualquer item, siga a skill `orbixhub-arquitetura` (regras de ouro + playbook de
> módulo novo) e as skills por área (`orbixhub-backend-patterns`, `orbixhub-multitenancy-rls`,
> `orbixhub-auth-security`, `orbixhub-billing`, `orbixhub-frontend-flutter`, `orbixhub-testing`,
> `orbixhub-fiscal-invoice`). Migrations são aditivas nos 3 lugares.
