# Estoque: Ledger de Movimentos + Estorno na OS — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cancelar ou editar uma OS em execução passa a estornar/ajustar o estoque corretamente, via um diário de movimentos (`stock_movement`) que substitui a semântica do booleano `stock_applied`.

**Architecture:** O módulo `inventory` ganha uma tabela-diário `stock_movement` (RLS+FORCE) e é dono de toda a contabilidade; `inventory_item.current_stock` continua como saldo materializado. O módulo `os` chama um único método público de reconciliação (`reconcileConsumption`) por linha-produto, sempre que o status muda ou um item é editado, passando a quantidade-alvo (`consome(status) ? qty : 0`). "Aponta, não invade": a OS nunca toca `stock_movement`/`inventory_item`; o inventory deriva o consumo já registrado do próprio diário por `ref_item_id`.

**Tech Stack:** NestJS (TypeScript), PostgreSQL + RLS, Prisma (client/tipos mantidos à mão), Jest + Supertest + Testcontainers (e2e).

## Global Constraints

- **Migrations ADITIVAS nos 3 lugares mantidos juntos:** `back/sql/auth-multitenant-schema.sql` (canônico/idempotente) + `back/prisma/migrations/0024_stock_movement/migration.sql` + `back/prisma/schema.prisma`. Próximo número = `0024` (último é `0023_report_module`). Não usar `prisma migrate deploy` — schema sobe via `scripts/ci-db-setup.ts` como `app_owner`.
- **Toda tabela tenant-scoped:** RLS + FORCE + policy `tenant_isolation USING (tenant_id = current_tenant_id())` + `GRANT SELECT, INSERT, UPDATE, DELETE ... TO app_user`.
- **Aponta, não invade:** o `os` referencia o `inventory` só por id + service público; nunca lê/escreve `stock_movement` nem `inventory_item`.
- **Pool de conexões:** chamadas ao `inventory` (que abrem a própria tx via `runWithTenant`) rodam SEMPRE fora de qualquer `withTenantTx` do `os`. Nunca aninhar.
- **Best-effort (v1):** estoque insuficiente / falha de movimento **não** bloqueia a transição nem a edição da OS — apenas loga aviso (mantém o comportamento atual do `applyStock`).
- **Sem hard delete** de registros históricos; movimentos de estoque nunca são apagados (estorno é um novo movimento, não a remoção do anterior).
- **Strings de usuário em PT-BR**; comentários técnicos podem ser em inglês (siga o arquivo vizinho).
- **Qualidade:** `npm run back:lint` 0 warnings; `back:test` + `back:test:e2e` verdes. Cite o output real antes de "pronto".
- **CONSUMINDO** = conjunto de status que consomem estoque = `{ em_execucao, concluida, entregue }`.

---

### Task 1: Helper puro de reconciliação (`computeReconcile`)

A matemática do delta é pura e merece teste isolado (padrão de `low-stock.ts`/`crossedIntoLowStock`). Os demais passos dependem dela.

**Files:**
- Create: `back/src/modules/inventory/stock-reconcile.ts`
- Test: `back/src/modules/inventory/stock-reconcile.spec.ts`

**Interfaces:**
- Consumes: nada.
- Produces:
  ```ts
  export type StockMovementReason = 'os_consumption' | 'os_reversal';
  export interface ReconcileResult {
    stockDelta: number; // somar ao current_stock: negativo=consumo, positivo=estorno
    reason: StockMovementReason;
  }
  export function computeReconcile(
    prevConsumed: number,
    targetConsumed: number,
  ): ReconcileResult | null; // null quando não há mudança
  ```

- [ ] **Step 1: Write the failing test**

```ts
// back/src/modules/inventory/stock-reconcile.spec.ts
import { computeReconcile } from './stock-reconcile';

describe('computeReconcile', () => {
  it('consome quando o alvo sobe a partir de zero (baixa)', () => {
    expect(computeReconcile(0, 3)).toEqual({
      stockDelta: -3,
      reason: 'os_consumption',
    });
  });

  it('estorna tudo quando o alvo cai a zero (cancelamento)', () => {
    expect(computeReconcile(3, 0)).toEqual({
      stockDelta: 3,
      reason: 'os_reversal',
    });
  });

  it('estorna a diferença quando o alvo diminui (redução de qtd)', () => {
    expect(computeReconcile(3, 1)).toEqual({
      stockDelta: 2,
      reason: 'os_reversal',
    });
  });

  it('baixa a mais quando o alvo aumenta', () => {
    expect(computeReconcile(1, 4)).toEqual({
      stockDelta: -3,
      reason: 'os_consumption',
    });
  });

  it('retorna null quando não há mudança (idempotência)', () => {
    expect(computeReconcile(2, 2)).toBeNull();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd back && npx jest src/modules/inventory/stock-reconcile.spec.ts`
Expected: FAIL — "Cannot find module './stock-reconcile'".

- [ ] **Step 3: Write minimal implementation**

```ts
// back/src/modules/inventory/stock-reconcile.ts
export type StockMovementReason = 'os_consumption' | 'os_reversal';

export interface ReconcileResult {
  /** Valor a somar ao current_stock: negativo = consumo (saída), positivo = estorno (entrada). */
  stockDelta: number;
  reason: StockMovementReason;
}

/**
 * Calcula o movimento de estoque necessário para levar o consumo já registrado
 * de uma linha (`prevConsumed`) até o consumo desejado (`targetConsumed`).
 * Função pura e idempotente: alvo igual ao atual → null (nenhum movimento).
 */
export function computeReconcile(
  prevConsumed: number,
  targetConsumed: number,
): ReconcileResult | null {
  const deltaConsumed = targetConsumed - prevConsumed;
  if (deltaConsumed === 0) return null;
  return {
    stockDelta: -deltaConsumed,
    reason: deltaConsumed > 0 ? 'os_consumption' : 'os_reversal',
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd back && npx jest src/modules/inventory/stock-reconcile.spec.ts`
Expected: PASS (5 testes).

- [ ] **Step 5: Commit**

```bash
git add back/src/modules/inventory/stock-reconcile.ts back/src/modules/inventory/stock-reconcile.spec.ts
git commit -m "feat(inventory): helper puro computeReconcile (delta de estoque por linha)"
```

---

### Task 2: Migração `0024_stock_movement` (3 lugares + backfill)

Cria a tabela-diário, espelha em prisma, e faz backfill das OS já aplicadas para que o consumo derivado bata com o saldo histórico.

**Files:**
- Create: `back/prisma/migrations/0024_stock_movement/migration.sql`
- Modify: `back/sql/auth-multitenant-schema.sql` (após o bloco de `inventory_item`, ~linha 660, antes de `service_order`)
- Modify: `back/prisma/schema.prisma` (novo `model stock_movement` + back-relation em `model tenant`)

**Interfaces:**
- Consumes: nada.
- Produces: tabela `stock_movement` e o model Prisma `stock_movement` com colunas: `id uuid`, `tenant_id uuid`, `inventory_item_id uuid`, `stock_delta numeric(14,3)`, `reason text`, `ref_type text`, `ref_id uuid`, `ref_item_id uuid?`, `created_by uuid?`, `created_at timestamptz`.

- [ ] **Step 1: Escrever a migração SQL**

```sql
-- back/prisma/migrations/0024_stock_movement/migration.sql
-- ============================================================
-- 0024 — Stock movement (diário de estoque) — aditivo, idempotente
-- ============================================================
-- Diário de movimentos do estoque. current_stock continua como SALDO
-- materializado; cada movimento o ajusta. Substitui a semântica do booleano
-- service_order.stock_applied (mantido por ora, deprecado). Genérico via
-- ref_type/ref_id/ref_item_id. RLS + FORCE como toda tabela tenant-scoped.

CREATE TABLE IF NOT EXISTS stock_movement (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  inventory_item_id uuid NOT NULL REFERENCES inventory_item(id) ON DELETE CASCADE,
  stock_delta       numeric(14,3) NOT NULL,        -- negativo = saída; positivo = entrada
  reason            text NOT NULL,                 -- 'os_consumption' | 'os_reversal'
  ref_type          text NOT NULL,                 -- 'service_order'
  ref_id            uuid NOT NULL,                 -- id da OS
  ref_item_id       uuid,                          -- id da service_order_item (chave da reconciliação)
  created_by        uuid,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_stock_movement_tenant
  ON stock_movement(tenant_id);
CREATE INDEX IF NOT EXISTS idx_stock_movement_item
  ON stock_movement(inventory_item_id);
CREATE INDEX IF NOT EXISTS idx_stock_movement_ref_item
  ON stock_movement(ref_item_id);
CREATE INDEX IF NOT EXISTS idx_stock_movement_ref
  ON stock_movement(ref_type, ref_id);

-- RLS + FORCE + policy (idempotente).
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['stock_movement']
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

GRANT SELECT, INSERT, UPDATE, DELETE ON stock_movement TO app_user;

-- Backfill: para OS já aplicadas (stock_applied) e ainda consumindo, insere um
-- movimento-espelho por linha-produto para que o consumo DERIVADO bata com o
-- saldo histórico. NÃO ajusta current_stock (o saldo já reflete a baixa).
-- Guardado por NOT EXISTS → idempotente em re-execução.
INSERT INTO stock_movement
  (tenant_id, inventory_item_id, stock_delta, reason, ref_type, ref_id, ref_item_id)
SELECT i.tenant_id, i.inventory_item_id, -i.quantity, 'os_consumption',
       'service_order', i.order_id, i.id
FROM service_order_item i
JOIN service_order o ON o.id = i.order_id
WHERE o.stock_applied = true
  AND o.status IN ('em_execucao','concluida','entregue')
  AND i.kind = 'product'
  AND i.inventory_item_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM stock_movement sm WHERE sm.ref_item_id = i.id
  );
```

- [ ] **Step 2: Espelhar no schema canônico**

Em `back/sql/auth-multitenant-schema.sql`, logo após o bloco de RLS/GRANT de `inventory_item` (após ~linha 660, antes do comentário do `service_order`), cole **o mesmo conteúdo** do Step 1 (a partir de `CREATE TABLE IF NOT EXISTS stock_movement` até o INSERT de backfill, inclusive). O arquivo é idempotente — o `CREATE TABLE IF NOT EXISTS`, o bloco RLS guardado e o backfill com `NOT EXISTS` podem ser reaplicados sem efeito colateral.

- [ ] **Step 3: Adicionar o model Prisma + back-relation**

Em `back/prisma/schema.prisma`, adicione o model novo (perto de `inventory_item`, após a linha 93):

```prisma
/// This model contains row level security and requires additional setup for migrations. Visit https://pris.ly/d/row-level-security for more info.
model stock_movement {
  id                String   @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  tenant_id         String   @db.Uuid
  inventory_item_id String   @db.Uuid
  stock_delta       Decimal  @db.Decimal(14, 3)
  reason            String
  ref_type          String
  ref_id            String   @db.Uuid
  ref_item_id       String?  @db.Uuid
  created_by        String?  @db.Uuid
  created_at        DateTime @default(now()) @db.Timestamptz(6)
  tenant            tenant   @relation(fields: [tenant_id], references: [id], onDelete: Cascade, onUpdate: NoAction)

  @@index([tenant_id], map: "idx_stock_movement_tenant")
  @@index([inventory_item_id], map: "idx_stock_movement_item")
  @@index([ref_item_id], map: "idx_stock_movement_ref_item")
  @@index([ref_type, ref_id], map: "idx_stock_movement_ref")
}
```

E no `model tenant`, adicione a back-relation (mantendo a ordem alfabética da lista de relações, perto de `subscription`):

```prisma
  stock_movement     stock_movement[]
```

- [ ] **Step 4: Gerar o client e validar o schema**

Run: `cd back && npx prisma generate`
Expected: "Generated Prisma Client" sem erros de validação (back-relation resolvida). Se reclamar de relação faltando, confira o Step 3.

- [ ] **Step 5: Recriar o banco local e conferir a tabela**

Run: `cd back && npm run db:setup` (aplica o schema canônico como `app_owner`; ver README §3)
Then: verifique que a tabela existe — `psql "$DATABASE_URL" -c "\d stock_movement"` deve listar as colunas e a policy `tenant_isolation`.
Expected: tabela presente com RLS habilitada.

> Se o nome do script `db:setup` divergir nesta máquina, use o comando equivalente do README §3 que roda `scripts/ci-db-setup.ts`.

- [ ] **Step 6: Commit**

```bash
git add back/prisma/migrations/0024_stock_movement/migration.sql back/sql/auth-multitenant-schema.sql back/prisma/schema.prisma
git commit -m "feat(inventory): migração 0024 stock_movement (diário + backfill) nos 3 lugares"
```

---

### Task 3: Repository — persistir movimento + derivar consumo

Único ponto que toca `stock_movement`. Adiciona criação de movimento e a soma do consumo já registrado por linha.

**Files:**
- Modify: `back/src/modules/inventory/inventory.repository.ts`

**Interfaces:**
- Consumes: `TenantContext.getClient()` (já injetado).
- Produces (métodos públicos em `InventoryRepository`):
  ```ts
  createStockMovement(tenantId: string, data: {
    inventory_item_id: string;
    stock_delta: number;
    reason: 'os_consumption' | 'os_reversal';
    ref_type: string;
    ref_id: string;
    ref_item_id: string | null;
    created_by: string | null;
  }): Promise<unknown>;

  /** Consumo já registrado para uma linha de origem = -Σ(stock_delta) dos movimentos. */
  sumConsumedByRefItem(refItemId: string): Promise<number>;
  ```

- [ ] **Step 1: Implementar os métodos no repository**

Adicione ao final da classe `InventoryRepository` (antes do fechamento `}`), perto de `adjustStock`:

```ts
  // ---- diário de estoque (stock_movement) ----
  createStockMovement(
    tenantId: string,
    data: {
      inventory_item_id: string;
      stock_delta: Prisma.Decimal | number;
      reason: 'os_consumption' | 'os_reversal';
      ref_type: string;
      ref_id: string;
      ref_item_id: string | null;
      created_by: string | null;
    },
  ) {
    const db = this.tenant.getClient();
    return db.stock_movement.create({
      data: {
        tenant_id: tenantId,
        ...data,
      } as Prisma.stock_movementUncheckedCreateInput,
    });
  }

  /**
   * Consumo já registrado para uma linha de origem (ex.: item de OS):
   * -Σ(stock_delta) dos movimentos dessa linha. Consumo reduz o saldo
   * (stock_delta negativo), então a soma negada dá o consumido positivo.
   * Tenant-scoped por RLS.
   */
  async sumConsumedByRefItem(refItemId: string): Promise<number> {
    const db = this.tenant.getClient();
    const agg = await db.stock_movement.aggregate({
      where: { ref_item_id: refItemId },
      _sum: { stock_delta: true },
    });
    const sum = agg._sum.stock_delta;
    return sum == null ? 0 : -(typeof sum === 'number' ? sum : sum.toNumber());
  }
```

- [ ] **Step 2: Compilar (sem teste isolado de repo — é I/O puro, coberto via e2e na Task 5)**

Run: `cd back && npx tsc --noEmit`
Expected: sem erros de tipo. (Se `stock_movementUncheckedCreateInput` não existir, rode `npx prisma generate` — depende da Task 2.)

- [ ] **Step 3: Commit**

```bash
git add back/src/modules/inventory/inventory.repository.ts
git commit -m "feat(inventory): repository de stock_movement (criar movimento + somar consumo por linha)"
```

---

### Task 4: Service — `reconcileConsumption` público (seam consumido pela OS)

Orquestra: deriva o consumo atual, calcula o delta (helper da Task 1), grava o movimento e ajusta o saldo na mesma tx, notifica estoque baixo na virada. Best-effort de saldo insuficiente é decidido aqui (lança erro controlado; quem chama na OS captura).

**Files:**
- Modify: `back/src/modules/inventory/inventory.service.ts`

**Interfaces:**
- Consumes: `InventoryRepository.createStockMovement`, `InventoryRepository.sumConsumedByRefItem`, `InventoryRepository.findItemById`, `InventoryRepository.adjustStock` (já existe); `computeReconcile` (Task 1); `maybeNotifyLowStock` (privado, já existe).
- Produces (método público em `InventoryService`):
  ```ts
  reconcileConsumption(tenantId: string, args: {
    inventoryItemId: string;
    refType: 'service_order';
    refId: string;
    refItemId: string;
    targetQty: number;          // 0 = liberar tudo
    createdBy?: string | null;
  }): Promise<void>;
  ```

- [ ] **Step 1: Importar o helper**

No topo de `back/src/modules/inventory/inventory.service.ts`, junto aos imports do módulo, adicione:

```ts
import { computeReconcile } from './stock-reconcile';
```

- [ ] **Step 2: Implementar `reconcileConsumption`**

Adicione na seção "Seam público (consumido pela OS)" da `InventoryService`, perto de `decrementStock`:

```ts
  /**
   * Reconcilia o consumo de UMA linha de origem (ex.: item de OS) para a
   * quantidade-alvo. Idempotente: se o consumo já registrado == alvo, não faz
   * nada. Grava o movimento e ajusta o saldo na MESMA tx; notifica estoque baixo
   * na virada (fora da tx). Abre a própria tx (runWithTenant) — NÃO chamar de
   * dentro de outra withTenantTx/runWithTenant.
   */
  async reconcileConsumption(
    tenantId: string,
    args: {
      inventoryItemId: string;
      refType: 'service_order';
      refId: string;
      refItemId: string;
      targetQty: number;
      createdBy?: string | null;
    },
  ): Promise<void> {
    const result = await this.tenant.runWithTenant(tenantId, async () => {
      const item = await this.repo.findItemById(args.inventoryItemId);
      // Item sumiu/deletado, ou é serviço → nada a reconciliar.
      if (!item || item.kind === 'service') return null;

      const prevConsumed = await this.repo.sumConsumedByRefItem(args.refItemId);
      const plan = computeReconcile(prevConsumed, args.targetQty);
      if (!plan) return null; // sem mudança

      const prev = toNum(item.current_stock);
      const next = prev + plan.stockDelta;
      if (next < 0) throw new BadRequestException('Estoque insuficiente.');

      await this.repo.createStockMovement(tenantId, {
        inventory_item_id: args.inventoryItemId,
        stock_delta: plan.stockDelta,
        reason: plan.reason,
        ref_type: args.refType,
        ref_id: args.refId,
        ref_item_id: args.refItemId,
        created_by: args.createdBy ?? null,
      });
      const updated = await this.repo.adjustStock(args.inventoryItemId, next);
      return { item: updated, prev, next, min: toNumOrNull(item.min_stock) };
    });

    // Notifica "estoque baixo" só na virada (consumo que cruza o mínimo).
    if (result) {
      await this.maybeNotifyLowStock(
        tenantId,
        result.item,
        result.prev,
        result.min,
        result.next,
        result.min,
      );
    }
  }
```

- [ ] **Step 3: Compilar**

Run: `cd back && npx tsc --noEmit`
Expected: sem erros de tipo.

- [ ] **Step 4: Commit**

```bash
git add back/src/modules/inventory/inventory.service.ts
git commit -m "feat(inventory): reconcileConsumption — seam de estoque por linha (idempotente)"
```

---

### Task 5: OS — reconciliar estoque na mudança de status (corrige o cancelamento)

Substitui `applyStock`/`stock_applied` por uma reconciliação de todas as linhas-produto conforme `consome(status)`. É aqui que o bug do cancelamento é corrigido.

**Files:**
- Modify: `back/src/modules/os/os.service.ts` (`changeStatus` ~L432; remover `applyStock` ~L494)
- Test: `back/test/os.e2e-spec.ts`

**Interfaces:**
- Consumes: `InventoryService.reconcileConsumption` (Task 4).
- Produces (privado em `OsService`):
  ```ts
  private reconcileOrderStock(user: AuthUser, order: { id: string; status: string; items: Array<{ id: string; kind: string; inventory_item_id: string | null; quantity: unknown }> }): Promise<void>;
  ```

- [ ] **Step 1: Escrever o teste e2e que falha (cancelar devolve estoque)**

Em `back/test/os.e2e-spec.ts`, adicione um teste no bloco de workflow (siga o setup/login/headers já usados no arquivo — reuse os helpers existentes de criação de OS e item):

```ts
it('cancelar uma OS em execução devolve as peças ao estoque', async () => {
  // 1. cria item de estoque com 10 unidades
  const inv = await createInventoryItem(app, headers, {
    name: 'Filtro de óleo',
    kind: 'product',
    currentStock: 10,
    salePrice: 50,
  });
  // 2. abre OS com 3 unidades do item
  const order = await createOrder(app, headers, { /* cliente novo mínimo */ });
  await addOrderItem(app, headers, order.id, {
    inventoryItemId: inv.id,
    quantity: 3,
    kind: 'product',
  });
  // 3. coloca em execução → baixa (10 - 3 = 7)
  await changeStatus(app, headers, order.id, 'em_execucao');
  let item = await getInventoryItem(app, headers, inv.id);
  expect(Number(item.current_stock)).toBe(7);

  // 4. cancela → estorna (7 + 3 = 10)
  await changeStatus(app, headers, order.id, 'cancelada');
  item = await getInventoryItem(app, headers, inv.id);
  expect(Number(item.current_stock)).toBe(10);
});
```

> Use os helpers/padrões já presentes em `os.e2e-spec.ts`. Se algum helper (`createInventoryItem`, `getInventoryItem`) não existir, crie-o como função local fina no topo do arquivo de teste chamando os endpoints `POST /api/inventory/items` e `GET /api/inventory/items/:id`.

- [ ] **Step 2: Rodar o teste e ver falhar**

Run: `cd back && redis-cli FLUSHALL && npx jest --config ./test/jest-e2e.json os.e2e-spec.ts -t "devolve as peças ao estoque"`
Expected: FAIL — após cancelar, `current_stock` ainda é 7 (estoque não voltou).

- [ ] **Step 3: Adicionar `consome()` e `reconcileOrderStock`; ligar no `changeStatus`**

No topo de `back/src/modules/os/os.service.ts`, perto de `TERMINAL_STATUSES`, adicione:

```ts
/** Status em que a OS consome estoque (peça está/foi usada). */
const CONSUMING_STATUSES = new Set<OsStatus>([
  'em_execucao',
  'concluida',
  'entregue',
]);
const consumes = (status: string): boolean =>
  CONSUMING_STATUSES.has(status as OsStatus);
```

Substitua o método `applyStock` (L494–L516) por `reconcileOrderStock`:

```ts
  /**
   * Reconcilia o estoque de TODAS as linhas-produto da OS para o alvo conforme o
   * status atual (consome → quantidade; senão → 0). Idempotente (delegado ao
   * inventory). Best-effort: erro num item (ex.: estoque insuficiente) NÃO
   * bloqueia a operação — apenas loga. Roda FORA de transação de banco
   * (reconcileConsumption abre a própria via runWithTenant).
   */
  private async reconcileOrderStock(
    user: AuthUser,
    order: {
      id: string;
      status: string;
      items: Array<{
        id: string;
        kind: string;
        inventory_item_id: string | null;
        quantity: Prisma.Decimal | number;
      }>;
    },
  ): Promise<void> {
    const target = consumes(order.status);
    for (const item of order.items) {
      if (item.kind !== 'product' || !item.inventory_item_id) continue;
      try {
        await this.inventory.reconcileConsumption(user.tenantId, {
          inventoryItemId: item.inventory_item_id,
          refType: 'service_order',
          refId: order.id,
          refItemId: item.id,
          targetQty: target ? toNum(item.quantity) : 0,
          createdBy: user.userId,
        });
      } catch (e) {
        this.logger.warn(
          `Reconciliação de estoque falhou (OS ${order.id}, item ${item.id}): ${
            (e as Error).message
          }`,
        );
      }
    }
  }
```

No `changeStatus`, substitua o bloco final de baixa (L479–L484):

```ts
    // Baixa/estorno de estoque conforme o novo status (idempotente). Substitui o
    // antigo applyStock/stock_applied. FORA de withTenantTx (reconcile abre a
    // própria tx). best-effort: erro de estoque não desfaz a transição.
    const after = await this.getOrderOrThrow(id);
    await this.reconcileOrderStock(user, after);

    return this.getOrderOrThrow(id);
```

(Remova a linha `return this.getOrderOrThrow(id);` duplicada anterior, se necessário, deixando apenas o retorno final acima.)

- [ ] **Step 4: Rodar o teste e ver passar**

Run: `cd back && redis-cli FLUSHALL && npx jest --config ./test/jest-e2e.json os.e2e-spec.ts -t "devolve as peças ao estoque"`
Expected: PASS — após cancelar, `current_stock` volta a 10.

- [ ] **Step 5: Rodar a suíte e2e de OS inteira + lint**

Run: `cd back && redis-cli FLUSHALL && npx jest --config ./test/jest-e2e.json os.e2e-spec.ts && npm run back:lint`
Expected: todos os testes de OS verdes (incl. os que antes dependiam de `applyStock`); lint 0 warnings.

- [ ] **Step 6: Commit**

```bash
git add back/src/modules/os/os.service.ts back/test/os.e2e-spec.ts
git commit -m "fix(os): estornar estoque ao cancelar via reconciliação por status (corrige bug)"
```

---

### Task 6: OS — reconciliar estoque ao editar item de OS em execução

Fecha o segundo furo: add/update/delete de item-produto enquanto a OS consome passa a ajustar o estoque. Cobre o caso "conclusão parcial via edição".

**Files:**
- Modify: `back/src/modules/os/os.service.ts` (`addItem` ~L519, `updateItem` ~L561, `deleteItem` ~L595)
- Test: `back/test/os.e2e-spec.ts`

**Interfaces:**
- Consumes: `InventoryService.reconcileConsumption` (Task 4); `consumes()` e `reconcileOrderStock` (Task 5).
- Produces: nada novo (reusa os pontos acima).

- [ ] **Step 1: Escrever o teste e2e que falha (reduzir qtd em execução estorna a diferença)**

Em `back/test/os.e2e-spec.ts`:

```ts
it('reduzir a quantidade de um item em execução estorna a diferença', async () => {
  const inv = await createInventoryItem(app, headers, {
    name: 'Pastilha de freio',
    kind: 'product',
    currentStock: 10,
    salePrice: 80,
  });
  const order = await createOrder(app, headers, { /* cliente novo mínimo */ });
  const item = await addOrderItem(app, headers, order.id, {
    inventoryItemId: inv.id,
    quantity: 4,
    kind: 'product',
  });
  await changeStatus(app, headers, order.id, 'em_execucao'); // 10 - 4 = 6
  let stock = await getInventoryItem(app, headers, inv.id);
  expect(Number(stock.current_stock)).toBe(6);

  // reduz de 4 para 1 → estorna 3 (6 + 3 = 9)
  await updateOrderItem(app, headers, order.id, item.id, { quantity: 1 });
  stock = await getInventoryItem(app, headers, inv.id);
  expect(Number(stock.current_stock)).toBe(9);

  // remove o item → estorna o 1 restante (9 + 1 = 10)
  await deleteOrderItem(app, headers, order.id, item.id);
  stock = await getInventoryItem(app, headers, inv.id);
  expect(Number(stock.current_stock)).toBe(10);
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd back && redis-cli FLUSHALL && npx jest --config ./test/jest-e2e.json os.e2e-spec.ts -t "estorna a diferença"`
Expected: FAIL — após reduzir/remover, o estoque não muda (continua 6).

- [ ] **Step 3: Reconciliar após cada mutação de item (quando a OS consome)**

Em `addItem` — após o `withTenantTx` que insere o item (logo antes de `return result;`, ~L558), adicione:

```ts
    // Se a OS já consome estoque, baixa a linha recém-criada (fora da tx).
    const orderAfterAdd = await this.getOrderOrThrow(orderId);
    if (consumes(orderAfterAdd.status)) {
      const created = orderAfterAdd.items.find((i) => i.id === result.id);
      if (created) await this.reconcileOrderStock(user, { ...orderAfterAdd, items: [created] });
    }
```

Em `updateItem` — o método hoje retorna direto o resultado do `withTenantTx`. Capture o retorno e reconcilie a linha alterada antes de retornar:

```ts
  async updateItem(
    user: AuthUser,
    orderId: string,
    itemId: string,
    dto: UpdateItemDto,
  ) {
    const item = await this.tenant.withTenantTx(async () => {
      // ... corpo atual idêntico, retornando o item ...
    });
    // Reconcilia o estoque da linha se a OS consome (fora da tx).
    const orderAfterUpd = await this.getOrderOrThrow(orderId);
    if (consumes(orderAfterUpd.status)) {
      const changed = orderAfterUpd.items.find((i) => i.id === itemId);
      if (changed) await this.reconcileOrderStock(user, { ...orderAfterUpd, items: [changed] });
    }
    return item;
  }
```

Em `deleteItem` — capture a linha ANTES de apagar (para ter `inventory_item_id`), apague, e reconcilie com alvo 0 (fora da tx). Reescreva o método:

```ts
  async deleteItem(user: AuthUser, orderId: string, itemId: string) {
    const { removed, order } = await this.tenant.withTenantTx(async () => {
      const order = await this.repo.findOrderById(orderId);
      if (!order || order.deleted_at)
        throw new NotFoundException('OS não encontrada.');
      this.assertEditable(order);
      const existing = await this.repo.findItemById(itemId);
      if (!existing || existing.order_id !== orderId)
        throw new NotFoundException('Item não encontrado.');
      await this.repo.deleteItem(itemId);
      await this.recomputeTotal(orderId);
      return { removed: existing, order };
    });
    // Estorna o consumo da linha removida (alvo 0) se a OS consome (fora da tx).
    if (
      consumes(order.status) &&
      removed.kind === 'product' &&
      removed.inventory_item_id
    ) {
      try {
        await this.inventory.reconcileConsumption(user.tenantId, {
          inventoryItemId: removed.inventory_item_id,
          refType: 'service_order',
          refId: orderId,
          refItemId: itemId,
          targetQty: 0,
          createdBy: user.userId,
        });
      } catch (e) {
        this.logger.warn(
          `Estorno de estoque falhou (OS ${orderId}, item ${itemId}): ${
            (e as Error).message
          }`,
        );
      }
    }
    return { id: itemId, deleted: true };
  }
```

> `assertEditable` bloqueia status terminais (`cancelada`/`entregue`), mas `em_execucao`/`concluida` permanecem editáveis — então a reconciliação acontece exatamente nos status que consomem e ainda aceitam edição.

- [ ] **Step 4: Rodar e ver passar**

Run: `cd back && redis-cli FLUSHALL && npx jest --config ./test/jest-e2e.json os.e2e-spec.ts -t "estorna a diferença"`
Expected: PASS — 9 após reduzir, 10 após remover.

- [ ] **Step 5: Suíte e2e completa + lint**

Run: `cd back && redis-cli FLUSHALL && npm run back:test:e2e && npm run back:lint`
Expected: tudo verde; lint 0 warnings.

- [ ] **Step 6: Commit**

```bash
git add back/src/modules/os/os.service.ts back/test/os.e2e-spec.ts
git commit -m "fix(os): reconciliar estoque ao editar item de OS em execução (conclusão parcial via edição)"
```

---

### Task 7: Auditoria do estorno + nota na timeline (best-effort)

Registra o estorno por ação para rastreabilidade (decisão §8.3: resumo por ação).

**Files:**
- Modify: `back/src/common/audit/audit.service.ts` (novo `AuditAction`)
- Modify: `back/src/modules/os/os.service.ts` (`changeStatus`: audit + nota ao cancelar)

**Interfaces:**
- Consumes: `AuditService.log`; `OsRepository.createEvent`.
- Produces: novo valor de `AuditAction`: `'os_stock_reconcile'`.

- [ ] **Step 1: Adicionar o AuditAction**

Em `back/src/common/audit/audit.service.ts`, no union `AuditAction`, adicione após `'os_template_apply'`:

```ts
  | 'os_stock_reconcile';
```

- [ ] **Step 2: Auditar + nota na timeline ao cancelar**

No `changeStatus`, logo após `await this.reconcileOrderStock(user, after);`, adicione:

```ts
    if (to === 'cancelada') {
      const devolvidos = after.items.filter(
        (i) => i.kind === 'product' && i.inventory_item_id,
      ).length;
      if (devolvidos > 0) {
        await this.audit.log(
          user.tenantId,
          user.userId,
          'os_stock_reconcile',
          id,
          { event: 'cancel_reversal', items: devolvidos },
        );
        // Nota interna na timeline (best-effort — não bloqueia).
        try {
          await this.tenant.withTenantTx(() =>
            this.repo.createEvent(user.tenantId, id, {
              kind: 'note',
              message: `Estoque estornado: ${devolvidos} item(ns) devolvido(s).`,
              visiblePublic: false,
              createdBy: user.userId,
            }),
          );
        } catch (e) {
          this.logger.warn(
            `Nota de estorno falhou (OS ${id}): ${(e as Error).message}`,
          );
        }
      }
    }
```

- [ ] **Step 3: Compilar + lint**

Run: `cd back && npx tsc --noEmit && npm run back:lint`
Expected: sem erros; 0 warnings.

- [ ] **Step 4: Rodar a suíte e2e de OS (garante que a nota/audit não quebrou nada)**

Run: `cd back && redis-cli FLUSHALL && npx jest --config ./test/jest-e2e.json os.e2e-spec.ts`
Expected: verde.

- [ ] **Step 5: Commit**

```bash
git add back/src/common/audit/audit.service.ts back/src/modules/os/os.service.ts
git commit -m "feat(os): auditar estorno de estoque + nota na timeline ao cancelar"
```

---

### Task 8: Limpeza — parar de usar `stock_applied` + atualizar docs

Remove o uso do booleano deprecado na lógica e atualiza a documentação de módulos.

**Files:**
- Modify: `back/src/modules/os/os.service.ts` (remover leituras/escritas de `stock_applied`)
- Modify: `back/src/modules/os/os.repository.ts` (`StatusFields.stock_applied` pode permanecer como campo opcional não usado, ou ser removido se não houver mais referências)
- Modify: `docs/modulos-v1.md` (documentar o diário de estoque)

**Interfaces:**
- Consumes: nada novo.
- Produces: nada novo.

- [ ] **Step 1: Remover referências a `stock_applied` na lógica**

Procure usos remanescentes:

Run: `cd back && grep -rn "stock_applied" src/`
Expected: listar as ocorrências. Remova as **leituras condicionais** (não há mais `if (!order.stock_applied)`) e a escrita `setStatusFields(orderId, { stock_applied: true })` (já substituída na Task 5). A coluna no banco e o campo opcional em `StatusFields` podem permanecer (migração aditiva; não quebrar baseline), apenas sem uso na lógica.

- [ ] **Step 2: Documentar em `docs/modulos-v1.md`**

Adicione, na seção do módulo `inventory`, um parágrafo:

```markdown
**Diário de estoque (`stock_movement`):** o `current_stock` é o saldo
materializado; cada baixa/estorno é um movimento em `stock_movement` (genérico
via `ref_type`/`ref_id`/`ref_item_id`). A OS reconcilia o consumo por linha via
`InventoryService.reconcileConsumption` quando o status muda ou um item é editado
(consome em `em_execucao`/`concluida`/`entregue`; estorna ao cancelar/reduzir/
remover). O booleano `service_order.stock_applied` está deprecado.
```

- [ ] **Step 3: Lint + compilar + suíte completa**

Run: `cd back && npx tsc --noEmit && npm run back:lint && redis-cli FLUSHALL && npm run back:test && npm run back:test:e2e`
Expected: tudo verde; 0 warnings.

- [ ] **Step 4: Commit**

```bash
git add back/src/modules/os/os.service.ts back/src/modules/os/os.repository.ts docs/modulos-v1.md
git commit -m "chore(os): deprecar stock_applied (sem uso na lógica) + doc do diário de estoque"
```

---

## Self-Review

**Spec coverage:**
- §3.1 tabela `stock_movement` → Task 2 ✅
- §3.2 cancelar estorna → Task 5 ✅
- §3.3 editar item em execução ajusta → Task 6 ✅
- §4.1 saldo materializado preservado (não reescreve métricas) → Task 2/3 (só adiciona tabela; `current_stock` intacto) ✅
- §4.2 regra `CONSUMINDO` + reconciliação → Task 5 (`consumes`/`reconcileOrderStock`) ✅
- §4.3 "aponta, não invade" + pool + best-effort → Task 4 (seam no inventory) + Task 5/6 (try/catch, fora de tx) ✅
- §4.5 timeline/auditoria → Task 7 ✅
- §5.2 backfill → Task 2 Step 1 ✅
- §5.3 `stock_applied` deprecado → Task 8 ✅
- §7 testes (idempotência, consumo, estorno total/parcial, remoção, serviço ignorado, isolamento) → Task 1 (unit) + Task 5/6 (e2e). **Nota:** o teste de isolamento de tenant para `stock_movement` está coberto implicitamente pela RLS+FORCE da tabela (mesmo padrão das demais); se quiser explícito, adicionar um caso no e2e de inventory replicando o padrão "A não vê B" existente.
- §8 decisões → resolvidas: best-effort (Global Constraints + Task 4/5/6), reabertura natural (coberta pela reconciliação na próxima transição — sem código extra), auditoria resumo por ação (Task 7) ✅

**Placeholder scan:** sem TBD/TODO; todo passo de código mostra o código. Os helpers de teste e2e (`createInventoryItem`, etc.) são referenciados com instrução explícita de reusar/criar conforme o padrão do arquivo — aceitável porque o arquivo `os.e2e-spec.ts` já existe com esses padrões (o implementador deve segui-los).

**Type consistency:** `computeReconcile(prevConsumed, targetConsumed) → {stockDelta, reason} | null` usado igual em Task 1 e Task 4. `reconcileConsumption` com a mesma assinatura em Task 4 (definição) e Task 5/6 (uso). `sumConsumedByRefItem`/`createStockMovement` idem entre Task 3 e Task 4. `consumes()`/`reconcileOrderStock` definidos na Task 5 e reusados na Task 6. ✅
