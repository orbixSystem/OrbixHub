# Notificação de estoque baixo — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Criar uma notificação tenant-wide quando um produto cruza para estoque baixo (`current_stock <= min_stock`).

**Architecture:** Uma função pura `crossedIntoLowStock` decide a "virada" (anti-spam). O `InventoryService` injeta o `NotificationsService` já existente (`@Global`) e, após persistir a baixa, chama `notify(...)` fora da transação quando há virada — nos dois caminhos que reduzem saldo (`decrementStock`, `updateItem`). Sem schema novo, sem endpoint novo. Front: ícone + navegação para a notificação.

**Tech Stack:** NestJS + Prisma (backend), Jest + supertest (testes), Flutter + Riverpod (front).

## Global Constraints

- **"Aponta, não invade":** o inventory NUNCA toca a tabela `notification` — só chama `NotificationsService.notify(...)`. (regra de ouro 1)
- **Notificar é best-effort:** falha ao notificar NUNCA quebra a baixa de estoque (try/catch + retorno normal).
- **Fora de transação:** `notify(...)` abre a própria tx via `runWithTenant`; chamá-lo dentro de `withTenantTx`/`runWithTenant` aninha transações e esgota o pool. Sempre depois da tx.
- **Opção A:** produto sem `min_stock` (null) NUNCA é "baixo". Só `kind === 'product'`.
- **Só na virada:** notifica apenas quando passa de NÃO-baixo para baixo. Sem flag persistida.
- **Strings de usuário em PT-BR.** Comentários técnicos podem ser em inglês (siga o vizinho).
- **Evidência antes de "pronto":** `npm run back:lint` (0 warnings) + `npm run back:test` + `npm run back:test:e2e`; `flutter analyze` (0 issues) + `flutter test`. Citar o output real.

---

### Task 1: Função pura `crossedIntoLowStock`

**Files:**
- Create: `back/src/modules/inventory/low-stock.ts`
- Test: `back/src/modules/inventory/low-stock.spec.ts`

**Interfaces:**
- Consumes: nada.
- Produces: `crossedIntoLowStock(prevStock: number, prevMin: number | null, nextStock: number, nextMin: number | null): boolean` — `true` quando a operação leva o item de NÃO-baixo para baixo. `prevMin`/`nextMin` separados para cobrir mudança do próprio mínimo no `updateItem`.

- [ ] **Step 1: Write the failing test**

`back/src/modules/inventory/low-stock.spec.ts`:
```ts
import { crossedIntoLowStock } from './low-stock';

describe('crossedIntoLowStock', () => {
  it('dispara quando o saldo cai de acima do mínimo para <= mínimo', () => {
    expect(crossedIntoLowStock(5, 3, 2, 3)).toBe(true);
  });

  it('conta o saldo exatamente no mínimo como baixo', () => {
    expect(crossedIntoLowStock(5, 3, 3, 3)).toBe(true);
  });

  it('NÃO dispara quando já estava baixo e continua baixando', () => {
    expect(crossedIntoLowStock(2, 3, 1, 3)).toBe(false);
  });

  it('NÃO dispara sem mínimo definido (Opção A)', () => {
    expect(crossedIntoLowStock(5, null, 0, null)).toBe(false);
  });

  it('NÃO dispara quando o saldo segue acima do mínimo', () => {
    expect(crossedIntoLowStock(10, 3, 8, 3)).toBe(false);
  });

  it('dispara quando o mínimo sobe acima do saldo atual (virada pelo mínimo)', () => {
    expect(crossedIntoLowStock(5, null, 5, 10)).toBe(true);
    expect(crossedIntoLowStock(5, 3, 5, 10)).toBe(true);
  });

  it('NÃO dispara em reabastecimento (sobe acima do mínimo)', () => {
    expect(crossedIntoLowStock(2, 3, 5, 3)).toBe(false);
  });

  it('rearma: após reabastecer, baixar de novo dispara', () => {
    expect(crossedIntoLowStock(5, 3, 2, 3)).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run back:test -- low-stock`
Expected: FAIL — "Cannot find module './low-stock'".

- [ ] **Step 3: Write minimal implementation**

`back/src/modules/inventory/low-stock.ts`:
```ts
/**
 * "Só na virada": true quando a operação leva o item de NÃO-baixo para baixo.
 * Mínimo nulo = nunca baixo (Opção A). prevMin/nextMin separados para cobrir o
 * caso de o próprio mínimo mudar (ex.: subir o mínimo acima do saldo atual).
 */
export function crossedIntoLowStock(
  prevStock: number,
  prevMin: number | null,
  nextStock: number,
  nextMin: number | null,
): boolean {
  const wasLow = prevMin != null && prevStock <= prevMin;
  const isLow = nextMin != null && nextStock <= nextMin;
  return !wasLow && isLow;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run back:test -- low-stock`
Expected: PASS (8 passed).

- [ ] **Step 5: Commit**

```bash
git add back/src/modules/inventory/low-stock.ts back/src/modules/inventory/low-stock.spec.ts
git commit -m "feat(inventory): função pura crossedIntoLowStock (só na virada)"
```

---

### Task 2: Engatar a notificação no `InventoryService`

**Files:**
- Modify: `back/src/modules/inventory/inventory.service.ts`
- Test: `back/src/modules/inventory/inventory.low-stock-notify.spec.ts` (create)

**Interfaces:**
- Consumes: `crossedIntoLowStock(...)` (Task 1); `NotificationsService.notify(tenantId, { type, title, body?, refType?, refId? })` (já existe em `../notifications/notifications.service`).
- Produces: comportamento — `decrementStock`/`updateItem` chamam `notify` com `type: 'inventory_low_stock'`, `refType: 'inventory_item'`, `refId: <id>` quando há virada.

- [ ] **Step 1: Write the failing test**

`back/src/modules/inventory/inventory.low-stock-notify.spec.ts`:
```ts
import { InventoryService } from './inventory.service';
import type { NotificationsService } from '../notifications/notifications.service';
import type { TenantContext } from '../../common/database/tenant-context';
import type { InventoryRepository } from './inventory.repository';

type Item = {
  id: string;
  name: string;
  kind: 'product' | 'service';
  unit: string | null;
  current_stock: number;
  min_stock: number | null;
  deleted_at: Date | null;
};

function makeService(item: Item) {
  const stored: Item = { ...item };
  const notify = jest.fn().mockResolvedValue(undefined);

  // tenant: executa o callback direto (sem banco real).
  const tenant = {
    runWithTenant: (_tid: string, fn: () => unknown) => fn(),
    withTenantTx: (fn: () => unknown) => fn(),
  } as unknown as TenantContext;

  const repo = {
    findItemById: async () => ({ ...stored }),
    adjustStock: async (_id: string, next: number) => {
      stored.current_stock = next;
      return { ...stored };
    },
    updateItem: async (_id: string, data: Record<string, unknown>) => {
      Object.assign(stored, data);
      return { ...stored };
    },
  } as unknown as InventoryRepository;

  const notifications = { notify } as unknown as NotificationsService;
  const audit = { log: jest.fn().mockResolvedValue(undefined) } as never;
  const noop = {} as never;

  // Ordem do construtor: tenant, repo, billing, audit, notifications,
  // catalogStore, catalog, env (ver inventory.service.ts).
  const svc = new InventoryService(
    tenant, repo, noop, audit, notifications, noop, noop, noop,
  );
  return { svc, notify };
}

const baseItem: Item = {
  id: 'item-1', name: 'Produto 0001', kind: 'product', unit: 'un',
  current_stock: 5, min_stock: 3, deleted_at: null,
};

describe('InventoryService — notificação de estoque baixo', () => {
  it('decrementStock cruzando o mínimo notifica 1x', async () => {
    const { svc, notify } = makeService(baseItem);
    await svc.decrementStock('t1', 'item-1', 3); // 5 -> 2 (<= 3)
    expect(notify).toHaveBeenCalledTimes(1);
    expect(notify).toHaveBeenCalledWith('t1', expect.objectContaining({
      type: 'inventory_low_stock',
      refType: 'inventory_item',
      refId: 'item-1',
    }));
  });

  it('decrementStock de item já baixo NÃO notifica', async () => {
    const { svc, notify } = makeService({ ...baseItem, current_stock: 2 });
    await svc.decrementStock('t1', 'item-1', 1); // 2 -> 1 (já baixo)
    expect(notify).not.toHaveBeenCalled();
  });

  it('decrementStock sem mínimo (Opção A) NÃO notifica', async () => {
    const { svc, notify } = makeService({ ...baseItem, min_stock: null });
    await svc.decrementStock('t1', 'item-1', 5); // 5 -> 0, sem mínimo
    expect(notify).not.toHaveBeenCalled();
  });

  it('updateItem reduzindo o saldo abaixo do mínimo notifica 1x', async () => {
    const { svc, notify } = makeService(baseItem);
    await svc.updateItem({ tenantId: 't1', userId: 'u1' } as never, 'item-1', {
      currentStock: 1,
    });
    expect(notify).toHaveBeenCalledTimes(1);
  });

  it('updateItem subindo o mínimo acima do saldo notifica 1x', async () => {
    const { svc, notify } = makeService(baseItem);
    await svc.updateItem({ tenantId: 't1', userId: 'u1' } as never, 'item-1', {
      minStock: 10,
    });
    expect(notify).toHaveBeenCalledTimes(1);
  });

  it('notify que falha não propaga (decrement conclui)', async () => {
    const { svc, notify } = makeService(baseItem);
    notify.mockRejectedValueOnce(new Error('down'));
    const res = await svc.decrementStock('t1', 'item-1', 3);
    expect((res as { current_stock: number }).current_stock).toBe(2);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run back:test -- inventory.low-stock-notify`
Expected: FAIL — construtor com aridade diferente / `notify` não chamado (a injeção e a lógica ainda não existem).

- [ ] **Step 3: Write minimal implementation**

Em `back/src/modules/inventory/inventory.service.ts`:

3a. Importar a função pura e o service (topo do arquivo, junto aos outros imports):
```ts
import { NotificationsService } from '../notifications/notifications.service';
import { crossedIntoLowStock } from './low-stock';
```

3b. Adicionar `toNumOrNull` ao lado do `toNum` existente (o `toNum` transforma null→0, o que apagaria a Opção A para o mínimo):
```ts
const toNumOrNull = (d: Prisma.Decimal | number | null | undefined): number | null =>
  d == null ? null : typeof d === 'number' ? d : d.toNumber();
```

3c. Injetar `NotificationsService` no construtor — **entre `audit` e `catalogStore`** (mantém o agrupamento dos services de domínio; a ordem deve casar com o teste da Task 2):
```ts
  constructor(
    private readonly tenant: TenantContext,
    private readonly repo: InventoryRepository,
    private readonly billing: BillingService,
    private readonly audit: AuditService,
    private readonly notifications: NotificationsService,
    private readonly catalogStore: CatalogProductStore,
    @Inject(CATALOG_PROVIDER) private readonly catalog: CatalogProvider,
    @Inject(ENV) private readonly env: Env,
  ) {}
```

3d. Adicionar o helper privado (perto do fim da classe, junto dos seams):
```ts
  /**
   * Best-effort: notifica "estoque baixo" só na virada (NÃO-baixo → baixo). Chamar
   * SEMPRE fora de withTenantTx/runWithTenant (notify abre a própria tx). Falha de
   * notificação nunca quebra a baixa de estoque.
   */
  private async maybeNotifyLowStock(
    tenantId: string,
    item: { id: string; name: string; unit: string | null },
    prevStock: number,
    prevMin: number | null,
    nextStock: number,
    nextMin: number | null,
  ): Promise<void> {
    if (!crossedIntoLowStock(prevStock, prevMin, nextStock, nextMin)) return;
    try {
      const unidade = item.unit?.trim() ? ` ${item.unit.trim()}` : '';
      await this.notifications.notify(tenantId, {
        type: 'inventory_low_stock',
        title: `Estoque baixo: ${item.name}`,
        body: `Restam ${nextStock}${unidade} (mínimo ${nextMin})`,
        refType: 'inventory_item',
        refId: item.id,
      });
    } catch {
      // best-effort — não quebra o fluxo de estoque
    }
  }
```

3e. Reescrever `decrementStock` para persistir na tx e notificar fora dela:
```ts
  /** Baixa de estoque programática; valida saldo ≥ 0. Notifica na virada (fora da tx). */
  async decrementStock(tenantId: string, id: string, qty: number) {
    const { item, prev, next, min } = await this.tenant.runWithTenant(
      tenantId,
      async () => {
        const item = await this.repo.findItemById(id);
        if (!item) throw new NotFoundException('Item não encontrado.');
        if (item.kind === 'service')
          throw new BadRequestException('Serviço não controla estoque.');
        const prev = toNum(item.current_stock);
        const next = prev - qty;
        if (next < 0) throw new BadRequestException('Estoque insuficiente.');
        const updated = await this.repo.adjustStock(id, next);
        return { item: updated, prev, next, min: toNumOrNull(item.min_stock) };
      },
    );
    // min não muda nesta operação → prevMin === nextMin === min.
    await this.maybeNotifyLowStock(tenantId, item, prev, min, next, min);
    return item;
  }
```

3f. No `updateItem`, capturar prev/next/min e notificar após o `audit.log`. Substituir o corpo a partir do `const item = await this.tenant.withTenantTx(...)` até o `return item;` por:
```ts
    const { item, prev, prevMin, next, nextMin, isService } =
      await this.tenant.withTenantTx(async () => {
        const existing = await this.repo.findItemById(id);
        if (!existing || existing.deleted_at)
          throw new NotFoundException('Item não encontrado.');
        // kind nunca muda; serviço não controla estoque (ignora campos de estoque).
        const isService = existing.kind === 'service';
        const data: Record<string, unknown> = {};
        if (dto.name !== undefined) data.name = dto.name.trim();
        if (dto.sku !== undefined) data.sku = trimOrNull(dto.sku);
        if (!isService && dto.manufacturerCode !== undefined)
          data.manufacturer_code = trimOrNull(dto.manufacturerCode);
        if (!isService && dto.barcode !== undefined)
          data.barcode = trimOrNull(dto.barcode);
        if (dto.category !== undefined) data.category = trimOrNull(dto.category);
        if (dto.brand !== undefined) data.brand = trimOrNull(dto.brand);
        if (dto.unit !== undefined) data.unit = trimOrNull(dto.unit);
        if (dto.salePrice !== undefined) data.sale_price = dto.salePrice;
        if (dto.costPrice !== undefined) data.cost_price = dto.costPrice;
        if (dto.marginPct !== undefined) data.margin_pct = dto.marginPct;
        if (!isService && dto.currentStock !== undefined)
          data.current_stock = dto.currentStock;
        if (!isService && dto.minStock !== undefined) data.min_stock = dto.minStock;
        if (dto.durationMinutes !== undefined)
          data.duration_minutes = dto.durationMinutes;
        if (dto.attributes !== undefined)
          data.attributes = dto.attributes as Prisma.InputJsonValue;
        try {
          const updated = await this.repo.updateItem(id, data);
          return {
            item: updated,
            prev: toNum(existing.current_stock),
            prevMin: toNumOrNull(existing.min_stock),
            next: toNum(updated.current_stock),
            nextMin: toNumOrNull(updated.min_stock),
            isService,
          };
        } catch (e) {
          if (isUniqueViolation(e))
            throw new ConflictException('Já existe um item com este código.');
          throw e;
        }
      });
    // audit FORA do tx (evita transação aninhada — ver deleteItem).
    await this.audit.log(user.tenantId, user.userId, 'inventory_item_update', id);
    if (!isService)
      await this.maybeNotifyLowStock(
        user.tenantId, item, prev, prevMin, next, nextMin,
      );
    return item;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run back:test -- inventory.low-stock-notify`
Expected: PASS (6 passed). Também rode `npm run back:test -- inventory` para garantir que nada quebrou e `npm run back:lint` (0 warnings).

- [ ] **Step 5: Commit**

```bash
git add back/src/modules/inventory/inventory.service.ts back/src/modules/inventory/inventory.low-stock-notify.spec.ts
git commit -m "feat(inventory): notifica estoque baixo na virada (decrement + update)"
```

---

### Task 3: e2e — caminho do ajuste manual (PATCH)

**Files:**
- Modify: `back/test/inventory.e2e-spec.ts`

**Interfaces:**
- Consumes: helpers já existentes no arquivo — `registerOwner()`, `createItem(access, body)`, `patchItem(access, id, body)`, `auth(access)`.
- Produces: nada (teste).

- [ ] **Step 1: Write the failing test**

Adicionar, antes do `});` final do `describe('Inventory — Produtos (e2e)', ...)`, um helper de notificações e um bloco de testes:
```ts
  function notifications(access: string) {
    return request(app.getHttpServer())
      .get('/api/notifications')
      .set(auth(access));
  }

  // ---- estoque baixo: notificação ----------------------------------------
  describe('estoque baixo (notificação)', () => {
    it('PATCH cruzando o mínimo gera notificação inventory_low_stock', async () => {
      const o = await registerOwner();
      const created = await createItem(o.access, {
        name: 'Filtro de óleo',
        currentStock: 5,
        minStock: 3,
      });
      expect(created.status).toBe(201);
      const id = created.body.id as string;

      const patched = await patchItem(o.access, id, { currentStock: 2 });
      expect(patched.status).toBe(200);

      const notif = await notifications(o.access);
      expect(notif.status).toBe(200);
      const low = (notif.body.items as Array<Record<string, unknown>>).find(
        (n) => n.type === 'inventory_low_stock' && n.ref_id === id,
      );
      expect(low).toBeTruthy();
    });

    it('produto sem mínimo NÃO gera notificação ao zerar (Opção A)', async () => {
      const o = await registerOwner();
      const created = await createItem(o.access, {
        name: 'Parafuso avulso',
        currentStock: 4,
      });
      const id = created.body.id as string;

      const patched = await patchItem(o.access, id, { currentStock: 0 });
      expect(patched.status).toBe(200);

      const notif = await notifications(o.access);
      const low = (notif.body.items as Array<Record<string, unknown>>).filter(
        (n) => n.type === 'inventory_low_stock',
      );
      expect(low).toHaveLength(0);
    });

    it('isolamento: B não vê a notificação de estoque baixo de A', async () => {
      const a = await registerOwner();
      const b = await registerOwner();
      const created = await createItem(a.access, {
        name: 'Correia',
        currentStock: 5,
        minStock: 3,
      });
      const id = created.body.id as string;
      await patchItem(a.access, id, { currentStock: 1 });

      const notifB = await notifications(b.access);
      const low = (notifB.body.items as Array<Record<string, unknown>>).filter(
        (n) => n.type === 'inventory_low_stock',
      );
      expect(low).toHaveLength(0);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run back:test:e2e -- inventory`
Expected: as duas primeiras já podem passar se a Task 2 estiver feita; este passo confirma que o e2e roda. Se a Task 2 NÃO estiver feita, o 1º caso FALHA (nenhuma notificação criada). (Redis é limpo no `beforeEach` com `flushall`.)

- [ ] **Step 3: Implementação**

Nenhuma — o comportamento já foi implementado na Task 2. Este é teste de aceitação do caminho HTTP real (RLS + isolamento).

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run back:test:e2e -- inventory`
Expected: PASS (todos os blocos, incluindo o novo `estoque baixo (notificação)`).

- [ ] **Step 5: Commit**

```bash
git add back/test/inventory.e2e-spec.ts
git commit -m "test(inventory): e2e estoque baixo via PATCH (+isolamento de tenant)"
```

---

### Task 4: e2e — caminho da OS (baixa ao entrar em execução)

**Files:**
- Modify: `back/test/os.e2e-spec.ts`

**Interfaces:**
- Consumes: helpers já existentes no arquivo — owner/registro, `createItem` (inventory), `createOrder`, `addItem(access, orderId, body)`, `changeStatus(access, orderId, status)`, `auth(access)`. (Confirmar os nomes exatos no topo do arquivo antes de escrever; reusar, não recriar.)
- Produces: nada (teste).

- [ ] **Step 1: Write the failing test**

Adicionar um helper de notificações (se ainda não houver no arquivo) e um teste dentro do `describe` principal da OS:
```ts
  function notifications(access: string) {
    return request(app.getHttpServer())
      .get('/api/notifications')
      .set(auth(access));
  }

  describe('estoque baixo ao executar a OS', () => {
    it('baixa que cruza o mínimo ao entrar em execução gera notificação', async () => {
      const o = await registerOwner();
      // produto perto do mínimo: saldo 5, mínimo 3
      const prod = await createItem(o.access, {
        name: 'Vela de ignição',
        currentStock: 5,
        minStock: 3,
      });
      expect(prod.status).toBe(201);
      const prodId = prod.body.id as string;

      const order = await createOrder(o.access);
      const orderId = order.body.id as string;

      // consome 3 → saldo 2 (<= 3): cruza o mínimo
      const added = await addItem(o.access, orderId, {
        kind: 'product',
        name: 'Vela de ignição',
        inventoryItemId: prodId,
        quantity: 3,
        unitPrice: 20,
      });
      expect(added.status).toBe(201);

      const exec = await changeStatus(o.access, orderId, 'em_execucao');
      expect(exec.status).toBe(200);

      const notif = await notifications(o.access);
      const low = (notif.body.items as Array<Record<string, unknown>>).find(
        (n) => n.type === 'inventory_low_stock' && n.ref_id === prodId,
      );
      expect(low).toBeTruthy();
    });
  });
```
Nota de implementação: confirmar os nomes/assinaturas reais de `registerOwner`, `createOrder`, `addItem`, `changeStatus` no topo de `os.e2e-spec.ts` (linhas ~77-184) e ajustar o corpo do `addItem`/`createOrder` ao formato já usado pelos testes vizinhos (ex.: o teste de transição na linha ~391 e o `addItem` com `inventoryItemId` na linha ~351). Não inventar campos.

- [ ] **Step 2: Run test to verify it fails (ou passa, se Task 2 pronta)**

Run: `npm run back:test:e2e -- os`
Expected: com a Task 2 feita, PASS. Sem ela, FALHA (sem notificação). Confirma a fiação do caminho `decrementStock` ponta a ponta — o cenário real do usuário (estoque baixa ao iniciar o serviço).

- [ ] **Step 3: Implementação**

Nenhuma — comportamento já implementado na Task 2.

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run back:test:e2e -- os`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add back/test/os.e2e-spec.ts
git commit -m "test(os): e2e notificação de estoque baixo ao entrar em execução"
```

---

### Task 5: Front — ícone e navegação da notificação

**Files:**
- Modify: `front/lib/features/notifications/presentation/notifications_bell.dart`

**Interfaces:**
- Consumes: `AppNotification.type` (`'inventory_low_stock'`), rota `/m/inventory` (ver `core/router/app_router.dart:145`).
- Produces: nada (UI).

- [ ] **Step 1: Ícone próprio no `_NotificationRow`**

Em `_NotificationRow.build`, logo após `final isMessage = n.type == 'message' || n.refType == 'message';`, derivar o ícone:
```dart
    final isLowStock = n.type == 'inventory_low_stock';
    final iconData = isMessage
        ? Icons.chat_bubble_outline_rounded
        : isLowStock
            ? Icons.inventory_2_outlined
            : Icons.notifications_none_rounded;
```
E trocar o `Icon(...)` do avatar (hoje `isMessage ? Icons.chat_bubble_outline_rounded : Icons.notifications_none_rounded`) por `Icon(iconData, ...)`, mantendo `size` e `color` atuais.

- [ ] **Step 2: Navegação no tap (`_onTapItem`)**

Em `_onTapItem`, após o bloco `if (n.refType == 'message' ...) { context.go('/mensagens/${n.refId}'); }`, adicionar:
```dart
    else if (n.type == 'inventory_low_stock') {
      context.go('/m/inventory');
    }
```

- [ ] **Step 3: Verificar**

Run (a partir de `front/`): `C:\Users\KaueSobral\develop\flutter\bin\flutter.bat analyze`
Expected: "No issues found!".
Run: `C:\Users\KaueSobral\develop\flutter\bin\flutter.bat test`
Expected: todos os testes verdes (sem regressão — não há teste novo de widget para o sino; o gate é o analyze + suíte existente).

- [ ] **Step 4: Commit**

```bash
git add front/lib/features/notifications/presentation/notifications_bell.dart
git commit -m "feat(front): ícone e navegação da notificação de estoque baixo"
```

---

## Self-Review

- **Cobertura do spec:** §3 decisões → Task 1 (virada/Opção A) + Task 2 (origem consumo+manual, só produto). §4 lógica → Task 1 (com refino prevMin/nextMin para o caso "subir o mínimo", citado nos testes do spec). §5 backend → Task 2. §6 front → Task 5. §8 testes → Task 1 (unit pura), Task 2 (unit service), Tasks 3-4 (e2e PATCH + OS), Task 5 (analyze). §7 sem schema → confirmado (nenhuma migration). §9 evidência → Global Constraints + steps de verificação.
- **Refino vs spec:** a função pura usa `prevMin`/`nextMin` (não um único `min`) para cobrir fielmente o teste "updateItem subindo o mínimo acima do saldo → notifica" listado no §8 do spec. Para `decrementStock`, `prevMin === nextMin`.
- **Consistência de tipos:** `crossedIntoLowStock(prevStock, prevMin, nextStock, nextMin)` usado com a mesma assinatura em Task 1 (def), Task 2 (chamada via `maybeNotifyLowStock`). `notify(tenantId, {type,title,body,refType,refId})` casa com `NotifyInput`. Ordem do construtor (`tenant, repo, billing, audit, notifications, catalogStore, catalog, env`) idêntica em 3c e no `makeService` do teste.
- **Placeholders:** nenhum — todos os steps de código trazem o código real.
```
