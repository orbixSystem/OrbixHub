# Estoque / Produtos (`inventory`) — Módulo 4 (spec refinado, supersede o de 2026-06-15)

> Apoia-se na skill `orbixhub-arquitetura` (RLS/FORCE, `withTenantTx`/`runWithTenant`,
> Controller→Service→Repository, "aponta não invade", sem hard delete, whitelist,
> segredos via env, nenhuma chamada externa dentro de transação — não repetidos aqui).
> **Tipo:** Contratado · **Reuso:** Genérico · gated por `@RequiresModule('inventory')`.
> **Inegociável:** genérico — nada de "veículo/placa/aplicação" hardcoded; o específico
> da vertical entra por `itemFields` + `attributes` (mesmo padrão do `subject`/`subjectFields`).

## Reconciliação com o que já foi construído (2026-06-15)
Este spec **supersede** `2026-06-15-inventory-estoque-servicos-design.md` e reverte/ajusta:
- **Preços decimais** (não centavos).
- **Inventory = só produtos.** `kind`/serviço **saem** do inventory; serviço é o **módulo 3
  (Catálogo de serviços)**, ainda não implementado. A aba "Serviço" do front fica como
  placeholder "em breve" até o módulo 3 existir.
- **Sem tabela de movimentações** (drop `inventory_movement` + UI de movimento). Estoque é
  ajustado **direto** em `currentStock`; histórico detalhado fica para quando a OS chegar.
- **Novos:** `sku` + `manufacturerCode` + `barcode`; `attributes` + `itemFields`; fluxo
  **código-first** (`/inventory/lookup`) com `CatalogProvider` (Noop/Cosmos), cache Redis.
- **Permissão:** mantém `inventory.read` / `inventory.write` (seed real); o spec citou
  `inventory.manage` mas ele não existe no catálogo.
- **Migration:** revisar **0010 no lugar** (módulo ainda não merjado) nos 3 lugares + reset
  das tabelas no DB de dev.

## 1. Escopo
Cadastro de **produto** (item com estoque), listagem/busca, alerta de estoque mínimo, e o
**fluxo código-first** (resolver por barras/fabricante e pré-preencher). Baixa na OS fica fora:
expor só o **service público** (`getItem`, `incrementStock`, `decrementStock`).

## 2. Modelo de dados — `inventory_item` (decimal; sem `inventory_movement`)
| Campo (snake_case no DB) | Tipo | Notas |
|---|---|---|
| `id` | uuid | PK |
| `tenant_id` | uuid | RLS (do JWT) |
| `name` | text | obrigatório |
| `sku` | text? | código interno; único por tenant quando preenchido |
| `manufacturer_code` | text? | part number; indexado |
| `barcode` | text? | EAN/GTIN; indexado; único por tenant quando preenchido |
| `category` | text? | texto livre (sem tabela de categoria na v1) |
| `brand` | text? | marca/fabricante |
| `unit` | text? | "un","peça","jogo","L"… |
| `sale_price` | numeric(14,2)? | preço de venda |
| `cost_price` | numeric(14,2)? | preço de custo |
| `margin_pct` | numeric(7,2)? | margem; pode ser derivada custo/venda no service |
| `current_stock` | numeric(14,3) | default 0 |
| `min_stock` | numeric(14,3)? | gatilho do alerta |
| `attributes` | jsonb | campos da vertical; default `'{}'` |
| `is_active` | boolean | default true (arquivar = false; sem hard delete) |
| `created_at`/`updated_at` | timestamptz | |

Índices: `(tenant_id, barcode)`, `(tenant_id, manufacturer_code)`, `(tenant_id, sku)`; uniques
parciais `(tenant_id, barcode) WHERE barcode IS NOT NULL` e `(tenant_id, sku) WHERE sku IS NOT NULL`.
RLS + FORCE + policy `tenant_isolation`. **Não** criar tabela de fitment/aplicação (vive em `attributes`).

## 3. `itemFields` + `attributes` (campos de vertical) — espelha `subjectFields`/`attributes`
- Config do módulo (`tenant_module.settings["inventory"].itemFields`), lida/gravada via
  `BillingService` (registra a seção no host de settings). `itemFields[]`:
  `{ key, label, type, required, options? }`, `type ∈ text|number|tags|select`.
- **Defaults por vertical = a casca da vertical no provisionamento** (oficina semeia
  `vehicleApplication: tags`); o inventory nunca conhece "veículo". Na v1, default `itemFields = []`.
- **Validação (service):** `attributes` whitelist contra `itemFields` — chave desconhecida → 400;
  tipo errado → 400; `required` ausente → 400.
- **Front:** busca `itemFields` via settings e renderiza os campos extras dinamicamente.

## 4. Código-first — `GET /inventory/lookup?code=<valor>` (não persiste)
Cascata no service:
1. **Interno:** procura no tenant por `barcode|manufacturer_code|sku == code` → `source:"internal"` + `item`.
2. **Catálogo por EAN:** se `code` é GTIN válido (8/12/13/14 dígitos + dígito verificador) e provider ligado → `CatalogProvider.lookupByGtin` → `source:"catalog"` + `suggestion` (name, brand, ncm, category). Não cria item.
3. **Catálogo por código de fabricante:** gancho (TecDoc/Auto Experts) → `Noop` devolve vazio.
4. Nada → `source:"none"`.

Resposta: `{ source: "internal"|"catalog"|"none", item?, suggestion? }`.

**Provider** (interface, padrão NoopGateway): `interface CatalogProvider { lookupByGtin(gtin): Promise<CatalogHit|null> }`;
impls `NoopCatalogProvider` (default) e `CosmosCatalogProvider`. Knobs: `CATALOG_PROVIDER=noop|cosmos`,
`COSMOS_TOKEN`, `CATALOG_ENABLED=false`. Chamada externa **fora de transação**; cache por GTIN no
**Redis** (Cosmos tem rate-limit/429 — degrada para `none` + log). Token nunca vai ao front.

## 5. Endpoints (`@RequiresModule('inventory')`)
| Método | Rota | Perm | O que faz |
|---|---|---|---|
| GET | `/inventory/items` | read | lista; filtros `q`(name/sku/barcode/fabricante), `category`, `lowStock=true`, `active` |
| GET | `/inventory/items/:id` | read | detalhe |
| POST | `/inventory/items` | write | cria (valida `attributes` vs `itemFields`) |
| PATCH | `/inventory/items/:id` | write | edita |
| POST | `/inventory/items/:id/archive` | write | `is_active=false` |
| POST | `/inventory/items/:id/unarchive` | write | `is_active=true` |
| GET | `/inventory/lookup?code=` | read | resolução código-first (§4) |
| GET | `/inventory/config` / PATCH | read / `settings.manage` | `itemFields` rico (lista) |
`lowStock=true` → `current_stock <= min_stock AND min_stock IS NOT NULL`.

## 6. DTOs (class-validator, whitelist + forbidNonWhitelisted)
- `CreateInventoryItemDto`: `name` (obrigatório); `sku`/`manufacturerCode`/`barcode`/`category`/`brand`/`unit` (string opc); `salePrice`/`costPrice`/`marginPct`/`currentStock`/`minStock` (number opc ≥0); `attributes` (objeto, validado dinâmico no service).
- `UpdateInventoryItemDto`: partial. `ItemQueryDto`: `q`,`category`,`lowStock`,`active`,paginação. `LookupQueryDto`: `code`.

## 7. Seam com a OS (módulo 5) — só deixar pronto
Service público: `getItem(id)` (snapshot), `decrementStock(id, qty)` / `incrementStock(id, qty)`
(ajusta `current_stock` direto, valida saldo ≥0). Sem tela; sem tabela de movimento.

## 8. UI (front)
1. Aba **Produto | Serviço** (Serviço → placeholder "Catálogo de Serviços (módulo 3) em breve").
2. **Bloco código-first em destaque no topo**: input único (barras/fabricante) + "Buscar e preencher" → `/inventory/lookup` → aplica `suggestion` (campos editáveis). Caminho primário.
3. Campos do núcleo, com **`manufacturerCode` e `barcode` primeiro**, depois name, category, brand, unit, preços, margem, estoque mínimo, estoque atual.
4. **Seção de campos da vertical** a partir de `itemFields` (tags/select/etc.).

## 9. Fora de escopo (v1/validação)
Tabela de categorias; fitment estruturado/TecDoc (só gancho Noop); tabela de movimentações com
histórico (ajuste direto); múltiplos depósitos; conversão de unidades. (→ `docs/pendencias.md`)

## 10. Testes
`attributes` rejeita chave fora de `itemFields` / aceita declaradas; `lookup` interno antes de
externo, EAN inválido não chama provider, Noop → none, 429 não derruba (degrada none+log);
uniques por tenant (`barcode`,`sku`) + isolamento RLS; `archive` não apaga; `lowStock` filtra certo.
