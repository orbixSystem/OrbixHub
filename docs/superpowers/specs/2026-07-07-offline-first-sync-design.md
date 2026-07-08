# Offline-first + SQLite + Sync — Design aprovado (2026-07-07)

> Aprovado pelo dono em 2026-07-07 (decisões por pergunta direta + revisão AppSec).
> Validado contra o código real da branch `feat/offline-sync` (pós-rebase do módulo
> caixa/venda). Fonte de verdade para o plano de implementação.

## Objetivo

O app Flutter opera offline nos módulos **estoque, clientes, caixa e OS** (+ **login
offline**), persistindo em SQLite local (drift + SQLCipher) e sincronizando com o
Postgres quando a conexão volta.

## Decisões fechadas

| Tema | Decisão |
|---|---|
| Plataformas | Offline em **Windows desktop + mobile**. **Web = online-only** (indicador mostra "sem conexão — recursos indisponíveis"; nada de drift/WASM no MVP). |
| Login offline | **Todos** os usuários que já logaram online no dispositivo. Validade **7 dias** desde o último login online (hora do servidor). |
| Réplica local | Só a **empresa ativa** — 1 arquivo de banco SQLCipher por tenant. |
| Cripto local | SQLCipher (AES-256); chave por dispositivo no secure storage. |
| Caixa offline | Completo: abrir/fechar sessão + lançamentos, tudo via outbox. |
| Caixa × conflito | **Sessão por dispositivo ("ponto de caixa", modelo Square/Toast):** cada dispositivo tem a própria sessão; offline e online coexistem; relatório soma as sessões. Nunca mescla, nunca sobrescreve. |
| Numeração | UUID definitivo gerado no cliente (PKs já são uuid). Número humano (OS-NNNN etc.) é **provisório** offline ("OS-P0123") e vira oficial no replay (servidor gera max+1, com retry em `P2002`). |
| Indicador | Chip no rodapé da sidebar (desktop/tablet-drawer) e no header de conteúdo no mobile (<600, bottom bar); estados `online | syncing | offline` + N pendentes. Banner fino no topo nas transições. |
| Arquitetura | Sync próprio: drift + outbox no front; módulo `sync` no back (pull incremental + push idempotente aplicado **via services públicos**). Sem engine de terceiros. |
| Conflito | Last-write-wins por `updated_at` (v1), com timestamp **clampado pelo servidor** (ver S2). |

## Bloco 1 — Camada local (drift) + Login offline

**Banco:** `drift` + `sqlcipher_flutter_libs`, um arquivo por tenant
(`orbix_<tenantId>.db`). Chave AES por dispositivo no secure storage. Tabelas:

- Espelhos: `customer`, `subject`, `inventory_item`, `stock_movement`,
  `service_order` (+ `service_order_item`, `service_order_event`,
  `service_order_photo` meta), `service_order_template` (+ itens, read-only —
  p/ aplicar template offline), `cash_session`, `cash_entry`.
- `outbox` — mutações pendentes: `client_mutation_id` (uuid), **`author_user_id`**,
  `entity`, `op`, `payload` json, `client_updated_at`, `status`
  (`pending|dispatching|applied|discarded|failed`).
- `sync_state` — cursor de pull por entidade (`updated_at`,`id`).
- `pending_upload` — fotos offline como **BLOB dentro do banco** (S6), referenciando a OS.
- Device-scoped (arquivo próprio, fora do banco por tenant): credenciais offline,
  snapshot do `/me`, `device_id` (uuid estável do dispositivo), `max_seen_ts`.

**Login offline:**
1. Em cada login online OK: salvar e-mail, hash **argon2id da senha com salt por
   dispositivo** (nunca a senha, nunca o hash do servidor), snapshot do `/me`
   (papel, permissões, módulos, memberships) e `lastOnlineLoginAt` (hora do servidor).
2. Offline: verificar contra o hash local; válido + ≤7 dias → sessão offline com o
   snapshot. Expirado → "É necessário conectar-se para entrar".
3. Sessão offline **sem JWT** — novo estado do `SessionController`
   (`SessionState.offline(Me me)`), populado a partir do snapshot. `_bootstrap()`
   ganha o caminho offline (hoje depende de `refresh()` + `fetchMe()`).
4. Ao reconectar: renovar sessão real (refresh token; senão pedir login) **antes**
   do push do outbox. RLS/permissões do servidor continuam a autoridade.

## Bloco 2 — Motor de sincronização

**Backend — módulo novo `sync` (núcleo, não gated):**

- **Pull:** `GET /api/sync/changes?entity=&since=<cursor>&limit=` — linhas alteradas
  do tenant por entidade, cursor composto (`updated_at`,`id`) monotônico, paginado
  (S10). Sob RLS (`withTenantTx`); compõe via métodos públicos novos
  `listChangedSince(cursor, limit)` em cada service dono ("aponta, não invade").
  Cursor usa `updated_at` onde existe; tabelas verdadeiramente append-only
  (`stock_movement`, `service_order_event`, `service_order_photo`) usam
  `created_at`. Sem hard delete no projeto → exclusão chega como mudança de `status`.
- **Push:** `POST /api/sync/push` — lote ordenado de mutações
  `{ client_mutation_id, entity, op, payload, client_updated_at }` + autor declarado.
  Idempotência pela tabela nova `sync_mutation`
  (unique `tenant_id + author_user_id + client_mutation_id`, S8). Cada mutação é
  aplicada chamando o **service público do módulo dono** (permissões + auditoria
  valem no replay). Resposta por item: `applied | discarded | error`.
- **LWW:** `effective_ts = min(client_updated_at, now())` (S2); linha do servidor
  mais nova → `discarded`; sobrescrita de dado mais antigo é auditada com
  `{valorAnterior, client_updated_at, effective_ts}`. Erro de validação não trava a
  fila → item `failed` visível ao usuário.
- **Create com id do cliente:** os services de create dos 4 módulos passam a aceitar
  `id?` (uuid) — usado pelo replay para preservar o id gerado offline. INSERT puro;
  unique violation → `error: id já existe` (S9, sem upsert). Número humano gerado no
  replay (max+1 com retry em `P2002`).

**Frontend — `SyncEngine` + repositories `LocalFirst`:**

- Impl `LocalFirst` de cada repository dos 4 módulos (decorator sobre a impl dio),
  registrada nos providers existentes (`diOverrides`) **somente quando `!kIsWeb`**:
  lê do drift; escreve no drift + enfileira no outbox. Telas não mudam.
- Online: outbox despachado quase em tempo real + pull periódico e por evento do
  WebSocket. Reconexão: **push primeiro, pull depois** (estado `syncing`).
- O push só despacha mutações do **usuário da sessão online atual** (S1); as de
  outros autores ficam pendentes, com indicação no chip.
- Fotos: `pending_upload` sobe para `/files` após a OS correspondente sincronizar.

## Mudanças de schema (migration `0031`, aditiva, nos 3 lugares)

1. `cash_session.device_id uuid NULL` — sessão por ponto de caixa. O índice parcial
   único de sessão aberta passa de por-tenant para **`(tenant_id, device_id) WHERE
   status='open'`**. `openSession`/`currentSession`/`createEntry` passam a operar
   por `device_id` (front envia o uuid estável do dispositivo; web também gera um e
   persiste em `shared_preferences`). Sessões antigas ficam com `device_id NULL`.
2. `service_order_item.updated_at` e `cash_entry.updated_at` (ambas mutáveis —
   item de OS editável; entry ganha `reversed_at` no estorno — e sem coluna hoje).
3. Função + **triggers `BEFORE UPDATE` `set_updated_at`** nas tabelas espelhadas
   mutáveis (`customer`, `subject`, `inventory_item`, `service_order`,
   `service_order_item`, `cash_session`, `cash_entry`) — hoje o `updated_at` é
   manual nos repos e um esquecimento furaria o cursor do pull.
4. Tabela `sync_mutation` (idempotência do push): `tenant_id`, `author_user_id`,
   `client_mutation_id`, `entity`, `op`, `result`, `applied_at`; unique nos 3
   primeiros; **RLS + FORCE**.

## Requisitos de segurança (revisão AppSec 2026-07-07 — OBRIGATÓRIOS)

**S1. Autoria no outbox (crítico).** `outbox.author_user_id` no enqueue; push só do
autor da sessão atual; servidor rejeita lote cujo autor declarado ≠ `sub` do JWT.

**S2. Timestamp não confiável (crítico).** `effective_ts = min(client_updated_at,
now())` (clamp); empate → servidor ganha; sobrescrita auditada com o valor anterior.

**S3. Anti-rollback de relógio.** `max_seen_ts` no dispositivo (atualizado a cada uso
e resposta do servidor); login offline com `agora < max_seen_ts` → expirado. Os 7
dias contam de `lastOnlineLoginAt` em hora do servidor.

**S4. Custo do hash é a defesa.** Argon2id via binding nativo (libsodium); memória
64–128 MB, 3 iterações, ~300–500 ms no hardware alvo. Servidor já exige senha ≥8
(`@MinLength(8)` nos DTOs). Backoff local (5 erros → exponencial) é fricção extra.

**S5. Revogação da réplica local.** Membership do tenant revogada/desativada
(resposta explícita, não 401 transitório) → apagar o banco SQLCipher do tenant + a
credencial offline do usuário. Higiene: apagar bancos sem uso há 60 dias. Risco
aceito documentado: dispositivo comprometido antes da revogação = dados daquele
tenant expostos (no Windows a chave DPAPI é por usuário do SO, sem sandbox por app).

**S6. Fotos pendentes cifradas.** Bytes como BLOB na `pending_upload` dentro do
SQLCipher (comprimidos antes); nunca arquivo solto em claro.

**S7. Validação whitelist no replay.** Registro explícito `entity+op → {DTO
existente, método do service}`; todo payload passa por `plainToInstance` +
`validate()` antes do service; `entity/op` desconhecido → rejeitado.

**S8. Idempotência escopada por autor.** Unique `(tenant_id, author_user_id,
client_mutation_id)` com autor tirado do JWT no apply.

**S9. Sem upsert cego.** `create` = INSERT puro (unique → erro); `update` sob RLS
(0 linhas → `discarded`). Nunca `ON CONFLICT DO UPDATE` no sync.

**S10. Limites anti-DoS.** Push: máx. 100 mutações/lote + limite de body + throttler
global existente. Pull: paginado (~500 linhas/entidade + `nextCursor`); `since=0`
nunca devolve o tenant inteiro numa resposta.

## Bloco 3 — UX offline e bloqueios

**`ConnectivityController`** (Riverpod): `connectivity_plus` + ping `/health` +
saúde do WebSocket → `online | offline | syncing` + contagem do outbox.

**UI:** chip no rodapé do `SidebarContent` (junto ao `_UserFooter`) para desktop e
drawer; no mobile (<600, bottom bar) o estado vive no `_ContentHeader`. Banner fino
no topo nas transições ("Você está offline — alterações serão enviadas ao
reconectar"), some ao voltar. Web offline: banner de online-only. Polir com
Playwright contra o tema atual, estados forçados via dev-tools.

**Escopo por módulo:**

| Módulo | Offline | Bloqueado offline ("Requer conexão") |
|---|---|---|
| Estoque | CRUD + arquivar | `lookup(code)` EAN/catálogo — mensagem clara no `item_form_dialog`; cadastro manual segue; `suggestSku` vira local |
| Clientes | CRUD clientes + veículos, foto do veículo (fila) | `lookup` FIPE (marcas/modelos/anos) — cascata do `subject_form_dialog` vira texto livre com aviso |
| Caixa | Sessão por dispositivo + lançamentos + estorno | — aviso permanente: "Os lançamentos só serão efetivados no sistema quando a conexão voltar" |
| OS | Criar/editar, status, itens, fotos, diagnóstico, notas, responsável, datas, aplicar template (cache local) | Enviar link de acompanhamento; emitir NF; comentários de foto (exigem servidor) |
| Demais | — | Chat, notificações, relatórios, NF, billing, equipe, configurações, venda avulsa (v1) → estado "Requer conexão" |

**Avisos vermelhos na OS (offline):** texto vermelho fixo em fotos, diagnóstico,
notas, troca de responsável e mudança de data: **"⚠ Será enviado ao sistema quando a
conexão voltar"**. Registros criados offline: badge "pendente de envio" + número
provisório "OS-P0123".

## Testes / evidência

- Back: unit + e2e do `sync` — idempotência do push, cursor do pull, LWW,
  **isolamento tenant A/B**, permissões no replay; caixa por dispositivo (duas
  sessões abertas em devices distintos; conflito no mesmo device). `back:lint` 0
  warnings.
- Segurança (S1–S10): autor ≠ JWT rejeitado; timestamp futuro clampado; relógio
  voltado → login offline expirado; campo fora do whitelist rejeitado; create com id
  existente falha; lote >100 rejeitado.
- Front: unit do outbox/merge, login offline (hash, 7 dias, backoff, S3),
  `ConnectivityController`; widget tests dos avisos; `flutter analyze` 0 issues +
  `flutter test`.
- Playwright (web build) para validar o design do indicador/banner.

## Riscos aceitos (documentados)

- Dispositivo comprometido antes de revogação → réplica local daquele tenant exposta.
- Senha trocada no servidor continua válida offline em outros dispositivos por até 7 dias.
- LWW pode descartar edição concorrente mais antiga (auditada; v2 pode evoluir para merge por campo).
