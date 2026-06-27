# Módulo Caixa (`cashier`) — Design

> Status: aprovado 2026-06-27. Branch `feat/cashier`. Vertical: genérico (oficina é o
> primeiro consumidor). Módulo **contratado** (`@RequiresModule('cashier')`).

## 1. Conceito

O Caixa é o **registrador de dinheiro** e a **visão central** (livro caixa) do que entrou
e saiu. Ele **não** é dono do status de pagamento da venda nem emite nota. Um recebimento
**aponta** para a venda (`{ sale_kind, sale_id }`) e lê o total dela **via o service público**
da venda — "aponta, não invade".

### Decisões de escopo (definidas no brainstorming)

- **`sale` / venda avulsa não existe ainda.** Só existe o módulo `os`. As colunas
  `sale_kind ('os'|'sale')` e `sale_id` ficam **forward-compatible** (nullable), mas só o
  recebimento de **OS** é fiado nesta entrega. "Venda avulsa" é uma `cash_entry` com
  `category='venda_avulsa'` e `sale_id` null (lançamento de dinheiro sem venda vinculada).
  Nenhum módulo novo é criado.
- **Ciclo financeiro fechado:** a OS passa a expor status de pagamento (pago/parcial/a
  receber) lendo o `CashierService`. Dependência circular Nest resolvida com `forwardRef`.
- **Fechamento `countCashOnly`** (default): `expected` considera só dinheiro; pix/cartão são
  totais informativos.
- **Estorno = soft-flag** (`reversed_at`/`reversed_by`/`reversal_reason` na entry original,
  somada-fora dos totais, mantida no extrato), seguindo o padrão `deleted_at` do código.

## 2. Backend — `back/src/modules/cashier/`

Camadas: **controller fino → service (lógica) → repository (único que toca o banco via
`TenantContext`)**. Padrão idêntico ao módulo `inventory`.

### 2.1 Migration `0025_cashier` (aditiva, nos 3 lugares)

`sql/auth-multitenant-schema.sql` (canônico/idempotente) + `prisma/migrations/0025_cashier/migration.sql`
+ `prisma/schema.prisma` (à mão). RLS + FORCE + policy `tenant_isolation USING/ WITH CHECK
(tenant_id = current_tenant_id())` nas duas tabelas. Sem hard delete.

**`cash_session`**
| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| tenant_id | uuid NOT NULL → tenant | |
| opened_by | uuid NOT NULL | user id (CLS) |
| opened_at | timestamptz NOT NULL default now() | |
| opening_amount | numeric(14,2) NOT NULL default 0 | |
| closed_by | uuid null | |
| closed_at | timestamptz null | |
| closing_amount_counted | numeric(14,2) null | informado no fechamento |
| closing_amount_expected | numeric(14,2) null | calculado |
| difference | numeric(14,2) null | counted − expected |
| status | text NOT NULL default 'open' | check ('open','closed') |
| notes | text null | |
| created_at / updated_at | timestamptz NOT NULL default now() | |

Índice parcial único: `uq_cash_session_one_open ON cash_session(tenant_id) WHERE status='open'`
→ **uma sessão aberta por tenant**.

**`cash_entry`**
| coluna | tipo | nota |
|---|---|---|
| id | uuid PK | |
| tenant_id | uuid NOT NULL → tenant | |
| cash_session_id | uuid NOT NULL → cash_session | |
| direction | text NOT NULL | check ('in','out') |
| amount | numeric(14,2) NOT NULL | check (amount > 0) |
| method | text NOT NULL | check ('pix','dinheiro','cartao_credito','cartao_debito','outro') |
| category | text NOT NULL | check ('os_payment','venda_avulsa','despesa','sangria','suprimento') |
| sale_kind | text null | check ('os','sale') |
| sale_id | uuid null | aponta p/ a venda |
| description | text null | |
| reversed_at | timestamptz null | estorno lógico |
| reversed_by | uuid null | |
| reversal_reason | text null | |
| created_by | uuid NOT NULL | |
| created_at | timestamptz NOT NULL default now() | |

Índices: `(tenant_id, cash_session_id)`, `(tenant_id, sale_kind, sale_id)`,
`(tenant_id, created_at)`, `(tenant_id, category)`, `(tenant_id, method)`.

### 2.2 Seeds

- `module ('cashier','Caixa')`.
- `plan_module`: cashier em **trial + pro** (aparece no dono de teste).
- Permissões `cashier.*` (já semeadas — confirmar nomes no SQL). Mapeamento em `role_permission`:
  `owner`/`gerente` = todas; `caixa` = operar+ler; `mechanic` = nenhuma.

### 2.3 Endpoints — `@Controller('cashier')` + `ModuleAccessGuard` + `@RequiresModule('cashier')`

| método | rota | permissão | nota |
|---|---|---|---|
| POST | `/cashier/sessions/open` | cashier.operate | `{opening_amount, notes?}`; falha se já há sessão aberta |
| POST | `/cashier/sessions/close` | cashier.operate | `{closing_amount_counted, notes?}` → calcula expected/difference |
| GET | `/cashier/sessions/current` | cashier.read | sessão aberta (ou null) |
| GET | `/cashier/sessions` | cashier.read | histórico paginado |
| POST | `/cashier/entries` | cashier.operate | recebimento/avulso/despesa; exige sessão aberta se `requireOpenSession` |
| POST | `/cashier/entries/:id/reverse` | cashier.manage | estorno lógico + `audit.log` |
| GET | `/cashier/entries` | cashier.read | **extrato** — filtros (sessão/direção/método/categoria/sale_kind+sale_id) + paginação |
| GET | `/cashier/summary` | cashier.read | `?from&to` → totais por método/categoria/origem |
| GET | `/cashier/payment-summary` | cashier.read | `?sale_kind=os&sale_id=…` |
| GET | `/cashier/config` | cashier.read | settings do módulo |
| PATCH | `/cashier/config` | cashier.manage | `paymentMethods`, `requireOpenSession`, `countCashOnly` |

> **Nota de implementação (ajuste vs. design inicial):** o branch já trazia o contrato
> **congelado** `CashierService` (`getPaymentSummary`/`getPaymentSummaryBatch`) com binding
> Noop, e a OS já o consumia passando o **próprio total** (`fallbackTotal`). A entrega
> **reusou esse contrato** (swap Noop → impl real via `useExisting`), então **não** foi
> preciso `OsService.getOrderValue` nem `forwardRef` — o caixa não depende da OS (sem
> dependência circular). O endpoint HTTP `GET /cashier/payment-summary` recebe um `total`
> **opcional** informado pelo dono da venda (a venda sabe seu total), preservando "aponta,
> não invade". A integração de exibição do status no front da OS (tag) pertence ao slice
> paralelo de OS/sales-payment.

### 2.4 Aponta, não invade (regra 1)

- **Cashier → OS:** `OsService.getOrderValue(id): Promise<number>` — método público novo e fino
  (hoje o total só é computado internamente). Caixa **nunca** toca `service_order`.
- **OS → Cashier:** `OsService` enriquece o detalhe da OS com `CashierService.getPaymentSummary('os', id)`
  (só quando o módulo cashier está habilitado p/ o tenant). Circular dep → `forwardRef` nos dois
  módulos; ambos exportam o service.
- **Seam público** `getPaymentSummary(saleKind, saleId)` →
  `{ total (via service da venda), paid (Σ entries 'in' não-estornadas dessa venda), balance,
  status: 'a_receber'|'parcial'|'pago', entries[] }`.

### 2.5 Regras de cálculo

- **paid** = Σ `amount` de entries `direction='in'`, `reversed_at IS NULL`, do par `(sale_kind, sale_id)`.
- **status**: `paid<=0` → a_receber; `0<paid<total` → parcial; `paid>=total` → pago.
- **Fechamento (`countCashOnly`)**: `expected = opening_amount + Σ(in,dinheiro,ñ estornado) −
  Σ(out,dinheiro,ñ estornado)`; `difference = counted − expected`. Pix/cartão = totais informativos.
- **`getCashSummary(from,to)`**: agrega entries não-estornadas → `byMethod`, `byCategory`, `byOrigin`
  (os/sale/nenhum), `totalIn`, `totalOut`, `net`. Base dos relatórios (recebido).

### 2.6 Config (host incremental)

`SettingsSectionRegistry.register({ key:'cashier', title:'Caixa', moduleKey:'cashier', fields:[
paymentMethods (lista), requireOpenSession (bool, default true), countCashOnly (bool, default true) ]})`.
Persistido em `tenant_module.settings['cashier']`.

## 3. Frontend — `front/lib/features/cashier/`

Feature-first: **presentation → domain (interface) → data (dio + fake)**. UI só fala com repository.

- **domain**: `cashier_models.dart` (freezed: `CashSession`, `CashEntry`, `PaymentSummary`,
  `CashSummary`, `CashierConfig` + drafts; estados de tela como unions selados),
  `cashier_repository.dart` (interface).
- **data**: `cashier_repository_impl.dart` (dio) + `fake_cashier_repository.dart`.
- **presentation**: `cashier_providers.dart` + telas:
  - **Caixa do dia**: sem sessão → *Abrir caixa* (valor inicial); com sessão → **extrato**
    (tabela entradas/saídas: método/categoria/origem) + totais por método + *Fechar caixa*
    (contado → mostra diferença).
  - **Receber venda** (dialog): pagamento de OS — parcial + múltiplas formas.
  - **Lançamento avulso / despesa** (sem venda).
- **Integração OS**: no detalhe da OS, chip de status (pago/parcial/a receber) + botão *Receber*,
  visível só se `me.hasModule('cashier')`.
- Wiring: `di.dart` (provider), `app_router.dart` (`/m/cashier`), `nav_items.dart`
  (`'cashier': ('Caixa', Icons.point_of_sale_outlined)`).

## 4. Testes

- **Backend e2e**: isolamento de tenant (A não vê caixa de B); 1 sessão aberta por tenant;
  recebimento parcial + N formas; `getPaymentSummary` correto (total via OsService); extrato com
  filtros; `getCashSummary`; estorno lógico fora dos somatórios; autorização (`caixa` opera,
  `mechanic` 403). **Unit**: cálculo `expected`/`difference`; derivação do status.
- **Front**: `gatedNavItems` mostra Caixa quando módulo presente; widget de status; fluxos via
  fake repo. `flutter analyze` 0 issues + `flutter test`.

## 5. Critérios de aceite (do prompt)

1. Abrir/fechar com `expected` × `counted` × `difference`; uma sessão open por tenant. ✅
2. Recebimento parcial e múltiplas formas (OS); `getPaymentSummary` correto (total via service). ✅
3. Extrato lista tudo com filtros; `getCashSummary` entrega totais. ✅
4. Estorno lógico, nunca hard delete; isolamento de tenant. ✅
5. "Aponta, não invade": total da venda via service; sem tocar a tabela da OS. ✅
6. Config registrada; suíte verde. ✅

## 6. Entregáveis

Backend `cashier` + telas (caixa do dia, extrato, receber, avulso/despesa) + config registrada +
seam/integração OS. Atualizar `docs/modulos-v1.md` e `docs/configuracao.md`. Branch `feat/cashier`;
ao final, cherry-pick para `dev-kaue`.
