# Estoque & Serviços (`inventory`) — Design v1

> Spec de design aprovado para o módulo **Estoque & Serviços** do OrbixHub.
> Data: 2026-06-15 · Branch alvo sugerida: `feat/inventory`.
> Fonte de verdade de arquitetura: skill `orbixhub-arquitetura` + `CLAUDE.md`.
> Itens adiados conscientemente vivem em [`docs/pendencias.md`](../../pendencias.md).

## 1. Objetivo e contexto

`inventory` é um módulo **contratável** (gated por `tenant_module` + plano) que entrega um
**catálogo de itens** — cada item é um **Produto** (tem estoque) ou um **Serviço** (não tem) —
com **controle de estoque por movimentações** e **precificação** (custo + margem → preço sugerido).

É a **fundação** sobre a qual o módulo `os` (Ordens de Serviço) será construído depois: a OS
consome itens do catálogo **por id, via o service público** do inventory ("aponta, não invade"),
e no futuro dá baixa de estoque chamando `InventoryService.applyMovement(...)`. A OS **não** está
neste spec.

**Genérico por design:** "item" (produto/serviço) serve qualquer vertical — peça/troca-de-óleo na
oficina, ração/banho no petshop, pomada/corte na barbearia. Nenhum termo de vertical no schema.

### Metas (v1)
- Cadastrar/editar/arquivar itens Produto e Serviço (form adapta campos por tipo).
- Controle de estoque de produtos via **movimentações** (entrada/saída/ajuste) com **histórico** e
  saldo cacheado no item.
- Precificação: custo + margem% → **preço de venda sugerido** (cálculo manual, sobrescrevível).
- `min_qty` + **filtro simples** "abaixo do mínimo".
- Config do módulo (unidade padrão, sugestões de categoria, margem padrão, default de rastrear estoque).
- Service público (`getItem`, `applyMovement`, busca p/ picker) para a OS consumir.

### Não-metas (v1) — ver `docs/pendencias.md`
Camada de feature-gating por plano; alerta/dashboard proativo de mínimo; precificação por IA;
valorização (custo médio/valor total do estoque); relatórios; fornecedores; importação CSV;
kits/combos; leitor de código de barras; unidades com conversão; múltiplos depósitos.

## 2. Regras de arquitetura aplicadas (não-negociáveis)

1. **Multi-tenant via RLS.** As 2 tabelas novas são tenant-scoped: `RLS + FORCE` com policy
   `tenant_id = current_tenant_id()`. `tenant_id` **sempre** do JWT (CLS); toda operação roda sob
   `withTenantTx`. No repository, **sempre** `getClient()` — nunca injetar `PrismaService` direto.
2. **Aponta, não invade.** O inventory é dono das suas tabelas; a OS (futuro) guarda só
   `inventory_item_id` e busca via `InventoryService`. O inventory **não** lê/escreve tabelas de
   outros módulos. Movimentos de origem externa carregam `ref_type`/`ref_id` (ponteiro, não FK rígida).
3. **Migration ADITIVA** nos 3 lugares: `sql/auth-multitenant-schema.sql` (canônico/idempotente),
   `prisma/migrations/0010_inventory/migration.sql`, `prisma/schema.prisma` (à mão). Não quebrar baseline.
4. **Sem hard delete.** `status='archived'` (arquivar/desarquivar). Itens arquivados somem das buscas
   padrão mas preservam histórico de movimentos.
5. **Mutações auditadas.** Criar/editar/arquivar item e registrar movimento → `AuditService.log`.
   Escrita exige `inventory.write`; config exige `settings.manage`.
6. **Genérico.** Sem "placa"/"peça de carro" hardcoded. Rótulos vêm da config/UI.
7. **Front fala só com repository** (interface no domain; impl dio + fake). Models freezed; estado selado.
   Strings de usuário em PT-BR. Módulo aparece sozinho no menu via `me.modules`.

## 3. Modelo de dados

Duas tabelas novas, tenant-scoped. Preços em **centavos** (`int`), seguindo a convenção de `plan.price_cents`.
Quantidades em `numeric(14,3)` (suporta fracionário: litros, kg).

### `inventory_item`
```sql
CREATE TABLE IF NOT EXISTS inventory_item (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  kind             text NOT NULL,                       -- 'product' | 'service'
  name             text NOT NULL,
  code             text,                                -- SKU/código interno
  barcode          text,                                -- só produto (opcional)
  category         text,                                -- texto livre; config sugere lista
  unit             text NOT NULL DEFAULT 'un',          -- un | L | kg | h ...
  sale_price_cents integer NOT NULL DEFAULT 0,          -- preço de venda
  cost_price_cents integer,                             -- custo (opcional; base do markup)
  margin_percent   numeric(7,2),                        -- margem usada p/ sugerir preço (opcional)
  sellable         boolean NOT NULL DEFAULT true,       -- futuro "vende / só estoque"
  track_stock      boolean NOT NULL DEFAULT true,       -- produto true; serviço sempre false
  stock_qty        numeric(14,3) NOT NULL DEFAULT 0,    -- saldo cacheado (∑ movimentos)
  min_qty          numeric(14,3),                       -- mínimo p/ alerta (opcional)
  duration_minutes integer,                             -- só serviço (estimativa)
  brand            text,
  status           text NOT NULL DEFAULT 'active',      -- 'active' | 'archived'
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE inventory_item ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_item FORCE ROW LEVEL SECURITY;
CREATE POLICY inventory_item_tenant_isolation ON inventory_item
  USING (tenant_id = current_tenant_id()) WITH CHECK (tenant_id = current_tenant_id());
CREATE INDEX IF NOT EXISTS idx_inventory_item_tenant_kind ON inventory_item (tenant_id, kind);
CREATE INDEX IF NOT EXISTS idx_inventory_item_tenant_status ON inventory_item (tenant_id, status);
CREATE UNIQUE INDEX IF NOT EXISTS uq_inventory_item_tenant_code
  ON inventory_item (tenant_id, code) WHERE code IS NOT NULL;
```
**Invariantes (no service):** `kind='service'` ⇒ `track_stock=false`, `stock_qty` ignorado,
`barcode/min_qty` irrelevantes. `kind='product'` ⇒ `track_stock` default true. `stock_qty` **nunca**
é editado direto pela API de item — só muda via movimento (ou ajuste).

### `inventory_movement`
```sql
CREATE TABLE IF NOT EXISTS inventory_movement (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  item_id       uuid NOT NULL REFERENCES inventory_item(id) ON DELETE CASCADE,
  type          text NOT NULL,                          -- 'in' | 'out' | 'adjust'
  quantity      numeric(14,3) NOT NULL,                 -- magnitude positiva
  balance_after numeric(14,3) NOT NULL,                 -- saldo resultante (auditoria)
  reason        text,                                   -- 'purchase'|'os_consumption'|'manual'|'correction'
  ref_type      text,                                   -- ponteiro externo: ex. 'os'
  ref_id        uuid,                                   -- id no módulo de origem
  note          text,
  created_by    uuid,                                   -- users.id (ator)
  created_at    timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE inventory_movement ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_movement FORCE ROW LEVEL SECURITY;
CREATE POLICY inventory_movement_tenant_isolation ON inventory_movement
  USING (tenant_id = current_tenant_id()) WITH CHECK (tenant_id = current_tenant_id());
CREATE INDEX IF NOT EXISTS idx_inventory_movement_tenant_item
  ON inventory_movement (tenant_id, item_id, created_at DESC);
```
**Semântica de saldo:** `in` soma, `out` subtrai, `adjust` define o saldo para um valor alvo
(grava o delta em `quantity` e o alvo em `balance_after`). Item + movimento gravados na **mesma
transação** (`withTenantTx`): cria o movimento, recalcula e persiste `inventory_item.stock_qty`.
Saída que deixaria saldo negativo: **bloqueia por padrão** (config futura pode permitir negativo).

## 4. Backend — estrutura e API

Pasta `back/src/modules/inventory/` espelhando o módulo `customers`:
```
inventory/
├── inventory.module.ts        # imports BillingModule, SettingsModule; exports InventoryService
├── inventory.controller.ts    # rotas de itens + movimentos + low-stock
├── inventory.config.controller.ts  # GET/PATCH /inventory/config (ou dentro do controller principal)
├── inventory.service.ts       # lógica + PÚBLICO (getItem, applyMovement, searchForPicker)
├── inventory.repository.ts    # único que toca o banco (getClient())
├── inventory.config.ts        # model + merge de defaults da config (espelha customers.config.ts)
└── dto/
    ├── item.dto.ts            # CreateItemDto, UpdateItemDto, ListItemsQueryDto
    ├── movement.dto.ts        # CreateMovementDto
    └── config.dto.ts          # UpdateInventoryConfigDto
```

### Endpoints (todos sob `@RequiresModule('inventory')` + `ModuleAccessGuard`)
| Método | Rota | Permissão | Descrição |
|---|---|---|---|
| GET | `/inventory/items?q=&kind=&category=&status=&lowStock=&page=` | `inventory.read` | Lista paginada + filtros |
| GET | `/inventory/items/:id` | `inventory.read` | Detalhe do item |
| POST | `/inventory/items` | `inventory.write` | Cria item (valida invariantes por `kind`) |
| PATCH | `/inventory/items/:id` | `inventory.write` | Edita campos (não `stock_qty`) |
| POST | `/inventory/items/:id/archive` | `inventory.write` | Soft delete |
| POST | `/inventory/items/:id/unarchive` | `inventory.write` | Reativa |
| GET | `/inventory/items/:id/movements` | `inventory.read` | Histórico de movimentos do item |
| POST | `/inventory/items/:id/movements` | `inventory.write` | Registra entrada/saída/ajuste |
| GET | `/inventory/low-stock` | `inventory.read` | Itens com `stock_qty <= min_qty` |
| GET | `/inventory/config` | `inventory.read` | Config rica do módulo |
| PATCH | `/inventory/config` | `settings.manage` | Atualiza config |

Erros no formato padrão `{ statusCode, error, message }`. Validação por whitelist (class-validator).

### Service público (consumido pela OS no futuro — não pela UI deste módulo)
```ts
class InventoryService {
  // ... métodos da UI acima ...

  /** Busca 1 item por id (para a OS montar a linha por snapshot). */
  getItem(user: AuthUser, id: string): Promise<InventoryItem>;

  /** Busca enxuta para picker da OS (id, nome, tipo, preço, saldo). */
  searchForPicker(user: AuthUser, q: string, kind?: 'product'|'service'): Promise<ItemPick[]>;

  /** Aplica movimento programático (ex.: baixa por consumo de OS). Idempotência por ref no futuro. */
  applyMovement(tenantId: string, input: ApplyMovementInput): Promise<InventoryMovement>;
}
```
`applyMovement` aceita `tenantId` explícito (padrão `runWithTenant`) para o caso de a OS chamar
dentro do próprio contexto. **Nenhuma chamada externa dentro de transação de banco.**

## 5. Config (host incremental)

Registrar no `SettingsSectionRegistry` (`back/src/modules/settings/`), `moduleKey:'inventory'`,
seção aparece só com o módulo habilitado. Valores em `tenant_module.settings['inventory']`,
lidos/gravados via `BillingService.getModuleSettings`/`setModuleSettings` ("aponta, não invade").

| Config | Chave | Tipo | Default |
|---|---|---|---|
| Unidade padrão | `defaultUnit` | text | `un` |
| Rastrear estoque por padrão | `trackStockDefault` | bool | `true` |
| Margem padrão (%) | `defaultMarginPercent` | number | `null` |
| Sugestões de categoria | `categories` | lista de text | `[]` |

A seção registrada no host expõe os escalares (`defaultUnit`, `trackStockDefault`,
`defaultMarginPercent`); a lista `categories` é gerida pelos endpoints próprios `/inventory/config`
(espelha o padrão do `customers`). Documentar a subseção em `docs/configuracao.md`.

## 6. Permissões, cargos e billing

- **Permissões** já semeadas — usar exatamente: `inventory.read`, `inventory.write`.
- **Cargos (já mapeados nos seeds — NENHUMA mudança de cargo necessária):**
  `owner` (tudo) · `gerente` (todas exceto `billing.manage` ⇒ já tem `inventory.read`+`inventory.write`)
  · `caixa` (`inventory.read`) · `mechanic` (`inventory.read`, só leitura). Confirmado em
  `prisma/migrations/0003_employees_settings/migration.sql` + baseline.
- **Billing (seed aditivo):** adicionar `inventory` ao plano **`trial`** (hoje só no `pro`), para a
  conta de teste (trial) ver o módulo e a futura OS rodar de ponta a ponta. SQL aditivo no baseline
  + migration `0010`. `reconcileTenantModules` recalcula ao (re)assinar; tenants trial existentes
  precisam de um reconcile/relogin para o módulo aparecer (validar no e2e).

## 7. Front — feature `inventory`

`front/lib/features/inventory/` espelhando `customers`:
```
inventory/
├── domain/   inventory_models.dart (Item, Movement, ItemPage, InventoryConfig, drafts; freezed)
│             inventory_repository.dart (interface)
├── data/     inventory_repository_impl.dart (dio) · fake_inventory_repository.dart
└── presentation/
              inventory_providers.dart (Riverpod)
              inventory_screen.dart       (lista + filtros + badge "abaixo do mínimo")
              item_form_dialog.dart        (toggle Produto/Serviço adapta campos; markup helper)
              item_detail_screen.dart      (dados + histórico de movimentos + registrar movimento)
```
- Registrar providers em `di.dart`; rota em `core/router/app_router.dart` (gated por módulo).
- Item de menu (label "Estoque", ícone) em `shell/presentation/nav_items.dart`; aparece via
  `me.modules` + `gatedNavItems`. Router também guarda a rota (esconder ≠ proteger; 403 elegante).
- **Markup helper (UI):** ao informar custo + margem, sugere `sale_price`; usuário pode sobrescrever.
- Repo fake cobre os fluxos para testes de widget sem backend.
- **UI animada/ícones (requisito do produto):** usar ícones por tipo (produto vs serviço), por tipo de
  movimento (entrada/saída/ajuste) e estados (badge de "abaixo do mínimo"); tela com vida, não só
  tabela. Seguir o design system (grafite + tangerina, Sora/Manrope) e o padrão visual de `customers`.

## 8. Testes (evidência antes de "pronto")

- **Backend unit (jest):** invariantes por `kind` (serviço não rastreia estoque); cálculo de saldo
  (`in`/`out`/`adjust`, bloqueio de negativo); merge de config; markup (custo+margem→preço).
- **Backend e2e (jest+supertest+testcontainers):** **isolamento de tenant** (A não vê itens/movimentos
  de B); **autorização** (`mechanic` lê mas não escreve; `settings.manage` exigido na config);
  `@RequiresModule` bloqueia tenant sem o módulo; movimento atualiza `stock_qty`; archive some da
  busca padrão; `inventory` no trial visível após reconcile.
- **Front:** `flutter analyze` 0 issues; `flutter test` cobrindo providers/markup/repo fake.
- Critério: `npm run back:lint` (0 warnings) + `back:test` + `back:test:e2e`; `flutter analyze` +
  `flutter test` — **citar o output real** antes de afirmar "pronto".

## 9. Itens em aberto / decisões adiadas
- Tudo de "Não-metas" → [`docs/pendencias.md`](../../pendencias.md).
- Saldo negativo: bloqueado no v1; tornar configurável é pendência.
- Idempotência de `applyMovement` por `(ref_type, ref_id)`: desenhar quando a OS for ligada.
```
