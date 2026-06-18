# Ordens de Serviço (`os`) — Design

> Spec do módulo OS do OrbixHub. Apoia-se na skill `orbixhub-arquitetura`
> (RLS/FORCE, `withTenantTx`/`runWithTenant`, Controller→Service→Repository,
> "aponta não invade", snapshot histórico, sem hard delete, whitelist, segredos via env,
> **audit FORA de transação** — nada disso repetido aqui).
> **Tipo:** Contratável · gated por `@RequiresModule('os')`. Já está nos planos `trial` e `pro`.
> Permissões semeadas: `os.read`, `os.write`, `os.approve`.

## 1. O que é
Registro do trabalho num **veículo** (subject) de um **cliente**: abre → vincula
cliente+veículo → adiciona **itens** (serviços + produtos do estoque) → anda pelo
**workflow de status** → **fotos** → **timeline** → **chat com o cliente** → **totais** →
**baixa de estoque** → **link público**. Alimenta o histórico do veículo (`SubjectHistoryProvider`).

**Genérico:** "veículo" vem do `subject` (rótulo/campos por config do `customers`); a OS só
guarda `subject_id` + snapshot. Nada de "placa" hardcoded.

## 2. Decisões travadas (brainstorm)
- **Workflow:** `aberta → aguardando_aprovacao → aprovada → em_execucao → concluida → entregue` (+ `cancelada`). *Aprovar* exige `os.approve`.
- **Baixa de estoque automática** ao entrar em **`concluida`** (idempotente via `stock_applied`); só **produtos**.
- **Datas (p/ Agenda futuro):** `scheduled_start`/`scheduled_end` (previsão) + `started_at`/`finished_at` (real).
- **Fotos:** object storage **MinIO** (container Podman) atrás de `StorageProvider` (troca por S3 em prod). Upload real.
- **Timeline pública = linha do tempo** (mais recente no topo). Cada evento/nota tem flag **`visible_public`**. Página read-only; tenant resolvido via `SECURITY DEFINER`. Copiar funciona; WhatsApp/e-mail desabilitados.
- **CHAT cliente↔mecânico no link público:** bidirecional. Cliente (no link, **sem auth por enquanto**) e staff (no detalhe interno) trocam mensagens. **Futuro:** autenticar o link com código via WhatsApp; por ora o chat funciona aberto (com rate-limit).
- **Diferenciais:** baixa automática · fotos · timeline pública · **chat** · **PDF/impressão** · **tempo por mecânico** · **templates de serviço**. **Fora:** cliente aprovar orçamento pelo link (página pública é leitura + chat).
- **UX/UI:** caprichado, seguindo o design system (grafite + tangerina, Sora/Manrope); **verificado com Playwright** (screenshots do app em :8090, iterar até ficar redondo).

## 3. Modelo de dados (tenant-scoped, RLS+FORCE; decimal)
### `service_order` (cabeçalho)
`id, tenant_id, number` (`OS-0001`), `customer_id`, `customer_name` (snapshot), `subject_id`,
`subject_label` (snapshot), `status`, `assigned_to` (mecânico), `opened_by`, `complaint`,
`diagnosis`, `scheduled_start, scheduled_end, started_at, finished_at, opened_at, closed_at`,
`discount numeric(14,2)`, `total numeric(14,2)` (cacheado), `stock_applied bool`,
`public_token uuid` (único), `deleted_at`, `created_at, updated_at`. CHECK no status.

### `service_order_item`
`id, tenant_id, order_id, kind`('product'|'service'), `inventory_item_id` (nullable, aponta),
`name` (snapshot), `quantity numeric(14,3)`, `unit_price numeric(14,2)` (snapshot),
`discount numeric(14,2)`, `total numeric(14,2)`, `created_at`. Avulso = sem `inventory_item_id`.

### `service_order_photo`
`id, tenant_id, order_id, storage_key, url, caption, uploaded_by, created_at`. Arquivo no MinIO.

### `service_order_event` (timeline)
`id, tenant_id, order_id, kind`('created'|'status_change'|'note'|'photo'), `message`,
`status_snapshot`, `photo_id`, `visible_public bool`, `created_by, created_at`.

### `service_order_message` (CHAT)
`id, tenant_id, order_id, sender`('customer'|'staff'), `author_name` (snapshot/opcional),
`body`, `created_by` (staff), `read_at`, `created_at`. Thread por OS; ordenado por tempo.

### `service_order_template` + `service_order_template_item`
Template nomeado (ex.: "Revisão completa") + itens pré-definidos. "Aplicar" pré-preenche os itens da OS.

Índices: `(tenant_id,status)`, `(tenant_id,customer_id)`, `(tenant_id,subject_id)`,
`(tenant_id,number)` único, `(order_id)` nas filhas, `public_token` único, `(order_id,created_at)` em event/message.

## 4. Workflow (máquina de estados)
`aberta`→{aguardando_aprovacao, em_execucao, cancelada}; `aguardando_aprovacao`→{aprovada(os.approve), aberta, cancelada}; `aprovada`→{em_execucao, cancelada}; `em_execucao`→{concluida, cancelada} (set `started_at`); `concluida`→{entregue} (set `finished_at`; **baixa de estoque** idempotente); `entregue`/`cancelada` terminais. Cada mudança gera `service_order_event` (status_change, `visible_public=true`).

## 5. Integrações ("aponta, não invade")
- **customers:** `getCustomer`/`getSubject` (picker + snapshot ao criar).
- **inventory:** `searchForPicker` (picker), `getItem` (snapshot), `decrementStock(tenantId,{itemId,qty,refType:'os',refId})` na conclusão.
- **histórico do veículo:** OS implementa o `SubjectHistoryProvider` → detalhe do veículo lista as OS.

## 6. Storage (fotos) — `StorageProvider` + MinIO
`StorageProvider { put(key,buf,ct); url(key); remove(key) }`; impl `MinioStorageProvider` (S3-compat).
Env (Zod, segredos): `STORAGE_PROVIDER=minio`, `S3_ENDPOINT, S3_REGION, S3_ACCESS_KEY, S3_SECRET_KEY, S3_BUCKET, S3_PUBLIC_URL`. Container `orbix-minio` (Podman). Upload `FileInterceptor` (memory) → valida imagem+tamanho → `put`. **Sem storage dentro de transação de banco.**

## 7. Endpoints (`@RequiresModule('os')`, exceto os públicos)
| Método | Rota | Perm | O quê |
|---|---|---|---|
| POST | `/os/orders` | os.write | cria OS (snapshot cliente+veículo) |
| GET | `/os/orders?q=&status=&customerId=&page=` | os.read | lista |
| GET | `/os/orders/:id` | os.read | detalhe (itens, fotos, timeline, chat) |
| PATCH | `/os/orders/:id` | os.write | edita cabeçalho (relato, diagnóstico, datas, responsável, desconto) |
| POST | `/os/orders/:id/status` | os.write (`os.approve` p/ aprovar) | transição |
| POST/PATCH/DELETE | `/os/orders/:id/items[/:itemId]` | os.write | itens (recalcula total) |
| POST/DELETE | `/os/orders/:id/photos[/:photoId]` (multipart) | os.write | fotos (MinIO) |
| POST | `/os/orders/:id/notes` | os.write | nota na timeline (toggle `visible_public`) |
| GET/POST | `/os/orders/:id/messages` | os.read/os.write | **chat (lado staff)** |
| DELETE | `/os/orders/:id` | os.write | soft delete |
| GET | `/os/orders/:id/pdf` (ou front imprime) | os.read | OS imprimível |
| CRUD | `/os/templates...` + `/os/orders/:id/apply-template/:templateId` | os.write | templates |
| **GET** | **`/public/track/:token`** | público | status + previsão + fotos + timeline (`visible_public`) + chat |
| **GET/POST** | **`/public/track/:token/messages`** | público (rate-limit) | **chat (lado cliente)** — sem auth por ora |

Públicos resolvem tenant+OS via função `SECURITY DEFINER` por `public_token` (nunca confiando em input).

## 8. Front (feature `os`) — UX caprichado + Playwright
- **Lista** de OS: status como chips coloridos, busca, filtro por status; linha com nº, cliente, veículo, status, total.
- **Detalhe**: cabeçalho editável; **itens** (picker do estoque + avulso, totais ao vivo); **fotos** (upload, galeria); **timeline** (eventos + nota com toggle "visível ao cliente"); **chat** (staff); **botões de status** (só transições válidas); responsável; datas (previsão/real); **link público** (gerar/copiar; WhatsApp/e-mail desabilitados); **imprimir/PDF**; **aplicar template**.
- **Público `/t/:token`**: **timeline** (recente no topo) + status + previsão + fotos + **chat** (cliente envia/recebe; polling). Sem login.
- UI só via repository; freezed; estado selado; PT-BR; design tokens. Menu via `me.modules`.
- **Playwright:** após cada tela, screenshot do app em `http://localhost:8090` e iterar o visual até ficar polido e coerente com o resto (login/equipe/estoque). (Há histórico de PWuse em `front/tmp-pw/`.)

## 9. Fases de entrega (cada uma roda + testes)
1. **Núcleo OS** (back+front): order+item, CRUD, workflow de status, totais, integração customers+inventory (picker+snapshot+baixa automática), `SubjectHistoryProvider`, e2e. **(começa aqui)**
2. **Timeline + notas** (event table, `visible_public`).
3. **Fotos (MinIO)**: StorageProvider + container + upload.
4. **Acompanhamento público + CHAT**: função `SECURITY DEFINER`, `/public/track/:token`(+`/messages`), `service_order_message`, página pública (timeline + chat), chat no detalhe interno. (sem auth no link; rate-limit; futuro: código WhatsApp).
5. **Templates de serviço** + aplicar.
6. **PDF/impressão.**
> Polimento de UX via Playwright ao final de cada fase com front.

## 10. Testes (mínimo)
Isolamento de tenant; autorização (`os.read`/`write`/`approve`); máquina de estados (válidas/inválidas; aprovar exige os.approve); baixa idempotente na conclusão (chama inventory, não toca tabela); snapshot ao criar; soft delete; timeline pública só `visible_public`; chat público posta/lê por token (rate-limit); upload valida tipo/tamanho; nenhuma chamada externa em transação.
