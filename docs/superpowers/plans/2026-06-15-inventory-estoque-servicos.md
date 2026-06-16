# Estoque & Serviços (`inventory`) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `inventory` (Estoque & Serviços) module: a tenant-scoped item catalog (Produto/Serviço) with stock movements + history, manual markup pricing, low-stock filter, module config, and a public service the future OS module will consume.

**Architecture:** NestJS modular monolith — Controller (thin) → Service (logic) → Repository (only DB toucher, via `TenantContext.getClient()` under `withTenantTx`). Two new RLS+FORCE tables (`inventory_item`, `inventory_movement`). Config lives in `tenant_module.settings['inventory']`, read/written via `BillingService` ("aponta, não invade"). Flutter feature mirrors `customers` (domain → data → presentation, UI only via repository). Migration is additive in 3 places.

**Tech Stack:** NestJS, Prisma, PostgreSQL (RLS), class-validator, Jest + supertest + testcontainers (e2e); Flutter (Riverpod 3, go_router, dio, freezed).

**Spec:** [docs/superpowers/specs/2026-06-15-inventory-estoque-servicos-design.md](../specs/2026-06-15-inventory-estoque-servicos-design.md)
**Pendências:** [docs/pendencias.md](../../pendencias.md)

**Ground rules (from skill `orbixhub-arquitetura`):**
- Repos NEVER inject `PrismaService`; always `this.tenant.getClient()` inside a `withTenantTx`/`runWithTenant`.
- `tenant_id` always from JWT/CLS, never from the client.
- Sensitive mutations: `@Permissions(...)` + `AuditService.log(...)`.
- No hard delete (`status='archived'`).
- Migration additive in 3 places kept together: `sql/auth-multitenant-schema.sql`, `prisma/migrations/0010_inventory/migration.sql`, `prisma/schema.prisma`.
- Prices in **cents** (`int`); quantities `numeric(14,3)`.
- Front: UI only via repository; freezed models; sealed state; PT-BR user strings; icons per type/movement (product requirement).

**Local env reminders (this machine):** Postgres under Podman on host port **55432**; run Nest on an alt port (e.g. `PORT=4400`) because VS Code forwards 3000. Flutter SDK at `C:\Users\KaueSobral\develop\flutter\bin\flutter.bat` (not on PATH). e2e needs Redis FLUSHALL first + `--forceExit`.

---

## File Structure

**Backend — create:**
- `back/prisma/migrations/0010_inventory/migration.sql` — additive DDL + RLS + grants + trial seed.
- `back/src/modules/inventory/inventory.module.ts` — module wiring + config section registration.
- `back/src/modules/inventory/inventory.config.ts` — config model, defaults, merge, pricing/balance pure helpers.
- `back/src/modules/inventory/inventory.repository.ts` — only DB toucher.
- `back/src/modules/inventory/inventory.service.ts` — logic + public methods (`getItem`, `applyMovement`, `searchForPicker`).
- `back/src/modules/inventory/inventory.controller.ts` — routes (items, movements, low-stock, config).
- `back/src/modules/inventory/dto/item.dto.ts`, `dto/movement.dto.ts`, `dto/config.dto.ts`.
- `back/src/modules/inventory/inventory.config.spec.ts` — unit tests (pure helpers).
- `back/test/inventory.e2e-spec.ts` — e2e (tenant isolation, authz, module gating, stock).

**Backend — modify:**
- `back/prisma/schema.prisma` — add `inventory_item`, `inventory_movement` models + relation on `tenant`.
- `back/sql/auth-multitenant-schema.sql` — add canonical idempotent tables + trial plan_module seed.
- `back/src/app.module.ts` — register `InventoryModule`.

**Frontend — create:** `front/lib/features/inventory/` (domain / data / presentation), mirroring `customers`.

**Frontend — modify:** `front/lib/di.dart` (providers), `front/lib/core/router/app_router.dart` (route), `front/lib/features/shell/presentation/nav_items.dart` (menu item).

**Docs — modify:** `docs/configuracao.md` (new subsection), `docs/modulos-v1.md` (mark `inventory` implemented).

---

## Phase 0 — Branch

### Task 0: Create the feature branch

- [ ] **Step 1: Create and switch to the branch**

Run:
```bash
git checkout -b feat/inventory
git status
```
Expected: `On branch feat/inventory`, clean tree.

---

## Phase 1 — Database migration (3 places)

### Task 1: Write the additive SQL migration

**Files:**
- Create: `back/prisma/migrations/0010_inventory/migration.sql`

- [ ] **Step 1: Write the migration SQL**

```sql
-- ============================================================
-- 0010 — Inventory (Estoque & Serviços) — aditivo, idempotente
-- ============================================================
-- Catálogo de itens (produto/serviço) + movimentações de estoque.
-- Genérico/multi-vertical. RLS + FORCE como toda tabela tenant-scoped.
-- Preços em centavos (int); quantidades numeric(14,3).

CREATE TABLE IF NOT EXISTS inventory_item (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  kind             text NOT NULL,                       -- 'product' | 'service'
  name             text NOT NULL,
  code             text,
  barcode          text,
  category         text,
  unit             text NOT NULL DEFAULT 'un',
  sale_price_cents integer NOT NULL DEFAULT 0,
  cost_price_cents integer,
  margin_percent   numeric(7,2),
  sellable         boolean NOT NULL DEFAULT true,
  track_stock      boolean NOT NULL DEFAULT true,
  stock_qty        numeric(14,3) NOT NULL DEFAULT 0,
  min_qty          numeric(14,3),
  duration_minutes integer,
  brand            text,
  status           text NOT NULL DEFAULT 'active',      -- 'active' | 'archived'
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'inventory_item_kind_chk') THEN
    ALTER TABLE inventory_item ADD CONSTRAINT inventory_item_kind_chk CHECK (kind IN ('product','service'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'inventory_item_status_chk') THEN
    ALTER TABLE inventory_item ADD CONSTRAINT inventory_item_status_chk CHECK (status IN ('active','archived'));
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_inventory_item_tenant_kind ON inventory_item(tenant_id, kind);
CREATE INDEX IF NOT EXISTS idx_inventory_item_tenant_status ON inventory_item(tenant_id, status);
CREATE UNIQUE INDEX IF NOT EXISTS uq_inventory_item_tenant_code
  ON inventory_item(tenant_id, code) WHERE code IS NOT NULL;

CREATE TABLE IF NOT EXISTS inventory_movement (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  item_id       uuid NOT NULL REFERENCES inventory_item(id) ON DELETE CASCADE,
  type          text NOT NULL,                          -- 'in' | 'out' | 'adjust'
  quantity      numeric(14,3) NOT NULL,
  balance_after numeric(14,3) NOT NULL,
  reason        text,
  ref_type      text,
  ref_id        uuid,
  note          text,
  created_by    uuid,
  created_at    timestamptz NOT NULL DEFAULT now()
);
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'inventory_movement_type_chk') THEN
    ALTER TABLE inventory_movement ADD CONSTRAINT inventory_movement_type_chk CHECK (type IN ('in','out','adjust'));
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_inventory_movement_tenant_item
  ON inventory_movement(tenant_id, item_id, created_at DESC);

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['inventory_item','inventory_movement']
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY;', t);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY;', t);
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = t AND policyname = 'tenant_isolation') THEN
      EXECUTE format($f$
        CREATE POLICY tenant_isolation ON %I
        USING (tenant_id = current_tenant_id())
        WITH CHECK (tenant_id = current_tenant_id());
      $f$, t);
    END IF;
  END LOOP;
END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON inventory_item TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON inventory_movement TO app_user;

-- inventory passa a fazer parte do plano trial (além do pro, que já tem tudo).
INSERT INTO plan_module (plan_id, module_id)
SELECT pl.id, m.id FROM plan pl JOIN module m ON m.key = 'inventory'
WHERE pl.key = 'trial'
ON CONFLICT DO NOTHING;
```

- [ ] **Step 2: Commit**

```bash
git add back/prisma/migrations/0010_inventory/migration.sql
git commit -m "feat(inventory): migration 0010 — tabelas inventory_item/inventory_movement + trial seed"
```

### Task 2: Mirror the tables into the canonical baseline SQL

**Files:**
- Modify: `back/sql/auth-multitenant-schema.sql`

- [ ] **Step 1: Add the same two `CREATE TABLE` blocks (with RLS/FORCE/policy/grants) to the baseline**

Insert the **identical** table DDL from Task 1 (both `CREATE TABLE`, the constraint `DO` blocks, indexes, the RLS `DO` loop over `ARRAY['inventory_item','inventory_movement']`, and the two `GRANT` lines) into `back/sql/auth-multitenant-schema.sql`, placed right after the `subject` table block (search for `CREATE TABLE IF NOT EXISTS subject`). The baseline is idempotent — reuse the exact `IF NOT EXISTS` / `DO $$` style already there.

- [ ] **Step 2: Add `inventory` to the trial plan in the baseline seed**

Find the trial `plan_module` seed (search `WHERE pl.key = 'trial'`). Update it so trial includes `inventory`. Change:
```sql
INSERT INTO plan_module (plan_id, module_id)
SELECT pl.id, m.id FROM plan pl JOIN module m ON m.key IN ('os','customers')
WHERE pl.key = 'trial'
ON CONFLICT DO NOTHING;
```
to:
```sql
INSERT INTO plan_module (plan_id, module_id)
SELECT pl.id, m.id FROM plan pl JOIN module m ON m.key IN ('os','customers','inventory')
WHERE pl.key = 'trial'
ON CONFLICT DO NOTHING;
```

- [ ] **Step 3: Apply the baseline as `app_owner` and verify it runs clean (idempotent)**

Run:
```bash
podman start orbix-postgres orbix-redis
npx ts-node back/scripts/ci-db-setup.ts
```
Expected: completes without error; re-running is safe (idempotent). If the script needs env, follow README §3.

- [ ] **Step 4: Verify the tables exist and trial has inventory**

Run:
```bash
PGPASSWORD=$APP_OWNER_PASSWORD psql -h localhost -p 55432 -U app_owner -d orbix -c "\d inventory_item" -c "SELECT m.key FROM plan_module pm JOIN plan p ON p.id=pm.plan_id JOIN module m ON m.id=pm.module_id WHERE p.key='trial' ORDER BY 1;"
```
Expected: `inventory_item` described with RLS; trial rows include `inventory`, `os`, `customers`.

- [ ] **Step 5: Commit**

```bash
git add back/sql/auth-multitenant-schema.sql
git commit -m "feat(inventory): baseline canônico — tabelas inventory + inventory no trial"
```

### Task 3: Add Prisma models (hand-maintained) and regenerate the client

**Files:**
- Modify: `back/prisma/schema.prisma`

- [ ] **Step 1: Add the two models, mirroring the existing `customer`/`subject` style**

Add after the `subject` model:
```prisma
/// This model contains row level security and requires additional setup for migrations. Visit https://pris.ly/d/row-level-security for more info.
model inventory_item {
  id               String               @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  tenant_id        String               @db.Uuid
  kind             String
  name             String
  code             String?
  barcode          String?
  category         String?
  unit             String               @default("un")
  sale_price_cents Int                  @default(0)
  cost_price_cents Int?
  margin_percent   Decimal?             @db.Decimal(7, 2)
  sellable         Boolean              @default(true)
  track_stock      Boolean              @default(true)
  stock_qty        Decimal              @default(0) @db.Decimal(14, 3)
  min_qty          Decimal?             @db.Decimal(14, 3)
  duration_minutes Int?
  brand            String?
  status           String               @default("active")
  created_at       DateTime             @default(now()) @db.Timestamptz(6)
  updated_at       DateTime             @default(now()) @db.Timestamptz(6)
  tenant           tenant               @relation(fields: [tenant_id], references: [id], onDelete: Cascade, onUpdate: NoAction)
  movements        inventory_movement[]

  // Partial unique index `(tenant_id, code) WHERE code IS NOT NULL` is created in SQL.
  @@index([tenant_id, kind], map: "idx_inventory_item_tenant_kind")
  @@index([tenant_id, status], map: "idx_inventory_item_tenant_status")
}

/// This model contains row level security and requires additional setup for migrations. Visit https://pris.ly/d/row-level-security for more info.
model inventory_movement {
  id            String         @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  tenant_id     String         @db.Uuid
  item_id       String         @db.Uuid
  type          String
  quantity      Decimal        @db.Decimal(14, 3)
  balance_after Decimal        @db.Decimal(14, 3)
  reason        String?
  ref_type      String?
  ref_id        String?        @db.Uuid
  note          String?
  created_by    String?        @db.Uuid
  created_at    DateTime       @default(now()) @db.Timestamptz(6)
  item          inventory_item @relation(fields: [item_id], references: [id], onDelete: Cascade, onUpdate: NoAction)
  tenant        tenant         @relation(fields: [tenant_id], references: [id], onDelete: Cascade, onUpdate: NoAction)

  @@index([tenant_id, item_id, created_at], map: "idx_inventory_movement_tenant_item")
}
```

- [ ] **Step 2: Add back-relations on the `tenant` model**

Find `model tenant {` and add these two relation fields among its existing relation list:
```prisma
  inventory_item     inventory_item[]
  inventory_movement inventory_movement[]
```

- [ ] **Step 3: Regenerate the Prisma client**

Run:
```bash
npm run -w back prisma:generate
```
Expected: "Generated Prisma Client" with no schema validation errors. (If the script name differs, use `npx prisma generate --schema back/prisma/schema.prisma`.)

- [ ] **Step 4: Commit**

```bash
git add back/prisma/schema.prisma
git commit -m "feat(inventory): modelos prisma inventory_item/inventory_movement"
```

---

## Phase 2 — Config + pure helpers (TDD)

### Task 4: Config model, defaults, merge, pricing & balance helpers

**Files:**
- Create: `back/src/modules/inventory/inventory.config.ts`
- Test: `back/src/modules/inventory/inventory.config.spec.ts`

- [ ] **Step 1: Write the failing unit tests**

```ts
import {
  mergeInventoryConfig,
  DEFAULT_INVENTORY_CONFIG,
  suggestPriceCents,
  computeMovement,
} from './inventory.config';

describe('inventory.config', () => {
  it('returns defaults when nothing saved', () => {
    expect(mergeInventoryConfig(undefined)).toEqual(DEFAULT_INVENTORY_CONFIG);
  });

  it('shallow-merges a partial patch over current', () => {
    const merged = mergeInventoryConfig(
      { defaultUnit: 'L', categories: ['Óleos'] },
      { defaultMarginPercent: 50 },
    );
    expect(merged.defaultUnit).toBe('L');
    expect(merged.categories).toEqual(['Óleos']);
    expect(merged.defaultMarginPercent).toBe(50);
    expect(merged.trackStockDefault).toBe(true);
  });
});

describe('suggestPriceCents', () => {
  it('applies margin over cost and rounds to cents', () => {
    expect(suggestPriceCents(1000, 50)).toBe(1500);
    expect(suggestPriceCents(999, 33.33)).toBe(1332); // 999*1.3333=1332.0
  });
  it('returns cost when margin is 0 or missing', () => {
    expect(suggestPriceCents(1000, 0)).toBe(1000);
  });
});

describe('computeMovement', () => {
  it('adds on in', () => {
    expect(computeMovement(5, 'in', 3)).toEqual({ quantity: 3, balanceAfter: 8 });
  });
  it('subtracts on out', () => {
    expect(computeMovement(5, 'out', 2)).toEqual({ quantity: 2, balanceAfter: 3 });
  });
  it('blocks negative out', () => {
    expect(() => computeMovement(1, 'out', 5)).toThrow(/negativ/i);
  });
  it('sets target on adjust and records the delta magnitude', () => {
    expect(computeMovement(5, 'adjust', 2)).toEqual({ quantity: 3, balanceAfter: 2 });
    expect(computeMovement(5, 'adjust', 9)).toEqual({ quantity: 4, balanceAfter: 9 });
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npm run -w back test -- inventory.config`
Expected: FAIL — `Cannot find module './inventory.config'`.

- [ ] **Step 3: Write the implementation**

```ts
/**
 * Config do módulo Estoque & Serviços + helpers puros (precificação e saldo).
 * Os VALORES da config ficam em `tenant_module.settings['inventory']` — o módulo
 * lê/grava via `BillingService` ("aponta, não invade"), nunca tocando a tabela.
 */

export const INVENTORY_MODULE_KEY = 'inventory';
export const INVENTORY_CONFIG_KEY = 'inventory';

export interface InventoryConfig {
  /** Unidade pré-selecionada ao cadastrar um produto. */
  defaultUnit: string;
  /** Marca novos produtos como rastreáveis por padrão. */
  trackStockDefault: boolean;
  /** Margem padrão (%) usada pelo helper de markup (null = sem default). */
  defaultMarginPercent: number | null;
  /** Sugestões de categoria para autocomplete (valor salvo é texto livre). */
  categories: string[];
}

export const DEFAULT_INVENTORY_CONFIG: InventoryConfig = {
  defaultUnit: 'un',
  trackStockDefault: true,
  defaultMarginPercent: null,
  categories: [],
};

/** Merge raso e seguro de um patch parcial sobre os defaults/atual. */
export function mergeInventoryConfig(
  current: Partial<InventoryConfig> | null | undefined,
  patch: Partial<InventoryConfig> = {},
): InventoryConfig {
  const base = { ...DEFAULT_INVENTORY_CONFIG, ...(current ?? {}) };
  return {
    defaultUnit: patch.defaultUnit ?? base.defaultUnit,
    trackStockDefault: patch.trackStockDefault ?? base.trackStockDefault,
    defaultMarginPercent:
      patch.defaultMarginPercent !== undefined
        ? patch.defaultMarginPercent
        : base.defaultMarginPercent,
    categories: patch.categories ?? base.categories,
  };
}

/** Preço de venda sugerido (centavos) a partir de custo + margem%. */
export function suggestPriceCents(costCents: number, marginPercent: number): number {
  if (!costCents || costCents < 0) return 0;
  const m = marginPercent && marginPercent > 0 ? marginPercent : 0;
  return Math.round(costCents * (1 + m / 100));
}

export type MovementType = 'in' | 'out' | 'adjust';

/**
 * Saldo resultante de um movimento (em unidades, número simples).
 * - in: soma `amount`; out: subtrai `amount` (erro se negativar);
 * - adjust: `amount` é o saldo-alvo; grava o delta (magnitude) em `quantity`.
 * O repository converte de/para Prisma.Decimal.
 */
export function computeMovement(
  current: number,
  type: MovementType,
  amount: number,
): { quantity: number; balanceAfter: number } {
  if (amount < 0) throw new Error('Quantidade inválida.');
  if (type === 'in') return { quantity: amount, balanceAfter: current + amount };
  if (type === 'out') {
    const balanceAfter = current - amount;
    if (balanceAfter < 0) throw new Error('Saldo não pode ficar negativo.');
    return { quantity: amount, balanceAfter };
  }
  // adjust
  return { quantity: Math.abs(amount - current), balanceAfter: amount };
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npm run -w back test -- inventory.config`
Expected: PASS (all cases).

- [ ] **Step 5: Commit**

```bash
git add back/src/modules/inventory/inventory.config.ts back/src/modules/inventory/inventory.config.spec.ts
git commit -m "feat(inventory): config + helpers puros (markup, saldo) com testes"
```

---

## Phase 3 — DTOs

### Task 5: Item, movement and config DTOs

**Files:**
- Create: `back/src/modules/inventory/dto/item.dto.ts`
- Create: `back/src/modules/inventory/dto/movement.dto.ts`
- Create: `back/src/modules/inventory/dto/config.dto.ts`

- [ ] **Step 1: Write `item.dto.ts`**

```ts
import {
  IsArray, IsBoolean, IsIn, IsInt, IsNumber, IsOptional, IsString,
  Max, MaxLength, Min, MinLength,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CreateItemDto {
  @IsIn(['product', 'service']) kind!: 'product' | 'service';
  @IsString() @MinLength(1) @MaxLength(200) name!: string;
  @IsOptional() @IsString() @MaxLength(60) code?: string;
  @IsOptional() @IsString() @MaxLength(60) barcode?: string;
  @IsOptional() @IsString() @MaxLength(120) category?: string;
  @IsOptional() @IsString() @MaxLength(20) unit?: string;
  @IsOptional() @IsInt() @Min(0) salePriceCents?: number;
  @IsOptional() @IsInt() @Min(0) costPriceCents?: number;
  @IsOptional() @IsNumber() @Min(0) @Max(100000) marginPercent?: number;
  @IsOptional() @IsBoolean() sellable?: boolean;
  @IsOptional() @IsBoolean() trackStock?: boolean;
  @IsOptional() @IsNumber() @Min(0) minQty?: number;
  @IsOptional() @IsInt() @Min(0) durationMinutes?: number;
  @IsOptional() @IsString() @MaxLength(120) brand?: string;
}

export class UpdateItemDto {
  // kind is immutable after creation; stock_qty is never set here (only via movements).
  @IsOptional() @IsString() @MinLength(1) @MaxLength(200) name?: string;
  @IsOptional() @IsString() @MaxLength(60) code?: string;
  @IsOptional() @IsString() @MaxLength(60) barcode?: string;
  @IsOptional() @IsString() @MaxLength(120) category?: string;
  @IsOptional() @IsString() @MaxLength(20) unit?: string;
  @IsOptional() @IsInt() @Min(0) salePriceCents?: number;
  @IsOptional() @IsInt() @Min(0) costPriceCents?: number;
  @IsOptional() @IsNumber() @Min(0) @Max(100000) marginPercent?: number;
  @IsOptional() @IsBoolean() sellable?: boolean;
  @IsOptional() @IsBoolean() trackStock?: boolean;
  @IsOptional() @IsNumber() @Min(0) minQty?: number;
  @IsOptional() @IsInt() @Min(0) durationMinutes?: number;
  @IsOptional() @IsString() @MaxLength(120) brand?: string;
}

export class ListItemsQueryDto {
  @IsOptional() @IsString() @MaxLength(120) q?: string;
  @IsOptional() @IsIn(['product', 'service']) kind?: 'product' | 'service';
  @IsOptional() @IsString() @MaxLength(120) category?: string;
  @IsOptional() @IsIn(['active', 'archived', 'all']) status?: 'active' | 'archived' | 'all';
  @IsOptional() @Type(() => Boolean) @IsBoolean() lowStock?: boolean;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) page?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(100) pageSize?: number;
}
```

- [ ] **Step 2: Write `movement.dto.ts`**

```ts
import { IsIn, IsNumber, IsOptional, IsString, MaxLength, Min } from 'class-validator';

export class CreateMovementDto {
  @IsIn(['in', 'out', 'adjust']) type!: 'in' | 'out' | 'adjust';
  /** in/out: quantidade movimentada; adjust: saldo-alvo. Sempre >= 0. */
  @IsNumber() @Min(0) quantity!: number;
  @IsOptional() @IsString() @MaxLength(40) reason?: string;
  @IsOptional() @IsString() @MaxLength(2000) note?: string;
}
```

- [ ] **Step 3: Write `config.dto.ts`**

```ts
import { IsArray, IsBoolean, IsNumber, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

export class UpdateInventoryConfigDto {
  @IsOptional() @IsString() @MaxLength(20) defaultUnit?: string;
  @IsOptional() @IsBoolean() trackStockDefault?: boolean;
  @IsOptional() @IsNumber() @Min(0) @Max(100000) defaultMarginPercent?: number | null;
  @IsOptional() @IsArray() @IsString({ each: true }) categories?: string[];
}
```

- [ ] **Step 4: Commit**

```bash
git add back/src/modules/inventory/dto
git commit -m "feat(inventory): DTOs de item, movimento e config"
```

---

## Phase 4 — Repository

### Task 6: Inventory repository (only DB toucher)

**Files:**
- Create: `back/src/modules/inventory/inventory.repository.ts`

- [ ] **Step 1: Write the repository**

```ts
import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { TenantContext } from '../../common/database/tenant-context';

export interface ItemFilter {
  q?: string;
  kind?: 'product' | 'service';
  category?: string;
  status: 'active' | 'archived' | 'all';
  lowStock?: boolean;
  skip: number;
  take: number;
}

export interface ItemData {
  kind?: string;
  name?: string;
  code?: string | null;
  barcode?: string | null;
  category?: string | null;
  unit?: string;
  sale_price_cents?: number;
  cost_price_cents?: number | null;
  margin_percent?: Prisma.Decimal | number | null;
  sellable?: boolean;
  track_stock?: boolean;
  min_qty?: Prisma.Decimal | number | null;
  duration_minutes?: number | null;
  brand?: string | null;
}

/**
 * Único ponto que toca `inventory_item`/`inventory_movement`. Sempre via
 * `tenant.getClient()` (tx-scoped sob RLS); o service abre o `withTenantTx`.
 */
@Injectable()
export class InventoryRepository {
  constructor(private readonly tenant: TenantContext) {}

  private statusWhere(status: 'active' | 'archived' | 'all') {
    if (status === 'all') return {};
    return { status };
  }

  createItem(tenantId: string, data: ItemData) {
    const db = this.tenant.getClient();
    return db.inventory_item.create({
      data: { tenant_id: tenantId, ...(data as Prisma.inventory_itemCreateInput) },
    });
  }

  findItemById(id: string) {
    const db = this.tenant.getClient();
    return db.inventory_item.findUnique({ where: { id } });
  }

  async listItems(filter: ItemFilter) {
    const db = this.tenant.getClient();
    const where: Prisma.inventory_itemWhereInput = {
      ...this.statusWhere(filter.status),
      ...(filter.kind ? { kind: filter.kind } : {}),
      ...(filter.category ? { category: { equals: filter.category, mode: 'insensitive' } } : {}),
      ...(filter.lowStock
        ? { track_stock: true, min_qty: { not: null }, stock_qty: { lte: db.inventory_item.fields.min_qty } }
        : {}),
      ...(filter.q
        ? {
            OR: [
              { name: { contains: filter.q, mode: 'insensitive' } },
              { code: { contains: filter.q, mode: 'insensitive' } },
              { barcode: { contains: filter.q, mode: 'insensitive' } },
            ],
          }
        : {}),
    };
    const [items, total] = await Promise.all([
      db.inventory_item.findMany({ where, orderBy: { name: 'asc' }, skip: filter.skip, take: filter.take }),
      db.inventory_item.count({ where }),
    ]);
    return { items, total };
  }

  updateItem(id: string, data: ItemData) {
    const db = this.tenant.getClient();
    return db.inventory_item.update({
      where: { id },
      data: { ...(data as Prisma.inventory_itemUpdateInput), updated_at: new Date() },
    });
  }

  setItemStatus(id: string, status: 'active' | 'archived') {
    const db = this.tenant.getClient();
    return db.inventory_item.update({ where: { id }, data: { status, updated_at: new Date() } });
  }

  /** Cria o movimento E atualiza o saldo cacheado do item — mesma tx. */
  async createMovement(
    tenantId: string,
    itemId: string,
    data: {
      type: string;
      quantity: number;
      balance_after: number;
      reason: string | null;
      ref_type: string | null;
      ref_id: string | null;
      note: string | null;
      created_by: string | null;
    },
  ) {
    const db = this.tenant.getClient();
    const movement = await db.inventory_movement.create({
      data: { tenant_id: tenantId, item_id: itemId, ...data },
    });
    await db.inventory_item.update({
      where: { id: itemId },
      data: { stock_qty: data.balance_after, updated_at: new Date() },
    });
    return movement;
  }

  listMovements(itemId: string, take = 100) {
    const db = this.tenant.getClient();
    return db.inventory_movement.findMany({
      where: { item_id: itemId },
      orderBy: { created_at: 'desc' },
      take,
    });
  }

  searchForPicker(q: string | undefined, kind: 'product' | 'service' | undefined, take = 20) {
    const db = this.tenant.getClient();
    return db.inventory_item.findMany({
      where: {
        status: 'active',
        ...(kind ? { kind } : {}),
        ...(q ? { OR: [{ name: { contains: q, mode: 'insensitive' } }, { code: { contains: q, mode: 'insensitive' } }] } : {}),
      },
      orderBy: { name: 'asc' },
      take,
    });
  }
}
```

> **Note on the `lowStock` filter:** `stock_qty <= min_qty` across two columns uses Prisma's
> field reference (`db.inventory_item.fields.min_qty`). If the installed Prisma version rejects
> field-to-field comparison, fall back to a raw query in the repository:
> `` db.$queryRaw`SELECT * FROM inventory_item WHERE status='active' AND track_stock AND min_qty IS NOT NULL AND stock_qty <= min_qty ORDER BY name` `` (still tenant-scoped by RLS under the tx). Keep the public method signature identical.

- [ ] **Step 2: Typecheck**

Run: `npm run -w back build` (or `npx tsc -p back/tsconfig.json --noEmit`)
Expected: no type errors in `inventory.repository.ts`.

- [ ] **Step 3: Commit**

```bash
git add back/src/modules/inventory/inventory.repository.ts
git commit -m "feat(inventory): repository (catálogo + movimentos + saldo cacheado)"
```

---

## Phase 5 — Service

### Task 7: Inventory service (logic + public methods)

**Files:**
- Create: `back/src/modules/inventory/inventory.service.ts`

- [ ] **Step 1: Write the service**

```ts
import {
  BadRequestException, ConflictException, ForbiddenException,
  Injectable, NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import type { AuthUser } from '../../common/auth/auth.types';
import { TenantContext } from '../../common/database/tenant-context';
import { AuditService } from '../../common/audit/audit.service';
import { BillingService } from '../billing/billing.service';
import { InventoryRepository } from './inventory.repository';
import {
  INVENTORY_CONFIG_KEY, INVENTORY_MODULE_KEY,
  InventoryConfig, mergeInventoryConfig, computeMovement, MovementType,
} from './inventory.config';
import { CreateItemDto, ListItemsQueryDto, UpdateItemDto } from './dto/item.dto';
import { CreateMovementDto } from './dto/movement.dto';
import { UpdateInventoryConfigDto } from './dto/config.dto';

const DEFAULT_PAGE_SIZE = 20;
const isUniqueViolation = (e: unknown) => (e as { code?: string })?.code === 'P2002';
const toNum = (d: Prisma.Decimal | number | null | undefined): number =>
  d == null ? 0 : typeof d === 'number' ? d : d.toNumber();

export interface ApplyMovementInput {
  itemId: string;
  type: MovementType;
  quantity: number;
  reason?: string;
  refType?: string;
  refId?: string;
  note?: string;
  actorUserId?: string;
}

@Injectable()
export class InventoryService {
  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: InventoryRepository,
    private readonly billing: BillingService,
    private readonly audit: AuditService,
  ) {}

  // ============ Config ============
  async getConfig(tenantId: string): Promise<InventoryConfig> {
    const settings = await this.billing.getModuleSettings(tenantId, INVENTORY_MODULE_KEY);
    return mergeInventoryConfig(settings[INVENTORY_CONFIG_KEY] as Partial<InventoryConfig> | undefined);
  }

  async updateConfig(user: AuthUser, dto: UpdateInventoryConfigDto): Promise<InventoryConfig> {
    const settings = await this.billing.getModuleSettings(user.tenantId, INVENTORY_MODULE_KEY);
    const current = settings[INVENTORY_CONFIG_KEY] as Partial<InventoryConfig> | undefined;
    const merged = mergeInventoryConfig(current, dto as Partial<InventoryConfig>);
    await this.billing.setModuleSettings(user.tenantId, INVENTORY_MODULE_KEY, {
      ...settings,
      [INVENTORY_CONFIG_KEY]: merged,
    });
    await this.audit.log(user.tenantId, user.userId, 'settings_change', 'inventory.config');
    return merged;
  }

  // ============ Items ============
  async createItem(user: AuthUser, dto: CreateItemDto) {
    const isService = dto.kind === 'service';
    const config = await this.getConfig(user.tenantId);
    const data = {
      kind: dto.kind,
      name: dto.name.trim(),
      code: dto.code?.trim() || null,
      barcode: isService ? null : dto.barcode?.trim() || null,
      category: dto.category?.trim() || null,
      unit: dto.unit?.trim() || config.defaultUnit,
      sale_price_cents: dto.salePriceCents ?? 0,
      cost_price_cents: dto.costPriceCents ?? null,
      margin_percent: dto.marginPercent ?? null,
      sellable: dto.sellable ?? true,
      track_stock: isService ? false : (dto.trackStock ?? config.trackStockDefault),
      min_qty: isService ? null : dto.minQty ?? null,
      duration_minutes: isService ? dto.durationMinutes ?? null : null,
      brand: dto.brand?.trim() || null,
    };
    try {
      const item = await this.tenant.withTenantTx(() => this.repo.createItem(user.tenantId, data));
      await this.audit.log(user.tenantId, user.userId, 'inventory_item_create', item.id);
      return item;
    } catch (e) {
      if (isUniqueViolation(e)) throw new ConflictException('Já existe um item com este código.');
      throw e;
    }
  }

  async listItems(user: AuthUser, query: ListItemsQueryDto) {
    const page = query.page ?? 1;
    const pageSize = query.pageSize ?? DEFAULT_PAGE_SIZE;
    const { items, total } = await this.tenant.withTenantTx(() =>
      this.repo.listItems({
        q: query.q?.trim() || undefined,
        kind: query.kind,
        category: query.category?.trim() || undefined,
        status: query.status ?? 'active',
        lowStock: query.lowStock ?? false,
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
    );
    return { items, total, page, pageSize };
  }

  async getItemOrThrow(id: string) {
    const item = await this.tenant.withTenantTx(() => this.repo.findItemById(id));
    if (!item) throw new NotFoundException('Item não encontrado.');
    return item;
  }

  async updateItem(user: AuthUser, id: string, dto: UpdateItemDto) {
    return this.tenant.withTenantTx(async () => {
      const existing = await this.repo.findItemById(id);
      if (!existing) throw new NotFoundException('Item não encontrado.');
      const isService = existing.kind === 'service';
      const data: Record<string, unknown> = {};
      if (dto.name !== undefined) data.name = dto.name.trim();
      if (dto.code !== undefined) data.code = dto.code.trim() || null;
      if (dto.barcode !== undefined) data.barcode = isService ? null : dto.barcode.trim() || null;
      if (dto.category !== undefined) data.category = dto.category.trim() || null;
      if (dto.unit !== undefined) data.unit = dto.unit.trim() || existing.unit;
      if (dto.salePriceCents !== undefined) data.sale_price_cents = dto.salePriceCents;
      if (dto.costPriceCents !== undefined) data.cost_price_cents = dto.costPriceCents;
      if (dto.marginPercent !== undefined) data.margin_percent = dto.marginPercent;
      if (dto.sellable !== undefined) data.sellable = dto.sellable;
      if (dto.trackStock !== undefined && !isService) data.track_stock = dto.trackStock;
      if (dto.minQty !== undefined && !isService) data.min_qty = dto.minQty;
      if (dto.durationMinutes !== undefined && isService) data.duration_minutes = dto.durationMinutes;
      if (dto.brand !== undefined) data.brand = dto.brand.trim() || null;
      try {
        const item = await this.repo.updateItem(id, data);
        await this.audit.log(user.tenantId, user.userId, 'inventory_item_update', id);
        return item;
      } catch (e) {
        if (isUniqueViolation(e)) throw new ConflictException('Já existe um item com este código.');
        throw e;
      }
    });
  }

  async archiveItem(user: AuthUser, id: string) {
    return this.setStatus(user, id, 'archived', 'inventory_item_archive');
  }
  async unarchiveItem(user: AuthUser, id: string) {
    return this.setStatus(user, id, 'active', 'inventory_item_unarchive');
  }
  private async setStatus(user: AuthUser, id: string, status: 'active' | 'archived', action: string) {
    return this.tenant.withTenantTx(async () => {
      const existing = await this.repo.findItemById(id);
      if (!existing) throw new NotFoundException('Item não encontrado.');
      const item = await this.repo.setItemStatus(id, status);
      await this.audit.log(user.tenantId, user.userId, action, id);
      return item;
    });
  }

  // ============ Movements ============
  async registerMovement(user: AuthUser, itemId: string, dto: CreateMovementDto) {
    return this.tenant.withTenantTx(async () => {
      const item = await this.repo.findItemById(itemId);
      if (!item) throw new NotFoundException('Item não encontrado.');
      if (item.kind === 'service' || !item.track_stock) {
        throw new BadRequestException('Este item não controla estoque.');
      }
      let calc: { quantity: number; balanceAfter: number };
      try {
        calc = computeMovement(toNum(item.stock_qty), dto.type, dto.quantity);
      } catch (e) {
        throw new BadRequestException((e as Error).message);
      }
      const movement = await this.repo.createMovement(user.tenantId, itemId, {
        type: dto.type,
        quantity: calc.quantity,
        balance_after: calc.balanceAfter,
        reason: dto.reason?.trim() || 'manual',
        ref_type: null,
        ref_id: null,
        note: dto.note?.trim() || null,
        created_by: user.userId,
      });
      await this.audit.log(user.tenantId, user.userId, 'inventory_movement', itemId, {
        type: dto.type, quantity: calc.quantity, balanceAfter: calc.balanceAfter,
      });
      return movement;
    });
  }

  async listMovements(user: AuthUser, itemId: string) {
    return this.tenant.withTenantTx(async () => {
      const item = await this.repo.findItemById(itemId);
      if (!item) throw new NotFoundException('Item não encontrado.');
      return this.repo.listMovements(itemId);
    });
  }

  async lowStock(user: AuthUser) {
    const { items } = await this.tenant.withTenantTx(() =>
      this.repo.listItems({ status: 'active', lowStock: true, skip: 0, take: 100 }),
    );
    return items;
  }

  // ============ Public (consumed by OS — não pela UI deste módulo) ============
  /** Busca 1 item por id (para a OS montar a linha por snapshot). */
  getItem(user: AuthUser, id: string) {
    return this.getItemOrThrow(id);
  }

  /** Picker enxuto para a OS. */
  async searchForPicker(user: AuthUser, q: string, kind?: 'product' | 'service') {
    return this.tenant.withTenantTx(() => this.repo.searchForPicker(q?.trim() || undefined, kind));
  }

  /**
   * Baixa/entrada programática (ex.: consumo por OS). tenantId explícito
   * (padrão runWithTenant). Não chamar dentro de tx com I/O externo.
   */
  async applyMovement(tenantId: string, input: ApplyMovementInput) {
    return this.tenant.runWithTenant(tenantId, async () => {
      const item = await this.repo.findItemById(input.itemId);
      if (!item) throw new NotFoundException('Item não encontrado.');
      if (item.kind === 'service' || !item.track_stock) {
        throw new BadRequestException('Este item não controla estoque.');
      }
      const calc = computeMovement(toNum(item.stock_qty), input.type, input.quantity);
      return this.repo.createMovement(tenantId, input.itemId, {
        type: input.type,
        quantity: calc.quantity,
        balance_after: calc.balanceAfter,
        reason: input.reason ?? 'os_consumption',
        ref_type: input.refType ?? null,
        ref_id: input.refId ?? null,
        note: input.note ?? null,
        created_by: input.actorUserId ?? null,
      });
    });
  }
}
```

- [ ] **Step 2: Typecheck**

Run: `npm run -w back build`
Expected: no type errors. (`ForbiddenException` import may be unused — remove it if the linter flags it.)

- [ ] **Step 3: Commit**

```bash
git add back/src/modules/inventory/inventory.service.ts
git commit -m "feat(inventory): service (CRUD, movimentos, config, métodos públicos p/ OS)"
```

---

## Phase 6 — Controller + module wiring

### Task 8: Controller

**Files:**
- Create: `back/src/modules/inventory/inventory.controller.ts`

- [ ] **Step 1: Write the controller**

```ts
import {
  Body, Controller, Get, HttpCode, Param, Patch, Post, Query, UseGuards,
} from '@nestjs/common';
import { CurrentUser, Permissions } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';
import { ModuleAccessGuard } from '../billing/module-access.guard';
import { RequiresModule } from '../billing/requires-module.decorator';
import { InventoryService } from './inventory.service';
import { CreateItemDto, ListItemsQueryDto, UpdateItemDto } from './dto/item.dto';
import { CreateMovementDto } from './dto/movement.dto';
import { UpdateInventoryConfigDto } from './dto/config.dto';

@Controller('inventory')
@UseGuards(ModuleAccessGuard)
@RequiresModule('inventory')
export class InventoryController {
  constructor(private readonly inventory: InventoryService) {}

  // --- config (rotas literais antes de :id) ---
  @Get('config')
  @Permissions('inventory.read')
  getConfig(@CurrentUser() user: AuthUser) {
    return this.inventory.getConfig(user.tenantId);
  }

  @Patch('config')
  @Permissions('settings.manage')
  @HttpCode(200)
  updateConfig(@CurrentUser() user: AuthUser, @Body() dto: UpdateInventoryConfigDto) {
    return this.inventory.updateConfig(user, dto);
  }

  @Get('low-stock')
  @Permissions('inventory.read')
  lowStock(@CurrentUser() user: AuthUser) {
    return this.inventory.lowStock(user);
  }

  // --- items ---
  @Post('items')
  @Permissions('inventory.write')
  create(@CurrentUser() user: AuthUser, @Body() dto: CreateItemDto) {
    return this.inventory.createItem(user, dto);
  }

  @Get('items')
  @Permissions('inventory.read')
  list(@CurrentUser() user: AuthUser, @Query() query: ListItemsQueryDto) {
    return this.inventory.listItems(user, query);
  }

  @Get('items/:id')
  @Permissions('inventory.read')
  getOne(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.inventory.getItemOrThrow(id);
  }

  @Patch('items/:id')
  @Permissions('inventory.write')
  update(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: UpdateItemDto) {
    return this.inventory.updateItem(user, id, dto);
  }

  @Post('items/:id/archive')
  @Permissions('inventory.write')
  @HttpCode(200)
  archive(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.inventory.archiveItem(user, id);
  }

  @Post('items/:id/unarchive')
  @Permissions('inventory.write')
  @HttpCode(200)
  unarchive(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.inventory.unarchiveItem(user, id);
  }

  @Get('items/:id/movements')
  @Permissions('inventory.read')
  movements(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.inventory.listMovements(user, id);
  }

  @Post('items/:id/movements')
  @Permissions('inventory.write')
  registerMovement(@CurrentUser() user: AuthUser, @Param('id') id: string, @Body() dto: CreateMovementDto) {
    return this.inventory.registerMovement(user, id, dto);
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add back/src/modules/inventory/inventory.controller.ts
git commit -m "feat(inventory): controller (items, movimentos, low-stock, config)"
```

### Task 9: Module + register config section + wire into AppModule

**Files:**
- Create: `back/src/modules/inventory/inventory.module.ts`
- Modify: `back/src/app.module.ts`

- [ ] **Step 1: Write the module (registers its config section on boot)**

```ts
import { Module, OnModuleInit } from '@nestjs/common';
import { BillingModule } from '../billing/billing.module';
import { SettingsModule } from '../settings/settings.module';
import { SettingsSectionRegistry } from '../settings/settings.section-registry';
import { InventoryController } from './inventory.controller';
import { InventoryService } from './inventory.service';
import { InventoryRepository } from './inventory.repository';
import { INVENTORY_CONFIG_KEY } from './inventory.config';

/**
 * Módulo Estoque & Serviços — catálogo de itens (produto/serviço) + movimentações.
 * Genérico/multi-vertical. Importa BillingModule (config em tenant_module.settings +
 * ModuleAccessGuard) e SettingsModule (registra a própria seção de config no host).
 * Exporta InventoryService para a futura OS consumir ("aponta, não invade").
 */
@Module({
  imports: [BillingModule, SettingsModule],
  controllers: [InventoryController],
  providers: [InventoryService, InventoryRepository],
  exports: [InventoryService],
})
export class InventoryModule implements OnModuleInit {
  constructor(private readonly registry: SettingsSectionRegistry) {}

  onModuleInit(): void {
    this.registry.register({
      key: INVENTORY_CONFIG_KEY,
      title: 'Estoque & Serviços',
      moduleKey: 'inventory',
      fields: [
        { key: 'defaultUnit', label: 'Unidade padrão', type: 'text' },
        { key: 'trackStockDefault', label: 'Rastrear estoque por padrão?', type: 'bool' },
        { key: 'defaultMarginPercent', label: 'Margem padrão (%)', type: 'text' },
      ],
    });
  }
}
```

> The `categories` list is managed via `GET/PATCH /inventory/config` (rich endpoints), not the
> scalar settings section — same split as `customers`/`subjectFields`.

- [ ] **Step 2: Register `InventoryModule` in `app.module.ts`**

Add the import and include `InventoryModule` in the `imports` array of `AppModule`, next to `CustomersModule`:
```ts
import { InventoryModule } from './modules/inventory/inventory.module';
// ... in @Module({ imports: [ ... CustomersModule, InventoryModule, ... ] })
```

- [ ] **Step 3: Build + lint**

Run:
```bash
npm run -w back build
npm run back:lint
```
Expected: build OK; lint **0 warnings**. Fix any unused imports.

- [ ] **Step 4: Commit**

```bash
git add back/src/modules/inventory/inventory.module.ts back/src/app.module.ts
git commit -m "feat(inventory): module wiring + registro da seção de config + AppModule"
```

---

## Phase 7 — e2e tests

### Task 10: e2e — tenant isolation, authz, module gating, stock

**Files:**
- Create: `back/test/inventory.e2e-spec.ts`

> Mirror the structure of an existing e2e (e.g. `back/test/employees.e2e-spec.ts` or `customers.e2e-spec.ts`):
> spin up the app via testcontainers, register/login a tenant (trial) to get a token, and use supertest.
> Reuse whatever bootstrap/helpers those specs use (don't invent a new harness). Tenant B is a second
> registered tenant. Run with Redis FLUSHALL first.

- [ ] **Step 1: Write the e2e spec**

```ts
import { INestApplication } from '@nestjs/common';
import * as request from 'supertest';
// Reuse the same bootstrap helpers the other e2e specs use:
import { createTestApp, registerTenant, login } from './helpers'; // adjust import to match the repo's actual helpers

describe('Inventory (e2e)', () => {
  let app: INestApplication;
  let ownerA: string; // bearer
  let ownerB: string;

  beforeAll(async () => {
    app = await createTestApp();
    ownerA = await registerTenant(app, 'a@inv.test');
    ownerB = await registerTenant(app, 'b@inv.test');
  });
  afterAll(async () => { await app.close(); });

  const auth = (t: string) => ({ Authorization: `Bearer ${t}` });

  it('creates a product and lists it (trial sees inventory)', async () => {
    const created = await request(app.getHttpServer())
      .post('/api/inventory/items').set(auth(ownerA))
      .send({ kind: 'product', name: 'Óleo 5W30', unit: 'L', salePriceCents: 4500, costPriceCents: 3000, marginPercent: 50, minQty: 2 })
      .expect(201);
    expect(created.body.kind).toBe('product');
    expect(created.body.track_stock).toBe(true);

    const list = await request(app.getHttpServer())
      .get('/api/inventory/items').set(auth(ownerA)).expect(200);
    expect(list.body.items.map((i: any) => i.name)).toContain('Óleo 5W30');
  });

  it('isolates tenants — B does not see A items', async () => {
    const list = await request(app.getHttpServer())
      .get('/api/inventory/items').set(auth(ownerB)).expect(200);
    expect(list.body.items.find((i: any) => i.name === 'Óleo 5W30')).toBeUndefined();
  });

  it('records movements and updates cached balance', async () => {
    const item = (await request(app.getHttpServer())
      .post('/api/inventory/items').set(auth(ownerA))
      .send({ kind: 'product', name: 'Filtro de óleo', unit: 'un' }).expect(201)).body;

    await request(app.getHttpServer())
      .post(`/api/inventory/items/${item.id}/movements`).set(auth(ownerA))
      .send({ type: 'in', quantity: 10 }).expect(201);
    await request(app.getHttpServer())
      .post(`/api/inventory/items/${item.id}/movements`).set(auth(ownerA))
      .send({ type: 'out', quantity: 3 }).expect(201);

    const got = (await request(app.getHttpServer())
      .get(`/api/inventory/items/${item.id}`).set(auth(ownerA)).expect(200)).body;
    expect(Number(got.stock_qty)).toBe(7);

    const movs = (await request(app.getHttpServer())
      .get(`/api/inventory/items/${item.id}/movements`).set(auth(ownerA)).expect(200)).body;
    expect(movs.length).toBe(2);
  });

  it('blocks an out that would go negative', async () => {
    const item = (await request(app.getHttpServer())
      .post('/api/inventory/items').set(auth(ownerA))
      .send({ kind: 'product', name: 'Vela', unit: 'un' }).expect(201)).body;
    await request(app.getHttpServer())
      .post(`/api/inventory/items/${item.id}/movements`).set(auth(ownerA))
      .send({ type: 'out', quantity: 1 }).expect(400);
  });

  it('rejects movement on a service item', async () => {
    const svc = (await request(app.getHttpServer())
      .post('/api/inventory/items').set(auth(ownerA))
      .send({ kind: 'service', name: 'Troca de óleo', salePriceCents: 8000, durationMinutes: 30 }).expect(201)).body;
    expect(svc.track_stock).toBe(false);
    await request(app.getHttpServer())
      .post(`/api/inventory/items/${svc.id}/movements`).set(auth(ownerA))
      .send({ type: 'in', quantity: 1 }).expect(400);
  });

  it('lists low-stock items', async () => {
    const item = (await request(app.getHttpServer())
      .post('/api/inventory/items').set(auth(ownerA))
      .send({ kind: 'product', name: 'Pastilha', unit: 'un', minQty: 5 }).expect(201)).body;
    await request(app.getHttpServer())
      .post(`/api/inventory/items/${item.id}/movements`).set(auth(ownerA))
      .send({ type: 'in', quantity: 2 }).expect(201); // 2 <= 5
    const low = (await request(app.getHttpServer())
      .get('/api/inventory/low-stock').set(auth(ownerA)).expect(200)).body;
    expect(low.find((i: any) => i.name === 'Pastilha')).toBeDefined();
  });
});
```

> **Authz coverage:** if the repo's e2e helpers can create a `mechanic` membership + token, add a test
> that `mechanic` can `GET /api/inventory/items` (200) but `POST /api/inventory/items` returns 403
> (`inventory.write` denied). If creating a non-owner membership in e2e is non-trivial in this harness,
> cover the authz mapping in a service-level unit test instead and note it here.

- [ ] **Step 2: Run the e2e and verify it passes**

Run (per README §6):
```bash
redis-cli -p 6379 FLUSHALL
npm run back:test:e2e -- inventory
```
Expected: all inventory e2e tests PASS.

- [ ] **Step 3: Commit**

```bash
git add back/test/inventory.e2e-spec.ts
git commit -m "test(inventory): e2e — isolamento, movimentos, low-stock, guardrails"
```

---

## Phase 8 — Frontend feature

> Use the Flutter SDK by full path on this machine: `C:\Users\KaueSobral\develop\flutter\bin\flutter.bat`.
> Mirror `front/lib/features/customers/` exactly (domain → data → presentation; UI only via repository;
> freezed models; sealed state). Run `dart run build_runner build` after adding freezed models.

### Task 11: Domain models + repository interface

**Files:**
- Create: `front/lib/features/inventory/domain/inventory_models.dart`
- Create: `front/lib/features/inventory/domain/inventory_repository.dart`

- [ ] **Step 1: Write the freezed models**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'inventory_models.freezed.dart';
part 'inventory_models.g.dart';

enum ItemKind { product, service }

@freezed
class InventoryItem with _$InventoryItem {
  const factory InventoryItem({
    required String id,
    required String kind, // 'product' | 'service'
    required String name,
    String? code,
    String? barcode,
    String? category,
    required String unit,
    @JsonKey(name: 'sale_price_cents') @Default(0) int salePriceCents,
    @JsonKey(name: 'cost_price_cents') int? costPriceCents,
    @JsonKey(name: 'margin_percent') String? marginPercent,
    @Default(true) bool sellable,
    @JsonKey(name: 'track_stock') @Default(true) bool trackStock,
    @JsonKey(name: 'stock_qty') @Default('0') String stockQty,
    @JsonKey(name: 'min_qty') String? minQty,
    @JsonKey(name: 'duration_minutes') int? durationMinutes,
    String? brand,
    required String status,
  }) = _InventoryItem;
  factory InventoryItem.fromJson(Map<String, dynamic> json) => _$InventoryItemFromJson(json);
}

@freezed
class InventoryMovement with _$InventoryMovement {
  const factory InventoryMovement({
    required String id,
    required String type, // 'in' | 'out' | 'adjust'
    required String quantity,
    @JsonKey(name: 'balance_after') required String balanceAfter,
    String? reason,
    String? note,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _InventoryMovement;
  factory InventoryMovement.fromJson(Map<String, dynamic> json) => _$InventoryMovementFromJson(json);
}

@freezed
class ItemPage with _$ItemPage {
  const factory ItemPage({
    required List<InventoryItem> items,
    required int total,
    required int page,
    required int pageSize,
  }) = _ItemPage;
  factory ItemPage.fromJson(Map<String, dynamic> json) => _$ItemPageFromJson(json);
}

@freezed
class InventoryConfig with _$InventoryConfig {
  const factory InventoryConfig({
    required String defaultUnit,
    required bool trackStockDefault,
    double? defaultMarginPercent,
    @Default(<String>[]) List<String> categories,
  }) = _InventoryConfig;
  factory InventoryConfig.fromJson(Map<String, dynamic> json) => _$InventoryConfigFromJson(json);
}

/// Draft enviado ao backend (camelCase, igual aos DTOs).
class ItemDraft {
  final String kind, name, unit;
  final String? code, barcode, category, brand;
  final int? salePriceCents, costPriceCents, durationMinutes;
  final double? marginPercent, minQty;
  final bool? sellable, trackStock;
  ItemDraft({
    required this.kind, required this.name, required this.unit,
    this.code, this.barcode, this.category, this.brand,
    this.salePriceCents, this.costPriceCents, this.durationMinutes,
    this.marginPercent, this.minQty, this.sellable, this.trackStock,
  });
  Map<String, dynamic> toJson() => {
    'kind': kind, 'name': name, 'unit': unit,
    if (code != null) 'code': code,
    if (barcode != null) 'barcode': barcode,
    if (category != null) 'category': category,
    if (brand != null) 'brand': brand,
    if (salePriceCents != null) 'salePriceCents': salePriceCents,
    if (costPriceCents != null) 'costPriceCents': costPriceCents,
    if (durationMinutes != null) 'durationMinutes': durationMinutes,
    if (marginPercent != null) 'marginPercent': marginPercent,
    if (minQty != null) 'minQty': minQty,
    if (sellable != null) 'sellable': sellable,
    if (trackStock != null) 'trackStock': trackStock,
  };
}

class MovementDraft {
  final String type; final double quantity; final String? reason, note;
  MovementDraft({required this.type, required this.quantity, this.reason, this.note});
  Map<String, dynamic> toJson() => {
    'type': type, 'quantity': quantity,
    if (reason != null) 'reason': reason,
    if (note != null) 'note': note,
  };
}
```

- [ ] **Step 2: Write the repository interface**

```dart
import 'inventory_models.dart';

abstract interface class InventoryRepository {
  Future<InventoryConfig> fetchConfig();
  Future<ItemPage> listItems({String? q, String? kind, String? category, String status, bool lowStock, int page});
  Future<InventoryItem> getItem(String id);
  Future<InventoryItem> createItem(ItemDraft draft);
  Future<InventoryItem> updateItem(String id, ItemDraft draft);
  Future<InventoryItem> archiveItem(String id);
  Future<InventoryItem> unarchiveItem(String id);
  Future<List<InventoryMovement>> listMovements(String id);
  Future<InventoryMovement> registerMovement(String id, MovementDraft draft);
  Future<List<InventoryItem>> lowStock();
}
```

- [ ] **Step 3: Generate freezed/json code**

Run:
```bash
cd front && "C:\Users\KaueSobral\develop\flutter\bin\flutter.bat" pub get && dart run build_runner build --delete-conflicting-outputs
```
Expected: generates `inventory_models.freezed.dart` + `inventory_models.g.dart` with no errors.

- [ ] **Step 4: Commit**

```bash
git add front/lib/features/inventory/domain
git commit -m "feat(front/inventory): domain — models freezed + interface do repositório"
```

### Task 12: Data layer — dio impl + fake impl

**Files:**
- Create: `front/lib/features/inventory/data/inventory_repository_impl.dart`
- Create: `front/lib/features/inventory/data/fake_inventory_repository.dart`

- [ ] **Step 1: Write the dio implementation**

```dart
import 'package:dio/dio.dart';
import '../domain/inventory_models.dart';
import '../domain/inventory_repository.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final Dio _dio;
  InventoryRepositoryImpl(this._dio);

  @override
  Future<InventoryConfig> fetchConfig() async {
    final r = await _dio.get('/inventory/config');
    return InventoryConfig.fromJson(r.data as Map<String, dynamic>);
  }

  @override
  Future<ItemPage> listItems({String? q, String? kind, String? category, String status = 'active', bool lowStock = false, int page = 1}) async {
    final r = await _dio.get('/inventory/items', queryParameters: {
      if (q != null && q.isNotEmpty) 'q': q,
      if (kind != null) 'kind': kind,
      if (category != null && category.isNotEmpty) 'category': category,
      'status': status,
      if (lowStock) 'lowStock': true,
      'page': page,
    });
    return ItemPage.fromJson(r.data as Map<String, dynamic>);
  }

  @override
  Future<InventoryItem> getItem(String id) async =>
      InventoryItem.fromJson((await _dio.get('/inventory/items/$id')).data as Map<String, dynamic>);

  @override
  Future<InventoryItem> createItem(ItemDraft draft) async =>
      InventoryItem.fromJson((await _dio.post('/inventory/items', data: draft.toJson())).data as Map<String, dynamic>);

  @override
  Future<InventoryItem> updateItem(String id, ItemDraft draft) async =>
      InventoryItem.fromJson((await _dio.patch('/inventory/items/$id', data: draft.toJson())).data as Map<String, dynamic>);

  @override
  Future<InventoryItem> archiveItem(String id) async =>
      InventoryItem.fromJson((await _dio.post('/inventory/items/$id/archive')).data as Map<String, dynamic>);

  @override
  Future<InventoryItem> unarchiveItem(String id) async =>
      InventoryItem.fromJson((await _dio.post('/inventory/items/$id/unarchive')).data as Map<String, dynamic>);

  @override
  Future<List<InventoryMovement>> listMovements(String id) async {
    final r = await _dio.get('/inventory/items/$id/movements');
    return (r.data as List).map((e) => InventoryMovement.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<InventoryMovement> registerMovement(String id, MovementDraft draft) async =>
      InventoryMovement.fromJson((await _dio.post('/inventory/items/$id/movements', data: draft.toJson())).data as Map<String, dynamic>);

  @override
  Future<List<InventoryItem>> lowStock() async {
    final r = await _dio.get('/inventory/low-stock');
    return (r.data as List).map((e) => InventoryItem.fromJson(e as Map<String, dynamic>)).toList();
  }
}
```

- [ ] **Step 2: Write the fake implementation (in-memory; for widget tests + offline dev)**

```dart
import '../domain/inventory_models.dart';
import '../domain/inventory_repository.dart';

class FakeInventoryRepository implements InventoryRepository {
  final _items = <String, InventoryItem>{};
  final _movs = <String, List<InventoryMovement>>{};
  int _seq = 0;

  @override
  Future<InventoryConfig> fetchConfig() async =>
      const InventoryConfig(defaultUnit: 'un', trackStockDefault: true, categories: []);

  @override
  Future<ItemPage> listItems({String? q, String? kind, String? category, String status = 'active', bool lowStock = false, int page = 1}) async {
    var list = _items.values.where((i) => status == 'all' || i.status == status);
    if (kind != null) list = list.where((i) => i.kind == kind);
    if (q != null && q.isNotEmpty) list = list.where((i) => i.name.toLowerCase().contains(q.toLowerCase()));
    if (lowStock) list = list.where((i) => i.trackStock && i.minQty != null && double.parse(i.stockQty) <= double.parse(i.minQty!));
    final items = list.toList();
    return ItemPage(items: items, total: items.length, page: 1, pageSize: 20);
  }

  @override
  Future<InventoryItem> getItem(String id) async => _items[id]!;

  @override
  Future<InventoryItem> createItem(ItemDraft d) async {
    final id = 'item-${_seq++}';
    final item = InventoryItem(
      id: id, kind: d.kind, name: d.name, unit: d.unit, code: d.code, category: d.category,
      salePriceCents: d.salePriceCents ?? 0, costPriceCents: d.costPriceCents,
      trackStock: d.kind == 'product' ? (d.trackStock ?? true) : false,
      stockQty: '0', minQty: d.minQty?.toString(), durationMinutes: d.durationMinutes,
      brand: d.brand, status: 'active',
    );
    _items[id] = item; _movs[id] = [];
    return item;
  }

  @override
  Future<InventoryItem> updateItem(String id, ItemDraft d) async {
    final cur = _items[id]!;
    final next = cur.copyWith(name: d.name, unit: d.unit, salePriceCents: d.salePriceCents ?? cur.salePriceCents);
    _items[id] = next; return next;
  }

  @override
  Future<InventoryItem> archiveItem(String id) async {
    final next = _items[id]!.copyWith(status: 'archived'); _items[id] = next; return next;
  }
  @override
  Future<InventoryItem> unarchiveItem(String id) async {
    final next = _items[id]!.copyWith(status: 'active'); _items[id] = next; return next;
  }

  @override
  Future<List<InventoryMovement>> listMovements(String id) async => _movs[id] ?? [];

  @override
  Future<InventoryMovement> registerMovement(String id, MovementDraft d) async {
    final cur = _items[id]!;
    final balance = d.type == 'in'
        ? double.parse(cur.stockQty) + d.quantity
        : d.type == 'out'
            ? double.parse(cur.stockQty) - d.quantity
            : d.quantity;
    final m = InventoryMovement(
      id: 'mov-${_seq++}', type: d.type, quantity: d.quantity.toString(),
      balanceAfter: balance.toString(), reason: d.reason, note: d.note, createdAt: '2026-01-01T00:00:00Z',
    );
    _items[id] = cur.copyWith(stockQty: balance.toString());
    (_movs[id] ??= []).insert(0, m);
    return m;
  }

  @override
  Future<List<InventoryItem>> lowStock() async =>
      _items.values.where((i) => i.trackStock && i.minQty != null && double.parse(i.stockQty) <= double.parse(i.minQty!)).toList();
}
```

- [ ] **Step 3: Analyze**

Run: `cd front && "C:\Users\KaueSobral\develop\flutter\bin\flutter.bat" analyze`
Expected: no issues in the new files (some presentation files don't exist yet — that's fine until Task 13).

- [ ] **Step 4: Commit**

```bash
git add front/lib/features/inventory/data
git commit -m "feat(front/inventory): data — impl dio + impl fake do repositório"
```

### Task 13: Presentation — providers, list screen (icons), item form, detail+movements

**Files:**
- Create: `front/lib/features/inventory/presentation/inventory_providers.dart`
- Create: `front/lib/features/inventory/presentation/inventory_screen.dart`
- Create: `front/lib/features/inventory/presentation/item_form_dialog.dart`
- Create: `front/lib/features/inventory/presentation/item_detail_screen.dart`

- [ ] **Step 1: Providers**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/inventory_models.dart';
import '../domain/inventory_repository.dart';

// Bound in di.dart to the dio-backed impl (overridden with the fake in tests).
final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  throw UnimplementedError('inventoryRepositoryProvider must be overridden in di.dart');
});

final inventoryConfigProvider = FutureProvider<InventoryConfig>((ref) =>
    ref.watch(inventoryRepositoryProvider).fetchConfig());

class ItemListQuery {
  final String? q; final String? kind; final String status; final bool lowStock;
  const ItemListQuery({this.q, this.kind, this.status = 'active', this.lowStock = false});
}

final itemListQueryProvider = StateProvider<ItemListQuery>((ref) => const ItemListQuery());

final itemListProvider = FutureProvider<ItemPage>((ref) {
  final query = ref.watch(itemListQueryProvider);
  return ref.watch(inventoryRepositoryProvider).listItems(
        q: query.q, kind: query.kind, status: query.status, lowStock: query.lowStock,
      );
});

final itemMovementsProvider = FutureProvider.family<List<InventoryMovement>, String>((ref, id) =>
    ref.watch(inventoryRepositoryProvider).listMovements(id));
```

- [ ] **Step 2: List screen — with icons per kind + low-stock badge**

Write `inventory_screen.dart` following the visual conventions of `customers_screen.dart` (the AppShell provides the frame; this returns the body). Requirements (product ask — make it lively):
- Header row with a search field, a Produto/Serviço filter (segmented or chips), and a "Só estoque baixo" toggle (drives `itemListQueryProvider`).
- Each row uses an **icon by kind**: `Icons.inventory_2_outlined` for product, `Icons.build_outlined` (or `Icons.design_services_outlined`) for service.
- Show price (format cents → `R$`), and for products the `stockQty`; if low-stock, a tangerine warning `Chip`/badge with `Icons.warning_amber_rounded`.
- FAB (`Icons.add`) opens `ItemFormDialog`; tapping a row pushes `ItemDetailScreen`.
- Use `AppColors`/`AppTheme` tokens; PT-BR strings. On `AppException`, show an inline error with a retry.

```dart
// Skeleton — fill the body following customers_screen.dart conventions.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/inventory_models.dart';
import 'inventory_providers.dart';
import 'item_form_dialog.dart';
import 'item_detail_screen.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  IconData iconFor(String kind) =>
      kind == 'service' ? Icons.design_services_outlined : Icons.inventory_2_outlined;

  String money(int cents) => 'R\$ ${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')}';

  bool isLow(InventoryItem i) =>
      i.trackStock && i.minQty != null && double.parse(i.stockQty) <= double.parse(i.minQty!);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageAsync = ref.watch(itemListProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Novo item'),
        onPressed: () => showDialog(context: context, builder: (_) => const ItemFormDialog()),
      ),
      body: Column(children: [
        // TODO(impl): search field + kind chips + low-stock switch wired to itemListQueryProvider.
        Expanded(child: pageAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
          data: (page) => ListView.separated(
            itemCount: page.items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, idx) {
              final i = page.items[idx];
              return ListTile(
                leading: Icon(iconFor(i.kind)),
                title: Text(i.name),
                subtitle: Text(i.kind == 'service'
                    ? 'Serviço · ${money(i.salePriceCents)}'
                    : 'Estoque: ${i.stockQty} ${i.unit} · ${money(i.salePriceCents)}'),
                trailing: isLow(i)
                    ? const Chip(avatar: Icon(Icons.warning_amber_rounded, size: 18), label: Text('Baixo'))
                    : null,
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ItemDetailScreen(itemId: i.id))),
              );
            },
          ),
        )),
      ]),
    );
  }
}
```

- [ ] **Step 3: Item form dialog — kind toggle adapts fields + markup helper**

Write `item_form_dialog.dart`: a dialog with a Produto/Serviço toggle at top. When **Produto**: show code, barcode, category (autocomplete from `inventoryConfigProvider.categories`), unit, cost + margin (live-suggests `salePrice` via `cost*(1+margin/100)`, editable), min_qty, brand. When **Serviço**: show code, category, price, durationMinutes (hide stock/barcode/min_qty). On save, build an `ItemDraft` and call `createItem`/`updateItem`, then `ref.invalidate(itemListProvider)`. PT-BR labels, icons on section headers.

```dart
// Skeleton — implement the two field sets per kind + the markup live-suggest.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/inventory_models.dart';
import 'inventory_providers.dart';

class ItemFormDialog extends ConsumerStatefulWidget {
  final InventoryItem? existing;
  const ItemFormDialog({super.key, this.existing});
  @override
  ConsumerState<ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends ConsumerState<ItemFormDialog> {
  String _kind = 'product';
  // controllers: name, code, unit, salePrice, cost, margin, minQty, duration, brand...
  int _suggestedPriceCents(int costCents, double margin) => (costCents * (1 + margin / 100)).round();

  @override
  Widget build(BuildContext context) {
    // TODO(impl): AlertDialog with a SegmentedButton<String>(_kind) and the per-kind field sets.
    // On cost/margin change, setState and prefill the price field with _suggestedPriceCents(...).
    return const AlertDialog(content: Text('ItemFormDialog — implementar campos por tipo + markup'));
  }
}
```

- [ ] **Step 4: Item detail + movements**

Write `item_detail_screen.dart`: shows item fields; for products a "Registrar movimento" action (dialog: type in/out/adjust + quantity + reason/note) calling `registerMovement` then `ref.invalidate(itemMovementsProvider(id))` and `itemListProvider`; renders the movement history list with **icons per type** (`Icons.south_west` in, `Icons.north_east` out, `Icons.tune` adjust) and the resulting balance. Archive/unarchive button. PT-BR strings; design-system tokens.

- [ ] **Step 5: Generate, analyze**

Run:
```bash
cd front && dart run build_runner build --delete-conflicting-outputs && "C:\Users\KaueSobral\develop\flutter\bin\flutter.bat" analyze
```
Expected: **No issues found!** (Implement the TODO bodies until analyze is clean — no `TODO`-only widgets left that break analysis; placeholders that compile are acceptable only if they compile and pass analyze.)

- [ ] **Step 6: Commit**

```bash
git add front/lib/features/inventory/presentation
git commit -m "feat(front/inventory): presentation — lista (ícones), form por tipo + markup, detalhe + movimentos"
```

### Task 14: Wire into di.dart, router, and the nav menu

**Files:**
- Modify: `front/lib/di.dart`
- Modify: `front/lib/core/router/app_router.dart`
- Modify: `front/lib/features/shell/presentation/nav_items.dart`

- [ ] **Step 1: Override the repository provider in `di.dart`**

In the composition root, override `inventoryRepositoryProvider` with the dio-backed impl, mirroring how `customersRepositoryProvider` is wired (same Dio instance/interceptor):
```dart
inventoryRepositoryProvider.overrideWithValue(InventoryRepositoryImpl(ref.read(dioProvider))),
```
(Use the exact Dio provider name this project already uses — match the customers wiring.)

- [ ] **Step 2: Add the gated route**

In `app_router.dart`, add a route `/inventory` → `InventoryScreen`, guarded by module `inventory` exactly like the `customers` route (the router already gates by `me.modules`; copy that pattern).

- [ ] **Step 3: Add the nav item**

In `nav_items.dart`, add the Estoque entry to `gatedNavItems` keyed on module `inventory`:
```dart
// label 'Estoque', icon Icons.inventory_2_outlined, route '/inventory', requiredModule 'inventory'
```
Match the exact `NavItem` shape used by the existing entries.

- [ ] **Step 4: Analyze + run the relevant tests**

Run:
```bash
cd front && "C:\Users\KaueSobral\develop\flutter\bin\flutter.bat" analyze && "C:\Users\KaueSobral\develop\flutter\bin\flutter.bat" test
```
Expected: **No issues found!**; existing + new tests pass.

- [ ] **Step 5: Commit**

```bash
git add front/lib/di.dart front/lib/core/router/app_router.dart front/lib/features/shell/presentation/nav_items.dart
git commit -m "feat(front/inventory): wiring — di + rota gated + item de menu"
```

### Task 15: Front widget test — list renders + low-stock badge (with fake repo)

**Files:**
- Create: `front/test/inventory_screen_test.dart`

- [ ] **Step 1: Write a widget test using the fake repository**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub/features/inventory/data/fake_inventory_repository.dart';
import 'package:orbixhub/features/inventory/domain/inventory_models.dart';
import 'package:orbixhub/features/inventory/presentation/inventory_providers.dart';
import 'package:orbixhub/features/inventory/presentation/inventory_screen.dart';
// NOTE: adjust the package import name ('orbixhub') to match front/pubspec.yaml `name:`.

void main() {
  testWidgets('lista mostra item e badge de estoque baixo', (tester) async {
    final fake = FakeInventoryRepository();
    await fake.createItem(ItemDraft(kind: 'product', name: 'Pastilha', unit: 'un', minQty: 5));
    // sem entrada de estoque → stock 0 <= min 5 → low

    await tester.pumpWidget(ProviderScope(
      overrides: [inventoryRepositoryProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: InventoryScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Pastilha'), findsOneWidget);
    expect(find.text('Baixo'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test**

Run: `cd front && "C:\Users\KaueSobral\develop\flutter\bin\flutter.bat" test test/inventory_screen_test.dart`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add front/test/inventory_screen_test.dart
git commit -m "test(front/inventory): widget test da lista + badge de estoque baixo"
```

---

## Phase 9 — Docs + final verification

### Task 16: Documentation

**Files:**
- Modify: `docs/configuracao.md`
- Modify: `docs/modulos-v1.md`

- [ ] **Step 1: Add the inventory config subsection to `docs/configuracao.md`**

Append a new subsection under "Seções" (mirroring the customers one):
```markdown
### Estoque & Serviços (módulo `inventory`)
Seção registrada pelo módulo `inventory` — aparece em `GET /settings` quando o módulo
está habilitado. Valores em `tenant_module.settings['inventory']` (lidos/gravados via
`BillingService`, "aponta, não invade").

| Config | Chave | Tipo | Default | Obs |
|---|---|---|---|---|
| Unidade padrão | `defaultUnit` | text | `un` | pré-seleção ao cadastrar produto |
| Rastrear estoque por padrão | `trackStockDefault` | bool | `true` | novos produtos nascem rastreáveis |
| Margem padrão (%) | `defaultMarginPercent` | number | `null` | usada pelo helper de markup |
| Sugestões de categoria | `categories` | lista text | `[]` | autocomplete; valor salvo é texto livre |

- Leitura/escrita rica: `GET /inventory/config` (`inventory.read`) e
  `PATCH /inventory/config` (`settings.manage`). A lista `categories` é gerida por esses
  endpoints; a seção do host expõe só os escalares.
```

- [ ] **Step 2: Mark `inventory` as implemented in `docs/modulos-v1.md`**

In the modules table, update the `inventory` row to `contratável _(implementado)_` with a short description: catálogo de itens (produto/serviço) + movimentações de estoque com histórico, markup manual, low-stock; service público `getItem`/`applyMovement` pronto p/ a OS. Add a note that `inventory` agora também faz parte do plano `trial`.

- [ ] **Step 3: Commit**

```bash
git add docs/configuracao.md docs/modulos-v1.md
git commit -m "docs(inventory): seção de config + inventário de módulos atualizado"
```

### Task 17: Full verification pass (evidence before "done")

- [ ] **Step 1: Backend — lint + unit + e2e**

Run:
```bash
npm run back:lint
npm run back:test
redis-cli -p 6379 FLUSHALL && npm run back:test:e2e
```
Expected: lint **0 warnings**; unit green; e2e green. Paste the real output into the PR/commit notes.

- [ ] **Step 2: Frontend — analyze + test**

Run:
```bash
cd front && "C:\Users\KaueSobral\develop\flutter\bin\flutter.bat" analyze && "C:\Users\KaueSobral\develop\flutter\bin\flutter.bat" test
```
Expected: **No issues found!**; all tests pass.

- [ ] **Step 3: Manual smoke (optional but recommended)**

Run the backend on the alt port and the Flutter web app, log in as `dono@teste.com` / `senha12345` (trial), confirm "Estoque" appears in the menu, create a product + service, register an `in` then `out` movement, see the balance update and the low-stock badge.
```bash
PORT=4400 npm run back:dev
cd front && "C:\Users\KaueSobral\develop\flutter\bin\flutter.bat" run -d chrome --web-port 8090 --dart-define=API_BASE_URL=http://localhost:4400/api
```
(Add `http://localhost:8090` to `CORS_ORIGINS`.)

- [ ] **Step 4: Final commit / open PR**

```bash
git log --oneline feat/inventory ^feat/customers-subjects
# open a PR against feat/billing-modules (the repo's main integration branch) when ready
```

---

## Self-Review (filled by plan author)

**Spec coverage:** ✅ catalog product/service (Tasks 5–8,11–13) · ✅ movements+history+cached balance (Tasks 1,4,6,7,10,13) · ✅ manual markup (Task 4 `suggestPriceCents`, Task 13 live-suggest) · ✅ min_qty + low-stock filter (Tasks 1,6,8,10,13) · ✅ config + registry section (Tasks 4,9,16) · ✅ soft delete archive (Tasks 6,7,8) · ✅ RLS+FORCE (Tasks 1,2) · ✅ public service `getItem`/`applyMovement`/`searchForPicker` (Task 7) · ✅ trial plan seed (Tasks 1,2) · ✅ roles already mapped — no seed change · ✅ front feature + icons (Tasks 11–15) · ✅ migration in 3 places (Tasks 1,2,3) · ✅ tests (Tasks 4,10,15,17).

**Type consistency:** `computeMovement`/`suggestPriceCents`/`mergeInventoryConfig` signatures identical across config, service, and tests. DTO field names (camelCase) match the front `ItemDraft.toJson()` and the controller bodies. Prisma column names (snake_case) match the migration, baseline, and repository.

**Known fill-ins (not placeholders — they require reading neighbor code that exists):** e2e bootstrap helpers (Task 10) and the Dio provider name + `NavItem` shape (Task 14) must match the repo's actual names — each step says to mirror the existing `customers` wiring rather than invent. The Flutter screen bodies (Task 13) are specified behaviorally with compiling skeletons; implement to the stated requirements and the `customers` visual conventions.

**Pendências (out of scope, tracked):** feature-gating layer, low-stock dashboard/alerts, AI pricing, stock valuation/total value, reports, suppliers, CSV import, kits, barcode scanner, unit conversion, multi-warehouse, configurable negative stock, `applyMovement` idempotency — all in `docs/pendencias.md`.
```
