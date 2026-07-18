# Offline-first + SQLite + Sync — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** App Flutter opera offline (login, estoque, clientes, caixa, OS) com SQLite local e sincroniza com o Postgres ao reconectar, conforme `docs/superpowers/specs/2026-07-07-offline-first-sync-design.md`.

**Architecture:** Backend ganha o módulo núcleo `sync` (pull incremental `GET /sync/changes` + push idempotente `POST /sync/push` aplicado via services públicos, LWW com clamp de timestamp) + migration 0031 (device_id no caixa, updated_at + triggers, tabela sync_mutation). Frontend ganha drift+SQLCipher (row-store genérico espelhando o JSON da API), outbox por autor, repositories `LocalFirst` (decorator, só `!kIsWeb`), login offline (argon2id local, 7 dias) e indicador global de conexão.

**Tech Stack:** NestJS + Prisma + Postgres RLS (back) · Flutter + Riverpod 3 + drift + sqlcipher_flutter_libs + connectivity_plus + sodium_libs (front).

## Global Constraints

- Migrations **aditivas** e refletidas nos 3 lugares: `back/sql/auth-multitenant-schema.sql` + `back/prisma/migrations/0031_offline_sync/migration.sql` + `back/prisma/schema.prisma`; depois `npm run prisma:generate --workspace back`.
- Multi-tenant via RLS: escrita tenant-scoped sob `withTenantTx`/`runWithTenant`; `AuditService.log` **fora** de `withTenantTx` (tx aninhada esgota o pool).
- "Aponta, não invade": módulo `sync` NUNCA lê tabela de outro módulo; só compõe services públicos.
- Requisitos de segurança S1–S10 da spec são obrigatórios (autoria no outbox/push, clamp de timestamp, anti-rollback de relógio, argon2id nativo, revogação da réplica, fotos como BLOB, whitelist no replay, idempotência por autor, sem upsert, limites anti-DoS).
- Strings de usuário em PT-BR. Backend `npm run back:lint` 0 warnings; front `flutter analyze` 0 issues.
- Offline só `!kIsWeb`; web permanece online-only (indicador com mensagem própria).
- Flutter invocado por caminho completo: `C:\Users\KaueSobral\develop\flutter\bin\flutter.bat`. Backend local: PG Podman em 55432; nunca usar porta 3000/4400 (poisoned) — usar 4500 se precisar subir.
- Commits frequentes com escopo (`feat(back/sync): …`, `feat(front/offline): …`).

---

## PART A — Backend

### Task A1: Migration 0031 (schema nos 3 lugares)

**Files:**
- Create: `back/prisma/migrations/0031_offline_sync/migration.sql`
- Modify: `back/sql/auth-multitenant-schema.sql` (append idempotente, seguir padrão do bloco do cashier)
- Modify: `back/prisma/schema.prisma` (cash_session.device_id; updated_at em service_order_item e cash_entry; model sync_mutation)

**Interfaces:**
- Produces: coluna `cash_session.device_id uuid NULL`; índice `uq_cash_session_open_device`; colunas `service_order_item.updated_at`/`cash_entry.updated_at`; função `orbix_set_updated_at()` + triggers; tabela `sync_mutation` com RLS+FORCE.

- [ ] **Step 1:** Escrever `migration.sql` (e replicar no schema canônico):

```sql
-- 0031_offline_sync — aditiva. Caixa por dispositivo + versão p/ sync + idempotência do push.
ALTER TABLE cash_session ADD COLUMN IF NOT EXISTS device_id uuid;
DROP INDEX IF EXISTS uq_cash_session_one_open;
-- 1 sessão aberta por (tenant, ponto de caixa); NULL = ponto legado/único.
CREATE UNIQUE INDEX IF NOT EXISTS uq_cash_session_open_device
  ON cash_session (tenant_id, COALESCE(device_id, '00000000-0000-0000-0000-000000000000'::uuid))
  WHERE status = 'open';

ALTER TABLE service_order_item ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE cash_entry        ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE OR REPLACE FUNCTION orbix_set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END $$;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['customer','subject','inventory_item','service_order',
                           'service_order_item','cash_session','cash_entry'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_updated_at ON %I', t, t);
    EXECUTE format('CREATE TRIGGER trg_%s_updated_at BEFORE UPDATE ON %I
                    FOR EACH ROW EXECUTE FUNCTION orbix_set_updated_at()', t, t);
  END LOOP;
END $$;

CREATE TABLE IF NOT EXISTS sync_mutation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  author_user_id uuid NOT NULL,
  client_mutation_id uuid NOT NULL,
  entity text NOT NULL,
  op text NOT NULL,
  result text NOT NULL,               -- applied | discarded | error
  error_message text,
  entity_id uuid,
  applied_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_sync_mutation UNIQUE (tenant_id, author_user_id, client_mutation_id)
);
CREATE INDEX IF NOT EXISTS idx_sync_mutation_tenant ON sync_mutation(tenant_id);
ALTER TABLE sync_mutation ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_mutation FORCE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='sync_mutation') THEN
    CREATE POLICY tenant_isolation ON sync_mutation
      USING (tenant_id = current_tenant_id())
      WITH CHECK (tenant_id = current_tenant_id());
  END IF;
END $$;
GRANT SELECT, INSERT, UPDATE, DELETE ON sync_mutation TO app_user;
```

(Ao aplicar no canônico, copie exatamente o padrão de policy/grant do bloco `0025_cashier` do arquivo — se lá a policy usa `DO $$`/`format`, siga aquele padrão.)

- [ ] **Step 2:** `schema.prisma`: em `cash_session` adicionar `device_id String? @db.Uuid`; em `service_order_item` e `cash_entry` adicionar `updated_at DateTime @default(now()) @db.Timestamptz(6)`; criar model `sync_mutation` espelhando o SQL (`@@unique([tenant_id, author_user_id, client_mutation_id], map: "uq_sync_mutation")`).
- [ ] **Step 3:** `npm run prisma:generate --workspace back` → sem erro.
- [ ] **Step 4:** Aplicar schema local (`scripts/ci-db-setup.ts` como app_owner, PG 55432) 2× → idempotente, sem erro.
- [ ] **Step 5:** Commit `feat(back/db): migration 0031 — caixa por dispositivo, updated_at+triggers, sync_mutation`.

### Task A2: Caixa por dispositivo (ponto de caixa)

**Files:**
- Modify: `back/src/modules/cashier/dto/session.dto.ts` (`deviceId?` `@IsUUID() @IsOptional()` em OpenSessionDto e CloseSessionDto)
- Modify: `back/src/modules/cashier/cashier.repository.ts` (`findOpenSession(deviceId?: string | null)` → `WHERE status='open' AND device_id IS NOT DISTINCT FROM $1`; `createSession` grava `device_id`)
- Modify: `back/src/modules/cashier/cashier.service.impl.ts` (`openSession`/`closeSession`/`getCurrentSession`/`createEntry` resolvem sessão pelo `deviceId` recebido)
- Modify: `back/src/modules/cashier/cashier.controller.ts` (`GET current?deviceId=` + dtos)
- Test: `back/test/cashier.e2e-spec.ts` (novos casos)

**Interfaces:**
- Consumes: índice `uq_cash_session_open_device` (A1).
- Produces: `openSession(user, dto{deviceId?})`, `getCurrentSession(user, deviceId?)`, `createEntry(user, dto{deviceId?})` — sessão sempre resolvida por `(tenant, deviceId)`; `deviceId` ausente = ponto legado (NULL).

- [ ] **Step 1:** Escrever e2e falhando: dois owners de devices distintos abrem 2 sessões no mesmo tenant (`POST /api/cashier/sessions` com `deviceId` A e B → ambos 201); reabrir no mesmo device → 409; `GET /api/cashier/sessions/current?deviceId=A` devolve a sessão A; entry com `deviceId` A cai na sessão A.
- [ ] **Step 2:** Rodar e2e → falha (409 na segunda sessão).
- [ ] **Step 3:** Implementar (dto → service → repo; `IS NOT DISTINCT FROM` para cobrir NULL; `createEntry` valida "não há caixa aberto **neste ponto**" em PT-BR).
- [ ] **Step 4:** e2e do cashier inteiro verde + `back:lint` 0 warnings.
- [ ] **Step 5:** Commit `feat(back/cashier): sessão de caixa por dispositivo (ponto de caixa)`.

### Task A3: create-with-id (replay preserva UUID offline)

**Files:**
- Modify: dtos de create — `back/src/modules/customers/dto/*.ts` (customer, subject), `back/src/modules/inventory/dto/*.ts` (item), `back/src/modules/os/dto/*.ts` (order, order item), `back/src/modules/cashier/dto/session.dto.ts` + `entry.dto.ts`: campo `id?: string` `@IsUUID() @IsOptional()`.
- Modify: repositories correspondentes: quando `dto.id` presente, incluir `id: dto.id` no `data` do create (INSERT puro — unique violation sobe como erro; **não** usar upsert — S9).
- Test: 1 caso e2e por módulo (criar com id fornecido → GET devolve o mesmo id; repetir o create → 409/erro de conflito).

**Interfaces:**
- Produces: todos os creates dos 4 módulos aceitam `id` uuid opcional.

- [ ] **Step 1:** e2e falhando (customers: `POST /api/customers` com `id` fixo → resposta `id` igual; repetido → erro).
- [ ] **Step 2:** Implementar nos 4 módulos; mapear `P2002` para `ConflictException('Registro já existe (id duplicado).')` no caminho do create quando `dto.id` veio preenchido.
- [ ] **Step 3:** e2e verde; commit `feat(back): creates aceitam id opcional (replay offline preserva uuid)`.

### Task A4: `listChangedSince` nos services donos

**Files:**
- Modify: `customers.repository.ts`/`customers.service.ts`; `inventory.repository.ts`/`inventory.service.ts`; `os.repository.ts`/`os.service.ts`; `cashier.repository.ts`/`cashier.service.impl.ts` (e contrato em `cashier.service.ts` se necessário para exposição pública).

**Interfaces:**
- Produces (em cada service dono, roda sob `withTenantTx` internamente):
  `listChangedSince(entity: string, cursor: { ts: string; id: string } | null, limit: number): Promise<{ rows: unknown[]; nextCursor: { ts: string; id: string } | null }>`
  Entidades por módulo — customers: `customer`, `subject`; inventory: `inventory_item`, `stock_movement`; os: `service_order`, `service_order_item`, `service_order_event`, `service_order_photo`, `service_order_template`; cashier: `cash_session`, `cash_entry`.
- Cursor: colunas `(updated_at, id)`; tabelas append-only (`stock_movement`, `service_order_event`, `service_order_photo`) usam `(created_at, id)`. Query padrão (raw, tenant-scoped por RLS):

```sql
SELECT * FROM <tabela>
WHERE (updated_at, id) > ($1::timestamptz, $2::uuid)
ORDER BY updated_at, id
LIMIT $3
```

(sem cursor: `WHERE true`, mesma ordenação; `nextCursor` = última linha da página, `null` se `rows.length < limit`). Serialização: mesma shape JSON que os endpoints de leitura já devolvem (reusar os mappers existentes do módulo; `service_order_photo` devolve só metadados+URL, nunca bytes).

- [ ] **Step 1:** Unit test (jest) de um repo (customers) com prisma mockado não vale a pena — cobrir via e2e do sync (A5). Implementar direto os 4 módulos, um commit por módulo.
- [ ] **Step 2:** `back:lint` 0 warnings; commits `feat(back/<mod>): listChangedSince p/ sync pull`.

### Task A5: Módulo `sync` (pull + push + segurança)

**Files:**
- Create: `back/src/modules/sync/sync.module.ts`, `sync.controller.ts`, `sync.service.ts`, `sync.registry.ts`, `dto/push.dto.ts`, `sync.repository.ts` (tabela `sync_mutation` apenas)
- Modify: `back/src/app.module.ts` (registrar `SyncModule`)
- Test: `back/test/sync.e2e-spec.ts`

**Interfaces:**
- Consumes: `listChangedSince` (A4); services públicos de escrita dos 4 módulos (+ `id` opcional de A3, `deviceId` de A2).
- Produces:
  - `GET /api/sync/changes?entity=<e>&sinceTs=&sinceId=&limit=` → `{ rows, nextCursor, serverTime }` (limit clampado a 500).
  - `POST /api/sync/push` body `{ authorUserId, mutations: [{ clientMutationId, entity, op, payload, clientUpdatedAt }] }` (máx. 100) → `{ results: [{ clientMutationId, status: 'applied'|'discarded'|'error', entityId?, message? }], serverTime }`.

**Registry (`sync.registry.ts`)** — whitelist S7. Shape:

```ts
export interface SyncOpDef {
  dto: ClassConstructor<object>;          // DTO existente do módulo dono
  permission: string;                     // ex.: 'os.write'
  lww?: {                                 // presente em ops de update
    getUpdatedAt: (services: SyncServices, user: AuthUser, payload: any) => Promise<Date | null>;
  };
  apply: (services: SyncServices, user: AuthUser, payload: any) => Promise<{ id?: string }>;
}
export const SYNC_OPS: Record<string, SyncOpDef> = {
  'customer.create': { dto: CreateCustomerDto, permission: 'customer.write',
    apply: (s, u, p) => s.customers.createCustomer(u, p) },
  'customer.update': { dto: UpdateCustomerDto, permission: 'customer.write',
    lww: { getUpdatedAt: (s, u, p) => s.customers.getCustomer(u, p.id).then(c => c?.updated_at ?? null) },
    apply: (s, u, p) => s.customers.updateCustomer(u, p.id, p) },
  // customer.archive/unarchive/delete; subject.*; inventory_item.*;
  // service_order.create/update/changeStatus/addItem/updateItem/deleteItem/createNote/applyTemplate;
  // cash_session.open/close; cash_entry.create/reverse — mesmo padrão.
};
```

Payloads de update carregam `{ id, ...campos }` — o registry separa `id` e valida o resto com o DTO (`plainToInstance` + `validate({ whitelist: true, forbidNonWhitelisted: true })`).

**`sync.service.ts` — push (S1/S2/S7/S8/S9/S10):**

```ts
async push(user: AuthUser, dto: PushDto) {
  if (dto.authorUserId !== user.userId)
    throw new ForbiddenException('Autor do lote não corresponde ao usuário autenticado.'); // S1
  const granted = await this.permissionsOf(user.role);   // mesma query do PermissionsGuard
  const results = [];
  for (const m of dto.mutations) {
    const prior = await this.repo.findMutation(user, m.clientMutationId);   // S8
    if (prior) { results.push(toResult(prior)); continue; }
    const def = SYNC_OPS[`${m.entity}.${m.op}`];
    let status = 'error', entityId, message;
    if (!def) message = 'Operação desconhecida.';                            // S7
    else if (!granted.has(def.permission)) message = 'Sem permissão.';
    else {
      const payload = await this.validatePayload(def.dto, m.payload);       // S7 whitelist
      if (!payload.ok) message = payload.message;
      else {
        const effectiveTs = new Date(Math.min(Date.parse(m.clientUpdatedAt), Date.now())); // S2 clamp
        const current = def.lww ? await def.lww.getUpdatedAt(this.services, user, m.payload) : null;
        if (current && current > effectiveTs) status = 'discarded';         // LWW: servidor ganha
        else {
          try {
            const r = await def.apply(this.services, user, payload.value);  // services já auditam
            status = 'applied'; entityId = r?.id;
            if (current) await this.audit.log(user.tenantId, user.userId, 'sync_overwrite',
              entityId, { clientUpdatedAt: m.clientUpdatedAt, effectiveTs }); // S2 forense
          } catch (e) { message = messageOf(e); }                            // erro não trava a fila
        }
      }
    }
    await this.repo.recordMutation(user, m, { status, entityId, message }); // idempotência
    results.push({ clientMutationId: m.clientMutationId, status, entityId, message });
  }
  return { results, serverTime: new Date().toISOString() };
}
```

Notas de implementação: `permissionsOf` = raw query `role→role_permission→permission` (copiar de `PermissionsGuard`); `findMutation`/`recordMutation` sob `withTenantTx` próprio (RLS); LWW `getUpdatedAt` usa leitura via service (não tabela alheia); retry 1× em `P2002` de **número humano** dentro do apply de `service_order.create` fica no próprio OsService (max+1 → repetir uma vez). PushDto: `@ArrayMaxSize(100)`, `clientMutationId @IsUUID`, `clientUpdatedAt @IsISO8601`, `entity/op @IsString @MaxLength(64)`.

- [ ] **Step 1:** Escrever `sync.e2e-spec.ts` falhando, cobrindo: pull com cursor (cria 3 clientes, pull limit 2 → nextCursor → página 2); push aplica create/update; **idempotência** (reenvio do mesmo lote → mesmos results, sem duplicar); **S1** autor errado → 403; **S2** `clientUpdatedAt` futuro + linha do servidor mais nova → `discarded`; **S7** payload com campo extra → `error`; **S8** mesmo `clientMutationId` de autores diferentes → ambos aplicam; **S9** create com id existente → `error`; **S10** lote de 101 → 400; **isolamento**: tenant B não vê mudanças de A no pull e push de B não toca linha de A.
- [ ] **Step 2:** Rodar → falha (rota inexistente).
- [ ] **Step 3:** Implementar módulo completo + registrar no `app.module.ts`.
- [ ] **Step 4:** e2e verde; `back:test` + `back:lint` verdes.
- [ ] **Step 5:** Commit `feat(back/sync): módulo sync — pull incremental + push idempotente (S1-S10)`.

### Task A6: Evidência backend

- [ ] `npm run back:lint` → 0 warnings (colar output).
- [ ] `npm run back:test` → verde.
- [ ] `npm run back:test:e2e` → verde (FLUSHALL antes, conforme README §6).
- [ ] Commit de ajustes finais se houver.

---

## PART B — Frontend

### Task B1: Dependências + geração

**Files:** Modify `front/pubspec.yaml`.

- [ ] Adicionar: `drift: ^2.28.0`, `sqlite3_flutter_libs: ^0.5.36`, `sqlcipher_flutter_libs: ^0.6.5`, `connectivity_plus: ^7.0.0`, `sodium_libs: ^3.5.0`, `uuid: ^4.5.1`, `path_provider: ^2.1.5`, `path: ^1.9.0`; dev: `drift_dev: ^2.28.0`.
- [ ] `flutter pub get` → resolve sem conflito (se falhar, ajustar versões pela resolução, não travar).
- [ ] Commit `chore(front): deps offline (drift, sqlcipher, connectivity, sodium)`.

### Task B2: Identidade do dispositivo + relógio confiável + ConnectivityController

**Files:**
- Create: `front/lib/core/offline/device_identity.dart` (`DeviceIdentity.deviceId` — uuid v4 persistido em `shared_preferences` chave `orbix_device_id`)
- Create: `front/lib/core/offline/trusted_clock.dart` (`TrustedClock`: `maxSeenTs` persistido; `observe(DateTime serverOrLocal)` guarda o maior; `bool clockRolledBack` — S3)
- Create: `front/lib/core/offline/connectivity_controller.dart` (`ConnectivityController extends Notifier<ConnState>`; `ConnState { ConnStatus status; int pendingCount; int pendingOtherAuthors; }`, `enum ConnStatus { online, offline, syncing }`) — combina stream do `connectivity_plus` + ping `GET /health` via `bareDio` (a cada 30s e nas mudanças) + setters chamados pelo SyncEngine (`markSyncing/markSynced/markOffline`, `setPending`)
- Modify: `front/lib/di.dart` (providers)
- Test: `front/test/connectivity_controller_test.dart`, `front/test/trusted_clock_test.dart`

**Interfaces:**
- Produces: `connectivityControllerProvider` (estado global do indicador); `deviceIdProvider` (`Future<String>`); `trustedClockProvider`.

- [ ] Testes unit primeiro (clock: observe maior/rollback; controller: transições por ping ok/falha) → falham → implementar → verdes.
- [ ] Commit `feat(front/offline): device id, relógio confiável (S3) e ConnectivityController`.

### Task B3: Indicador global (chip + banner)

**Files:**
- Create: `front/lib/core/offline/widgets/connection_chip.dart`, `connection_banner.dart`
- Modify: `front/lib/features/shell/presentation/sidebar.dart` (chip acima do `_UserFooter`), `app_shell.dart` (banner no topo do body; no mobile <600 o estado entra no `_ContentHeader`)
- Test: `front/test/connection_indicator_test.dart` (widget)

**Comportamento:** chip verde "Online" / âmbar "Sincronizando…" / cinza "Offline • N pendentes" (+ tooltip com "M aguardando login de outro usuário" quando aplicável). Banner nas transições: offline → "Você está offline — alterações serão enviadas ao reconectar" (persiste enquanto offline; na web: "Você está offline — o Orbix precisa de conexão no navegador"); volta online+fila zerada → banner some (flash verde 3s "Conexão restabelecida — dados sincronizados"). Cores dos tokens de `AppColors` (sem hardcode fora do tema).

- [ ] Widget test (forçando estados via override do provider) → implementar → verde → commit `feat(front/shell): indicador de conexão (chip + banner)`.

### Task B4: deviceId no caixa (front)

**Files:** Modify `front/lib/features/cashier/data/cashier_repository_impl.dart` (+ fake), `cashier_providers.dart` — `openSession`/`currentSession`/`closeSession`/`createEntry` enviam `deviceId` (de `DeviceIdentity`).

- [ ] Ajustar impl+fake+testes existentes → `flutter test` verde → commit `feat(front/cashier): sessão por ponto de caixa (deviceId)`.

### Task B5: Banco local drift (row-store) + chave SQLCipher

**Files:**
- Create: `front/lib/core/offline/db/local_db.dart` (drift schema + open)
- Create: `front/lib/core/offline/db/db_key_store.dart` (chave por dispositivo no `FlutterSecureStorage`, chave `orbix_db_key`, gerada uma vez com 32 bytes aleatórios seguros)
- Test: `front/test/local_db_test.dart` (usa `NativeDatabase.memory()`)

**Schema (row-store genérico — o payload é o MESMO JSON da API):**

```dart
class EntityRows extends Table {           // espelho de todas as entidades do pull
  TextColumn get entity => text()();      // 'customer', 'service_order', ...
  TextColumn get id => text()();
  TextColumn get payload => text()();     // json cru da API
  DateTimeColumn get updatedAt => dateTime()();
  @override Set<Column> get primaryKey => {entity, id};
}
class Outbox extends Table {
  TextColumn get clientMutationId => text()();
  TextColumn get authorUserId => text()();   // S1
  TextColumn get entity => text()();
  TextColumn get op => text()();
  TextColumn get payload => text()();
  DateTimeColumn get clientUpdatedAt => dateTime()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending|applied|discarded|failed
  TextColumn get message => text().nullable()();
  IntColumn get seq => integer().autoIncrement()();      // ordem de aplicação
}
class SyncState extends Table {            // cursor por entidade
  TextColumn get entity => text()();
  TextColumn get cursorTs => text().nullable()();
  TextColumn get cursorId => text().nullable()();
  @override Set<Column> get primaryKey => {entity};
}
class PendingUploads extends Table {       // S6: bytes DENTRO do banco cifrado
  TextColumn get id => text()();
  TextColumn get orderId => text()();
  BlobColumn get bytes => blob()();
  TextColumn get filename => text()();
  TextColumn get contentType => text()();
  TextColumn get caption => text().nullable()();
  @override Set<Column> get primaryKey => {id};
}
```

Abertura: um arquivo por tenant `orbix_<tenantId>.db` em `path_provider` app-support dir; `NativeDatabase.createInBackground(file, setup: (db) => db.execute("PRAGMA key = '<hex>'"))` (SQLCipher via `sqlcipher_flutter_libs`; `import 'package:sqlcipher_flutter_libs/...'` + `open.overrideFor` conforme README do pacote). API do wrapper: `LocalDb.forTenant(tenantId)` com `upsertRows(entity, rows)`, `rowsOf(entity)`, `enqueue(mutation)`, `pendingFor(authorId)`, `cursorFor/saveCursor`, `deleteDbForTenant(tenantId)` (S5).

- [ ] Testes (upsert/rowsOf/enqueue/cursor em memória) → implementar → verdes → commit `feat(front/offline): banco local drift + SQLCipher (row-store, outbox, cursores)`.

### Task B6: Login offline

**Files:**
- Create: `front/lib/core/offline/offline_credentials.dart` (`OfflineCredentialsStore` — arquivo device-scoped `orbix_device.db` (mesmo wrapper drift, tabela própria): `email`, `userId`, `passwordHash` (argon2id, salt por dispositivo), `meSnapshot` json, `lastOnlineLoginAt` (hora do servidor), `failedAttempts`, `lockedUntil`)
- Create: `front/lib/core/offline/password_hasher.dart` (`PasswordHasher.hash/verify` via `sodium_libs` `crypto.pwhash` — argon2id, `opsLimit=3`, `memLimit=64MB`)
- Modify: `front/lib/features/auth/presentation/session_state.dart` (+ `SessionState.offline(Me me)`)
- Modify: `front/lib/features/auth/presentation/session_controller.dart`:
  - login online OK → salvar credencial + snapshot `/me` + `lastOnlineLoginAt` (do header/`serverTime`) + `TrustedClock.observe`;
  - `login()` com falha de REDE (não 401) → tentar `loginOffline(email, password)`: verifica hash, S3 (`clockRolledBack` → expirado), 7 dias, backoff (5 falhas → `lockedUntil` exponencial) → `SessionState.offline(meSnapshot)`;
  - `_bootstrap()` offline: refresh falhou por rede + existe snapshot válido → **não** vai para `unauthenticated`, vai para tela de login com aviso offline;
  - reconexão (ouvindo `connectivityControllerProvider`): tenta refresh real e migra `offline → authenticated`;
  - S5: `/me` sem a membership do tenant → `LocalDb.deleteDbForTenant` + remover credencial.
- Modify: `front/lib/features/auth/presentation/login_screen.dart` (aviso âmbar "Sem conexão — entrando no modo offline" quando aplicável; erro PT-BR de credencial offline expirada)
- Modify: `front/lib/di.dart`
- Test: `front/test/offline_login_test.dart`

**Regras:** hash NUNCA sai do dispositivo; senha nunca persistida; modo offline só `!kIsWeb`; sessão offline não dispara chamadas dio (repos LocalFirst leem só local; guards de rota tratam `SessionState.offline` como autenticado para os 4 módulos e bloqueiam os online-only).

- [ ] Testes: login online salva credencial; offline com senha certa → `SessionState.offline`; senha errada 5× → lock; >7 dias → expirado; relógio voltado → expirado (S3); membership revogada → wipe (S5). → implementar → verdes.
- [ ] Commit `feat(front/auth): login offline (argon2id local, 7 dias, S3/S4/S5)`.

### Task B7: SyncEngine + outbox

**Files:**
- Create: `front/lib/core/offline/sync_engine.dart`
- Create: `front/lib/core/offline/sync_api.dart` (dio: `GET /sync/changes`, `POST /sync/push` — tipos `SyncPushResult` etc.)
- Modify: `front/lib/di.dart`
- Test: `front/test/sync_engine_test.dart` (com fakes de SyncApi/LocalDb)

**Comportamento:**
- Disparo: ao ficar online (listener do ConnectivityController), a cada 60s online, e após cada escrita local.
- Ordem: **push → pull**. Push: mutações `pending` do **autor da sessão atual** (S1), em lotes de ≤100, ordem por `seq`; resultado marca `applied|discarded|failed` no outbox; `discarded/failed` mantêm registro para exibição; `serverTime` → `TrustedClock.observe`.
- Pull: para cada entidade (lista fixa das 11 da spec), loop `changes(entity, cursor)` até `nextCursor == null`, `upsertRows` + salvar cursor.
- Fotos: após push com sucesso da OS correspondente, subir `PendingUploads` via repo de files existente (`addPhoto` do OsRepository real); sucesso → apagar blob.
- Estados: `markSyncing` no início, `markSynced/pendingCount` ao fim; erro de rede no meio → `markOffline`, mantém fila.

- [ ] Testes (push idempotente marca status; pull pagina e salva cursor; push só do autor atual) → implementar → verdes → commit `feat(front/offline): SyncEngine (push→pull, fotos, autoria S1)`.

### Task B8: Repositories LocalFirst (4 módulos)

**Files:**
- Create: `front/lib/features/customers/data/local_first_customers_repository.dart` (referência completa)
- Create: `front/lib/features/inventory/data/local_first_inventory_repository.dart`
- Create: `front/lib/features/os/data/local_first_os_repository.dart`
- Create: `front/lib/features/cashier/data/local_first_cashier_repository.dart`
- Modify: `front/lib/di.dart` (decorar os providers com LocalFirst quando `!kIsWeb`)
- Test: `front/test/local_first_customers_test.dart` (+ 1 por módulo com os casos críticos)

**Padrão (decorator sobre a impl dio; referência = customers):**
- **Leitura:** online → chama a impl real, grava o resultado no row-store, devolve; offline → monta do row-store (`rowsOf('customer')` → `Customer.fromJson`), aplica filtro/busca/paginação em Dart.
- **Escrita:** gera uuid quando create; monta o payload JSON (mesma shape do dto da API + `id`); aplica **otimista** no row-store local; `enqueue` no outbox (`authorUserId` da sessão — S1; `clientUpdatedAt = TrustedClock.now`); se online, cutuca o SyncEngine. Retorno = modelo montado localmente.
- **Específicos:** OS create offline → `number: 'OS-P<seq>'` (contador local; badge "pendente de envio"); fotos → blob em `PendingUploads` + evento local; `lookup` FIPE/EAN offline → `throw AppException('Requer conexão', ...)` (a UI trata — B9); cashier segue `deviceId` (B4); templates ficam no row-store (pull) e `applyTemplate` offline monta itens localmente a partir do template espelhado.
- Métodos intrinsecamente online (ex.: `emitInvoice`, `listPhotoComments`, `addPhotoComment`, `subjectHistory`) → offline lançam `AppException('Requer conexão')`.

- [ ] Testes (offline: create/list/update no local + outbox cresce; online: passthrough + espelho atualizado; OS número provisório) → implementar módulo a módulo, 1 commit cada: `feat(front/<mod>): repository LocalFirst`.

### Task B9: UX offline nas telas

**Files:**
- Modify: `front/lib/features/os/presentation/os_detail_screen.dart` — quando `ConnState.status == offline`: texto vermelho (token de erro do tema) "⚠ Será enviado ao sistema quando a conexão voltar" nas seções `_PhotosSection`, `_DiagnosisSection`, `_TimelineSection` (notas) e no `OrderEditDialog` (responsável/datas); botão do link de acompanhamento e `_IssueInvoiceButton` desabilitados com tooltip "Requer conexão".
- Modify: `front/lib/features/os/presentation/os_list_screen.dart` — badge "pendente de envio" nos registros com número provisório `OS-P...`.
- Modify: `front/lib/features/cashier/presentation/cashier_screen.dart` — aviso permanente offline: "Os lançamentos só serão efetivados no sistema quando a conexão voltar" (banner interno da tela).
- Modify: `front/lib/features/inventory/presentation/item_form_dialog.dart` — lookup EAN offline: mensagem "Você está offline — a consulta automática por código de barras não está disponível. Preencha os dados manualmente." (o botão de lookup desabilita).
- Modify: `front/lib/features/customers/presentation/subject_form_dialog.dart` — offline: cascata FIPE vira campos de texto livre com hint "Sem conexão — digite manualmente".
- Modify: telas online-only (`messages`, `notifications`, `report`, `invoice`, `team`, `settings`, `sale`): estado vazio "Requer conexão" quando offline (widget compartilhado `RequiresConnectionView` em `front/lib/core/offline/widgets/`).
- Test: `front/test/offline_ux_test.dart` (widget: avisos aparecem quando offline).

- [ ] Widget tests → implementar → verdes → commit `feat(front): UX offline (avisos vermelhos, requer conexão, badges)`.

### Task B10: Evidência frontend + design pass

- [ ] `flutter analyze` → "No issues found!".
- [ ] `flutter test` → verde (todos).
- [ ] Build web release + servir (tmp-pw/serve.mjs:8090) + **Playwright**: capturar o indicador nos 3 estados (forçados via dev-tools) e iterar o design contra o tema (grafite+tangerina) até ficar consistente; validar banner e avisos vermelhos visualmente.
- [ ] Atualizar `docs/modulos-v1.md` (offline implementado) + `docs/configuracao.md` se aplicável.
- [ ] Commit final `docs: offline-first implementado`.

---

## Self-review (feito na escrita)

- Cobertura da spec: Bloco 1 → B5/B6; Bloco 2 → A1–A5/B7/B8; Bloco 3 → B2/B3/B9; migration → A1; S1 (A5, B7, B8) S2 (A5) S3 (B2, B6) S4 (B6) S5 (B6) S6 (B5) S7 (A5) S8 (A1, A5) S9 (A3, A5) S10 (A5); caixa por dispositivo → A2/B4; numeração provisória → B8 + retry no OsService (A5 nota); web online-only → B3/B6/B8 (`!kIsWeb`).
- Riscos conhecidos: versões de pacote em B1 podem precisar de ajuste na resolução (`flutter pub get` decide); `sodium_libs` exige inicialização async (fazer no bootstrap do app); e2e de sync depende do ambiente PG local.
