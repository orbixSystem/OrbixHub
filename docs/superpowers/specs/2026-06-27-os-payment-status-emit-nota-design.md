# OS — Status de pagamento + Emitir Nota Fiscal (design)

> Data: 2026-06-27 · Branch: `feat/sales-payment` · Prompt A (coordena com Prompt B/Caixa e Fiscal)

## Escopo

Tornar a OS o "documento de venda" no que toca a **status de pagamento** e **emissão de
nota fiscal**, **sem acoplar** caixa ou fiscal (referência por id + service público).

**Fora de escopo (decisão do usuário 2026-06-27):** `quick_sale` / venda avulsa / balcão
e a coluna `type` em `service_order` — virão como um **módulo `sale` separado** depois.
Consequentemente a regra de métricas "operacional exclui quick_sale / receita inclui" não
se aplica nesta task (não há quick_sale para excluir).

## Decisões (brainstorm aprovado)

1. **Contrato do Caixa via interface + stub Noop.** `cashier` ainda não existe (Prompt B).
   Defino `CashierService` (classe abstrata = token de injeção) + `NoopCashierService` em
   `back/src/modules/cashier`. OS injeta o token. Prompt B troca o binding pelo real,
   **mantendo a assinatura abstrata como contrato congelado**.
2. **Batch para a listagem.** `CashierService.getPaymentSummaryBatch(tenantId, ids)` evita
   N+1 ao montar a tag na lista de OS.
3. **Status fiscal = snapshot na OS, Fiscal é dono.** OS guarda `fiscal_status` (+ id/at)
   só para exibir o que `InvoiceService.emit` devolveu; o Fiscal continua autoridade.
4. **Sem quick_sale nesta task** (ver Escopo).

## Contratos (ports)

```ts
// back/src/modules/cashier
export type PaymentStatus = 'a_receber' | 'parcial' | 'pago';
export interface PaymentSummary { total: number; paid: number; balance: number; status: PaymentStatus; }

export abstract class CashierService {
  // venda = service_order.id (genérico p/ futuro sale)
  abstract getPaymentSummary(tenantId: string, vendaId: string, fallbackTotal?: number): Promise<PaymentSummary>;
  abstract getPaymentSummaryBatch(tenantId: string, vendas: { id: string; total: number }[]): Promise<Map<string, PaymentSummary>>;
}
// NoopCashierService: paid=0 ⇒ { total, paid:0, balance:total, status:'a_receber' }
// Derivação: paid<=0 → a_receber; paid+ε >= total → pago; senão parcial.
```

```ts
// back/src/modules/invoice
export type FiscalStatus = 'nao_emitida' | 'processando' | 'emitida' | 'rejeitada';
export interface FiscalResult { status: FiscalStatus; externalId?: string | null; message?: string | null; }

export abstract class InvoiceService {
  abstract isAvailable(): boolean;                 // Noop → false; UI gateia o botão
  abstract emit(tenantId: string, vendaId: string, payload: InvoiceEmitPayload): Promise<FiscalResult>;
}
// NoopInvoiceService.isAvailable()=false; emit() lança ServiceUnavailableException (503).
```

`InvoiceEmitPayload` = `{ items, customer, company }` montados pela OS (itens + cliente +
empresa), passados ao Fiscal — a OS dispara, o Caixa não participa.

## Schema (aditivo — 3 lugares: sql canônico, prisma/migrations, schema.prisma)

`service_order` ganha (todos nullable, sem default destrutivo):
- `fiscal_status TEXT NULL`
- `fiscal_external_id TEXT NULL`
- `fiscal_emitted_at TIMESTAMPTZ NULL`

Sem coluna de pagamento (derivado do caixa em runtime). RLS herdada da tabela. Migration
nova com o próximo número.

## Backend

- `OsService.getOrderOrThrow(id)` → inclui `payment: PaymentSummary` (via
  `CashierService.getPaymentSummary` passando `order.total`) e `fiscal_status` armazenado.
- `OsService.listOrders` → enriquece cada linha com `paymentStatus` via **uma**
  `getPaymentSummaryBatch`.
- Endpoint `POST /os/orders/:id/invoice` → `@RequiresModule('os')` +
  `@Permissions('invoice.issue')`; monta payload, chama `InvoiceService.emit`, faz snapshot
  de `fiscal_status/external_id/emitted_at`, audita (`AuditService.log` `os_emit_invoice`).
  Noop ⇒ 503 tratado com elegância. **Não altera o status da OS.**
- `CashierModule`/`InvoiceModule` exportam os tokens; `OsModule` os importa.

## Frontend

- `PaymentTag` (PT-BR): **Paga** (success) / **A receber** (inkMuted) / **Parcial** (warning).
- Renderizar em `_OrderTile` (lista) e `_Header` (detalhe).
- `ServiceOrder` ganha `paymentStatus` e `fiscalStatus`; `OsRepository.emitInvoice(id)`
  (impl dio + fake).
- Detalhe: botão **"Emitir Nota Fiscal"** gated por permissão `invoice.issue` **e**
  disponibilidade do fiscal; exibe badge de `fiscalStatus`. Noop ⇒ desabilitado com
  tooltip "Fiscal em breve". `/me` não expõe disponibilidade do fiscal hoje ⇒ a UI infere
  pela resposta 503 do endpoint (botão sempre visível p/ quem tem permissão, com feedback
  claro quando indisponível).

## Testes

- Backend: isolamento de tenant; derivação a_receber (Noop); `emit` chama `InvoiceService`
  e não o caixa; `emit` não muda status da OS; gating de permissão/módulo; snapshot fiscal.
- Front: `PaymentTag` renderiza os 3 estados; botão Emitir Nota gated (fake repos).

## Critérios de aceite (recorte desta task)

2. Status de pagamento derivado do caixa; OS nasce `a_receber`; emitir nota não altera pagamento.
3. Tag de pagamento na listagem e dentro da OS.
4. "Emitir Nota" chama `InvoiceService` por service (não o caixa); status fiscal vem do Fiscal.
6. "Aponta, não invade": caixa/fiscal só via service. Suíte verde.

(Itens 1 e 5 do prompt original dependem de `quick_sale`, adiado para o módulo `sale`.)
