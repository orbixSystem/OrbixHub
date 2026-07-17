# NF — Plano 2: Classificação Fiscal (inventory + invoice_line) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Dar aos itens de estoque a classificação fiscal necessária para emitir NF (produto: NCM, CFOP, origem, GTIN; serviço: código do serviço LC116, alíquota ISS) e adicionar as colunas de snapshot fiscal em `invoice_line` (preenchidas no Plano 3). Não emite nota — só modela e captura os dados.

**Architecture:** Campos fiscais viram colunas de primeira classe em `inventory_item` (não `attributes`), gated por `kind` (produto vs serviço). `invoice_line` ganha colunas de snapshot nullable, plumbadas em `InvoiceLineData`/`createWithLines` mas ainda não preenchidas (o Plano 3 as preenche lendo o item via `InventoryService`). Tudo aditivo, RLS intacta.

**Tech Stack:** NestJS 10 · Prisma 5 · Postgres 16 (RLS) · class-validator (DTOs) · Jest+Supertest · Flutter/Riverpod 3 · freezed.

## Global Constraints

- **Migrations ADITIVAS nos 3 lugares:** `back/sql/auth-multitenant-schema.sql` (baseline) + `back/prisma/migrations/NNNN_*/migration.sql` + `back/prisma/schema.prisma` (à mão). Colunas novas **nullable**. Próximo número após `0031` = `0032`.
- **Aplicar migration localmente = rodar SÓ o SQL da migration via psql** (o baseline NÃO é re-executável em DB populado — `CREATE TABLE tenant` sem IF NOT EXISTS). Comando psql: `"/c/Program Files/RedHat/Podman/podman.exe" exec orbix-postgres psql -U app_owner -d orbixhub -c "<SQL>"`. Depois `npm run prisma:generate --workspace back`.
- **RLS intacta:** não alterar policies; colunas herdam a RLS da tabela. Acesso via `TenantContext.getClient()` (repos).
- **DTO whitelist:** o `ValidationPipe({whitelist,forbidNonWhitelisted,transform})` é global — todo campo novo DEVE entrar no DTO ou o request leva 400. DTOs em **camelCase**; colunas em **snake_case**.
- **`kind` é imutável** (só existe no Create DTO). Produto e serviço têm grupos fiscais distintos; o service zera o grupo que não se aplica.
- **Sem hard delete. Strings de usuário em PT-BR.** Qualidade: `npm run back:lint` 0 warnings + testes; `flutter analyze` 0 issues + `flutter test`.
- **Front (Flutter):** binário em `C:\flutter\bin\flutter.bat` (não no PATH; use a ferramenta PowerShell). Pacote Dart = `orbixhub_front`.

## File Structure

**Backend (modificar):**
- `back/sql/auth-multitenant-schema.sql` — ALTERs idempotentes em `inventory_item` (~L596-608) e `invoice_line` (~L1197).
- `back/prisma/schema.prisma` — models `inventory_item` (L68-95) e `invoice_line` (L635-648).
- `back/src/modules/inventory/dto/item.dto.ts` — campos fiscais nos Create/Update DTOs.
- `back/src/modules/inventory/inventory.repository.ts` — interface `ItemData` (L49-65).
- `back/src/modules/inventory/inventory.service.ts` — mapping em `createItem` (L117-134) e `updateItem` (L209-228).
- `back/src/modules/invoice/invoice.repository.ts` — `InvoiceLineData` (L7-13) + `createWithLines` map (L50-67).
- `back/test/inventory.e2e-spec.ts` — estender o bloco product/service (L415-454).

**Backend (criar):**
- `back/prisma/migrations/0032_inventory_fiscal_fields/migration.sql`
- `back/prisma/migrations/0033_invoice_line_fiscal_snapshot/migration.sql`

**Frontend (modificar):**
- `front/lib/features/inventory/domain/inventory_models.dart` — `InventoryItem` (read) + `ItemDraft` (write/toJson).
- `front/lib/features/inventory/presentation/item_form_dialog.dart` — controllers + campos + `_save`.

---

## Task 1: Colunas fiscais em `inventory_item` (3 lugares + aplicar + generate)

**Files:**
- Modify: `back/sql/auth-multitenant-schema.sql` (após os ALTER de `inventory_item`, ~L608, antes dos índices)
- Create: `back/prisma/migrations/0032_inventory_fiscal_fields/migration.sql`
- Modify: `back/prisma/schema.prisma` (model `inventory_item`)

**Interfaces:**
- Produces (colunas novas, todas nullable): `inventory_item.ncm text`, `cfop text`, `origem text`, `gtin text`, `codigo_servico text`, `aliquota_iss numeric(7,2)`.

- [ ] **Step 1: SQL aditivo no baseline**

Em `back/sql/auth-multitenant-schema.sql`, logo após os ALTER existentes de `inventory_item` (perto de `duration_minutes`, ~L604) e antes dos índices:

```sql
-- Classificação fiscal (produto: ncm/cfop/origem/gtin; serviço: codigo_servico/aliquota_iss)
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS ncm            text;
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS cfop           text;
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS origem         text;
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS gtin           text;
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS codigo_servico text;
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS aliquota_iss   numeric(7,2);
```

- [ ] **Step 2: Migration 0032**

Criar `back/prisma/migrations/0032_inventory_fiscal_fields/migration.sql` com o MESMO SQL do Step 1 (mais um cabeçalho de 1 linha `-- 0032 — classificação fiscal em inventory_item (aditivo)`).

- [ ] **Step 3: Prisma model**

Em `back/prisma/schema.prisma`, no model `inventory_item` (após `duration_minutes`):

```prisma
  ncm               String?
  cfop              String?
  origem            String?
  gtin              String?
  codigo_servico    String?
  aliquota_iss      Decimal? @db.Decimal(7, 2)
```

- [ ] **Step 4: Aplicar SÓ a migration no DB local + generate**

Run (aplica o fragmento — NÃO rodar ci-db-setup):
```bash
"/c/Program Files/RedHat/Podman/podman.exe" exec orbix-postgres psql -U app_owner -d orbixhub -c "ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS ncm text; ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS cfop text; ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS origem text; ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS gtin text; ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS codigo_servico text; ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS aliquota_iss numeric(7,2);"
```
Run: `npm run prisma:generate --workspace back`
Verify columns:
```bash
"/c/Program Files/RedHat/Podman/podman.exe" exec orbix-postgres psql -U app_owner -d orbixhub -c "SELECT column_name FROM information_schema.columns WHERE table_name='inventory_item' AND column_name IN ('ncm','cfop','origem','gtin','codigo_servico','aliquota_iss') ORDER BY column_name;"
```
Expected: 6 rows.

- [ ] **Step 5: Build (confirma o client regenerado compila)**

Run: `npm run build --workspace back`
Expected: sem erros.

- [ ] **Step 6: Commit**

```bash
git add back/sql/auth-multitenant-schema.sql back/prisma/migrations/0032_inventory_fiscal_fields/migration.sql back/prisma/schema.prisma
git commit -m "feat(inventory): colunas de classificação fiscal (ncm/cfop/origem/gtin/codigo_servico/aliquota_iss)"
```

---

## Task 2: DTO + service + repository — persistir a classificação fiscal (com e2e)

**Files:**
- Modify: `back/src/modules/inventory/dto/item.dto.ts`
- Modify: `back/src/modules/inventory/inventory.repository.ts` (interface `ItemData`)
- Modify: `back/src/modules/inventory/inventory.service.ts` (`createItem`, `updateItem`)
- Modify: `back/test/inventory.e2e-spec.ts`

**Interfaces:**
- Consumes: colunas da Task 1.
- Produces: Create/Update DTOs aceitam `ncm?, cfop?, origem?, gtin?, codigoServico?, aliquotaIss?` (camelCase); persistidos gated por `kind` (produto recebe ncm/cfop/origem/gtin; serviço recebe codigo_servico/aliquota_iss; o grupo que não se aplica fica null).

- [ ] **Step 1: e2e que falha (estende o bloco product/service ~L415-454)**

Em `back/test/inventory.e2e-spec.ts`, adicionar casos (usando o helper `createItem(access, body)` existente):

```ts
it('persiste classificação fiscal de produto e ignora campos de serviço', async () => {
  const res = await createItem(owner.access, {
    name: 'Óleo 5W30', kind: 'product',
    ncm: '27101259', cfop: '5102', origem: '0', gtin: '7891234567895',
    codigoServico: '14.01', aliquotaIss: 5, // devem ser ignorados p/ produto
  });
  expect(res.status).toBe(201);
  expect(res.body.ncm).toBe('27101259');
  expect(res.body.cfop).toBe('5102');
  expect(res.body.origem).toBe('0');
  expect(res.body.gtin).toBe('7891234567895');
  expect(res.body.codigo_servico).toBeNull();
  expect(res.body.aliquota_iss).toBeNull();
});

it('persiste classificação fiscal de serviço e ignora campos de produto', async () => {
  const res = await createItem(owner.access, {
    name: 'Troca de óleo', kind: 'service', durationMinutes: 30,
    codigoServico: '14.01', aliquotaIss: 5,
    ncm: '27101259', cfop: '5102', // devem ser ignorados p/ serviço
  });
  expect(res.status).toBe(201);
  expect(res.body.codigo_servico).toBe('14.01');
  expect(String(res.body.aliquota_iss)).toBe('5.00');
  expect(res.body.ncm).toBeNull();
  expect(res.body.cfop).toBeNull();
});

it('rejeita campo fiscal fora do whitelist do DTO', async () => {
  const res = await createItem(owner.access, { name: 'x', foo_fiscal: '1' });
  expect(res.status).toBe(400);
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `"/c/Program Files/RedHat/Podman/podman.exe" exec orbix-redis redis-cli FLUSHALL && npm run back:test:e2e -- inventory`
Expected: FAIL (campos fiscais viram 400 por `forbidNonWhitelisted`, ou vêm null).

- [ ] **Step 3: DTO — adicionar campos fiscais (Create e Update)**

Em `back/src/modules/inventory/dto/item.dto.ts`, adicionar a AMBOS `CreateInventoryItemDto` e `UpdateInventoryItemDto`:

```ts
  @IsOptional() @IsString() @MaxLength(8)
  ncm?: string;

  @IsOptional() @IsString() @MaxLength(4)
  cfop?: string;

  @IsOptional() @IsString() @MaxLength(1)
  origem?: string;

  @IsOptional() @IsString() @MaxLength(14)
  gtin?: string;

  @IsOptional() @IsString() @MaxLength(10)
  codigoServico?: string;

  @IsOptional() @IsNumber() @Min(0) @Max(100)
  aliquotaIss?: number;
```
(Garantir que `IsNumber`, `Min`, `Max`, `IsString`, `MaxLength`, `IsOptional` já estão importados de `class-validator` — adicionar `Max` se faltar.)

- [ ] **Step 4: Repository `ItemData`**

Em `back/src/modules/inventory/inventory.repository.ts`, estender a interface `ItemData` (L49-65) com (snake_case, opcionais):

```ts
  ncm?: string | null;
  cfop?: string | null;
  origem?: string | null;
  gtin?: string | null;
  codigo_servico?: string | null;
  aliquota_iss?: number | null;
```
(create/update já fazem `...data` — nenhuma mudança de método necessária.)

- [ ] **Step 5: Service — mapear gated por kind**

Em `createItem` (bloco `data`, ~L117-134), adicionar (usa o `isService` já calculado e o helper `trimOrNull`):

```ts
      ncm: isService ? null : trimOrNull(dto.ncm),
      cfop: isService ? null : trimOrNull(dto.cfop),
      origem: isService ? null : trimOrNull(dto.origem),
      gtin: isService ? null : trimOrNull(dto.gtin),
      codigo_servico: isService ? trimOrNull(dto.codigoServico) : null,
      aliquota_iss: isService ? (dto.aliquotaIss ?? null) : null,
```

Em `updateItem` (bloco incremental `if (dto.X !== undefined)`, ~L209-228), adicionar (respeitando `isService` do item existente):

```ts
    if (!isService) {
      if (dto.ncm !== undefined) data.ncm = trimOrNull(dto.ncm);
      if (dto.cfop !== undefined) data.cfop = trimOrNull(dto.cfop);
      if (dto.origem !== undefined) data.origem = trimOrNull(dto.origem);
      if (dto.gtin !== undefined) data.gtin = trimOrNull(dto.gtin);
    } else {
      if (dto.codigoServico !== undefined) data.codigo_servico = trimOrNull(dto.codigoServico);
      if (dto.aliquotaIss !== undefined) data.aliquota_iss = dto.aliquotaIss ?? null;
    }
```

- [ ] **Step 6: Rodar e2e e ver passar**

Run: `"/c/Program Files/RedHat/Podman/podman.exe" exec orbix-redis redis-cli FLUSHALL && npm run back:test:e2e -- inventory`
Expected: PASS (todos, incl. os 3 novos).

- [ ] **Step 7: Lint + commit**

Run: `npm run back:lint`
```bash
git add back/src/modules/inventory/ back/test/inventory.e2e-spec.ts
git commit -m "feat(inventory): DTO+service persistem classificação fiscal gated por kind"
```

---

## Task 3: Snapshot fiscal em `invoice_line` (colunas + plumbing, nullable)

**Files:**
- Modify: `back/sql/auth-multitenant-schema.sql` (`invoice_line`, ~L1197)
- Create: `back/prisma/migrations/0033_invoice_line_fiscal_snapshot/migration.sql`
- Modify: `back/prisma/schema.prisma` (model `invoice_line`)
- Modify: `back/src/modules/invoice/invoice.repository.ts` (`InvoiceLineData` + `createWithLines`)

**Interfaces:**
- Produces (nullable): `invoice_line.ncm text`, `cfop text`, `unidade text`, `gtin text`, `codigo_servico text`. `InvoiceLineData` ganha esses campos opcionais; `createWithLines` os grava (null quando ausente). **Não preenchidos ainda** — o Plano 3 os popula via `InventoryService`.

- [ ] **Step 1: SQL aditivo no baseline**

Em `back/sql/auth-multitenant-schema.sql`, após o CREATE TABLE de `invoice_line` (~L1198) e antes do índice:

```sql
ALTER TABLE invoice_line ADD COLUMN IF NOT EXISTS ncm            text;
ALTER TABLE invoice_line ADD COLUMN IF NOT EXISTS cfop           text;
ALTER TABLE invoice_line ADD COLUMN IF NOT EXISTS unidade        text;
ALTER TABLE invoice_line ADD COLUMN IF NOT EXISTS gtin           text;
ALTER TABLE invoice_line ADD COLUMN IF NOT EXISTS codigo_servico text;
```

- [ ] **Step 2: Migration 0033** — `back/prisma/migrations/0033_invoice_line_fiscal_snapshot/migration.sql` com o mesmo SQL (+cabeçalho de 1 linha).

- [ ] **Step 3: Prisma model** — no model `invoice_line` (após `total`):

```prisma
  ncm            String?
  cfop           String?
  unidade        String?
  gtin           String?
  codigo_servico String?
```

- [ ] **Step 4: Aplicar SÓ a migration no DB local + generate**

Run:
```bash
"/c/Program Files/RedHat/Podman/podman.exe" exec orbix-postgres psql -U app_owner -d orbixhub -c "ALTER TABLE invoice_line ADD COLUMN IF NOT EXISTS ncm text; ALTER TABLE invoice_line ADD COLUMN IF NOT EXISTS cfop text; ALTER TABLE invoice_line ADD COLUMN IF NOT EXISTS unidade text; ALTER TABLE invoice_line ADD COLUMN IF NOT EXISTS gtin text; ALTER TABLE invoice_line ADD COLUMN IF NOT EXISTS codigo_servico text;"
```
Run: `npm run prisma:generate --workspace back`
Verify: `... psql ... -c "SELECT column_name FROM information_schema.columns WHERE table_name='invoice_line' AND column_name IN ('ncm','cfop','unidade','gtin','codigo_servico') ORDER BY column_name;"` → 5 rows.

- [ ] **Step 5: `InvoiceLineData` + `createWithLines`**

Em `back/src/modules/invoice/invoice.repository.ts`, estender `InvoiceLineData` (L7-13):

```ts
  ncm?: string | null;
  cfop?: string | null;
  unidade?: string | null;
  gtin?: string | null;
  codigo_servico?: string | null;
```
E no `.map()` de `createWithLines` (L57-64), adicionar dentro do objeto criado:

```ts
          ncm: l.ncm ?? null,
          cfop: l.cfop ?? null,
          unidade: l.unidade ?? null,
          gtin: l.gtin ?? null,
          codigo_servico: l.codigo_servico ?? null,
```
(O `toLine` em `invoice.service.ts` NÃO muda nesta task — os campos ficam null até o Plano 3.)

- [ ] **Step 6: Regressão — invoice e2e ainda verde**

Run: `"/c/Program Files/RedHat/Podman/podman.exe" exec orbix-redis redis-cli FLUSHALL && npm run back:test:e2e -- invoice`
Expected: PASS (linhas ainda criadas; novas colunas null). Depois `npm run back:lint` (0 warnings) e `npm run build --workspace back`.

- [ ] **Step 7: Commit**

```bash
git add back/sql/auth-multitenant-schema.sql back/prisma/migrations/0033_invoice_line_fiscal_snapshot/migration.sql back/prisma/schema.prisma back/src/modules/invoice/invoice.repository.ts
git commit -m "feat(invoice): colunas de snapshot fiscal em invoice_line (nullable, preenchidas no Plano 3)"
```

---

## Task 4: Front — campos fiscais no cadastro de item

**Files:**
- Modify: `front/lib/features/inventory/domain/inventory_models.dart` (`InventoryItem` + `ItemDraft`)
- Modify: `front/lib/features/inventory/presentation/item_form_dialog.dart`
- Test: `front/test/inventory_fiscal_test.dart` (novo)

**Interfaces:**
- Consumes: endpoints `POST/PATCH /inventory/items` (ItemDraft.toJson camelCase); GET item retorna colunas snake_case.
- Produces: `InventoryItem` lê `ncm/cfop/origem/gtin/codigoServico/aliquotaIss`; `ItemDraft` escreve os mesmos; form mostra os campos condicionalmente (produto vs serviço).

- [ ] **Step 1: Teste que falha (ItemDraft.toJson inclui campos fiscais)**

`front/test/inventory_fiscal_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub_front/features/inventory/domain/inventory_models.dart';

void main() {
  test('ItemDraft de produto serializa campos fiscais de produto', () {
    final json = ItemDraft(name: 'Óleo', kind: 'product', ncm: '27101259', cfop: '5102', origem: '0', gtin: '7891234567895').toJson();
    expect(json['ncm'], '27101259');
    expect(json['cfop'], '5102');
    expect(json['origem'], '0');
    expect(json['gtin'], '7891234567895');
  });

  test('ItemDraft de serviço serializa código do serviço e ISS', () {
    final json = ItemDraft(name: 'Troca', kind: 'service', codigoServico: '14.01', aliquotaIss: 5).toJson();
    expect(json['codigoServico'], '14.01');
    expect(json['aliquotaIss'], 5);
  });

  test('InventoryItem lê classificação fiscal do JSON (snake_case)', () {
    final item = InventoryItem.fromJson({
      'id': '1', 'name': 'Óleo', 'kind': 'product',
      'ncm': '27101259', 'cfop': '5102', 'origem': '0', 'gtin': '789',
      'codigo_servico': null, 'aliquota_iss': null,
    });
    expect(item.ncm, '27101259');
    expect(item.cfop, '5102');
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run (PowerShell): `Set-Location C:\Project\OrbixHub\front; & "C:\flutter\bin\flutter.bat" test test/inventory_fiscal_test.dart`
Expected: FAIL (campos inexistentes).

- [ ] **Step 3: `InventoryItem` (read) — novos campos**

Em `front/lib/features/inventory/domain/inventory_models.dart`, no `InventoryItem` freezed, adicionar:

```dart
    String? ncm,
    String? cfop,
    String? origem,
    String? gtin,
    @JsonKey(name: 'codigo_servico') String? codigoServico,
    @JsonKey(name: 'aliquota_iss') String? aliquotaIss,
```
(`aliquota_iss` chega como String — decimal serializado, igual aos preços.)

- [ ] **Step 4: `ItemDraft` (write) — novos campos + toJson**

No `ItemDraft` (classe simples), adicionar os campos ao construtor e ao `toJson()` (camelCase, só não-nulos):

```dart
    if (ncm != null) 'ncm': ncm,
    if (cfop != null) 'cfop': cfop,
    if (origem != null) 'origem': origem,
    if (gtin != null) 'gtin': gtin,
    if (codigoServico != null) 'codigoServico': codigoServico,
    if (aliquotaIss != null) 'aliquotaIss': aliquotaIss,
```
Campos: `final String? ncm, cfop, origem, gtin, codigoServico; final double? aliquotaIss;`.

- [ ] **Step 5: Codegen + teste passar**

Run: `& "C:\flutter\bin\flutter.bat" pub run build_runner build --delete-conflicting-outputs`
Run: `& "C:\flutter\bin\flutter.bat" test test/inventory_fiscal_test.dart` → PASS.

- [ ] **Step 6: Form — campos condicionais**

Em `item_form_dialog.dart`: adicionar `TextEditingController` para ncm/cfop/origem/gtin (produto) e codigoServico/aliquotaIss (serviço) — init em `initState` a partir de `widget.existing` (usando os getters do `InventoryItem`), dispose em `dispose`. Adicionar uma seção "Fiscal" com os campos no `_productForm` (NCM, CFOP, origem, GTIN) e no `_serviceForm` (Código do serviço LC116, Alíquota ISS %). No `_save`, incluir no `ItemDraft` gated por `isService` (produto → ncm/cfop/origem/gtin; serviço → codigoServico/aliquotaIss). Rótulos/hints em PT-BR; responsivo (seguir o layout de linhas existente).

- [ ] **Step 7: analyze + test**

Run: `& "C:\flutter\bin\flutter.bat" analyze` → "No issues found!" (ignorar os 3 info lints pré-existentes de `lib/features/schedule/**` se aparecerem — não tocar schedule).
Run: `& "C:\flutter\bin\flutter.bat" test` → todos verdes.

- [ ] **Step 8: Commit**

```bash
git add front/lib/features/inventory/ front/test/inventory_fiscal_test.dart
git commit -m "feat(inventory): campos fiscais no cadastro de item (produto: NCM/CFOP/origem/GTIN; serviço: cód. serviço/ISS)"
```

---

## Self-Review (feito na escrita)

- **Cobertura:** produto (ncm/cfop/origem/gtin) e serviço (codigo_servico/aliquota_iss) modelados nas 3 camadas do banco (T1), persistidos gated por kind com e2e (T2), snapshot em invoice_line plumbado nullable (T3), e capturados no front (T4). Enriquecimento do snapshot no momento da emissão = **Plano 3** (via `InventoryService.getItem`/`getItemsByIds` — seam já existente).
- **Sem placeholders:** paths/linhas e código reais de cada camada (extraídos do código atual).
- **Consistência:** camelCase no DTO/ItemDraft vs snake_case nas colunas/InventoryItem read; `ItemData`/`InvoiceLineData` estendidos onde os métodos fazem `...data`/map explícito.
- **Migrations locais:** aplicar só o fragmento via psql (baseline não re-executável) — lição do Plano 1.

## Pendências herdadas (Plano 3)
- Preencher o snapshot de `invoice_line` no `issue()`/`toLine` lendo a classificação do item via `InventoryService` (o `inventory_item_id` já viaja em `service_order_item`/`sale_item`).
- Validação mais rica (ex.: origem ∈ 0..8, NCM 8 dígitos) pode ser endurecida quando o gateway real exigir.
