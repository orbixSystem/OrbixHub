---
applyTo: "**"
description: "Escopo e roadmap do MVP do OrbixHub: fiscal + offline, responsividade obrigatória, auditoria UI/UX no fim. Ler em todo prompt."
---

# OrbixHub — Escopo & Roadmap do MVP

> **Consulte este arquivo em toda tarefa.** Ele define o que é MVP, o que está pronto,
> o que falta e as regras transversais decididas pelo dono do produto. Não perca este contexto.

## Visão do produto (relembrar)

Sistema de **gestão modular multi-tenant**, vertical inicial **oficina mecânica**, posicionado
como **concorrente enxuto do SG Master**. Filosofia: **simples, fácil de usar, focado em oficina**
— sem o excesso de funcionalidades densas do SG Master. Módulos ativáveis por plano, nunca forks.

## Definição de MVP (decidida)

O MVP **precisa ter fiscal + offline**, além do núcleo de oficina já implementado.

### ✅ Já implementado (núcleo funcional — backend + Flutter)
- Plataforma: multi-tenant RLS, auth/IAM, billing modular, settings (host incremental), dashboard.
- Vertical oficina: `os` (ordens de serviço + templates + fotos + métricas), `customers`
  (clientes + subjects/veículos + FIPE), `inventory` (produto/serviço + baixa por OS + catálogo EAN).
- Diferencial: **link público de acompanhamento + chat em tempo real** (WebSocket socket.io;
  tenant resolvido no servidor por função `SECURITY DEFINER`).
- Transversais: `messages`, `notifications`, `report`, `realtime`, `devtools` (dev-only).

### ❌ Falta para o MVP (dois blocos grandes + destrave)

**0. Destrave do front (bloqueador atual):** o `pubspec.yaml` exige Dart `^3.12.1` mas a máquina
tem 3.11.3 → `flutter pub get` falha. Atualizar o Flutter SDK (`flutter upgrade`) antes de mexer no app.

**1. Fiscal — módulo `invoice` (online-only):**
- Fronteira já definida em `docs/configuracao.md`: identidade fiscal (CNPJ, IE/IM, regime, CNAE,
  endereço) fica no núcleo (`tenant.settings`); dados sensíveis (certificado A1 criptografado,
  ambiente, série, CSC/token) ficam em `tenant_module.settings['invoice']`.
- Backend novo `back/src/modules/invoice/`: migration aditiva (tabelas `invoice`/`invoice_event`
  com RLS + seed `module`+`plan_module`), **gateway fiscal abstrato** (mesmo padrão de `payment/`,
  com `NoopFiscalGateway` em dev), emissão a partir da OS (aponta via service público — não invade),
  chamada externa **fora da transação**, status por **webhook idempotente**. Gate:
  `@RequiresModule('invoice')` + `@Permissions('invoice.issue')`.
- **Decisões do dono (decididas):**
  - **Documento:** **NFS-e** (nota de serviço — mão de obra da oficina). NFC-e/NF-e de produto fica
    para depois.
  - **Gateway:** **API NFS-e Nacional (gov.br)** — **gratuita** (sem mensalidade/custo por nota;
    APIs de produção liberadas em out/2025; fluxo DPS → NFS-e → Eventos/DFe, REST). Primeira impl real
    = `GovBrNfseGateway`; manter `NoopFiscalGateway` em dev. Trocar por gateway pago é só outra impl.
  - **Ressalvas:** exige **certificado A1** do lojista (custo dele, ~R$120/ano) e que o **município
    tenha aderido ao ADN** (Ambiente de Dados Nacional) — nem todos aderiram; usar o **leiaute
    novo/atual** (a API antiga será descontinuada). Municípios de lançamento a confirmar por tenant.

**2. Offline-first + SQLite + Sync:**
- **Escopo (decidido):** offline cobre **CRUD básico** — clientes, ordem de serviço, caixa, estoque.
  Salva local e depois **avisa que os dados estão dessincronizados com a nuvem**.
- **Bloqueado offline (exige rede):** link em tempo real, chat, **emissão de NF** (depende de API).
  Esses recursos ficam desabilitados com aviso "Requer conexão" quando offline.
- **Indicador online/offline em tempo real:** combinar conectividade do device
  (`connectivity_plus`) + saúde do WebSocket; um controller Riverpod expõe
  `online | offline | syncing` para o shell.
- **Frontend:** `drift` (SQLite) + `sqlite3_flutter_libs`; nova impl `LocalFirst` de cada repository
  (o repository pattern já existente permite trocar por injeção no `di.dart` sem mudar as telas);
  **outbox** de mutações com `client_mutation_id`.
- **Backend:** endpoints de sync — `GET /sync/changes?since=` (pull) e `POST /sync/push`
  (push, idempotente). Conflito: **last-write-wins** por `updated_at` no v1. RLS continua imposto.
- **Decisão do dono (decidida):** **web é online-only**; offline vale para **desktop/mobile**
  (SQLite no web exige WASM — fora do MVP).

## Regras transversais (decididas)

- **RESPONSIVIDADE É REQUISITO AGORA.** Toda tela — nova ou alterada — deve ser desenvolvida para
  **desktop, web e mobile**. É critério de aceite: breakpoints, sidebar↔drawer, tabelas↔cards,
  alvos de toque adequados. O `AppShell` já tem a base (sidebar fixa ≥1000px, drawer abaixo);
  cada feature deve seguir.
- **Auditoria de UI/UX/Design = fase FINAL.** Passada completa de design/usabilidade só depois que
  tudo estiver funcionando. Não bloqueia o desenvolvimento; é o último épico antes do lançamento.

## Ordem de execução sugerida

1. Destravar o Flutter SDK. 2. Bloco **Fiscal** (isolado, menor risco). 3. Bloco **Offline**
(transversal, mexe em todos os repositórios) + indicador de conexão. 4. WhatsApp/e-mail do link
público (hoje só "copiar link"). 5. **Auditoria de UI/UX/Design** (fase final).

> Ao implementar qualquer item, siga a skill `orbixhub-arquitetura` (regras de ouro + playbook de
> módulo novo) e os arquivos de instrução por área. Migrations são aditivas nos 3 lugares.
