# Estoque: ledger de movimentos + estorno no cancelamento/edição da OS

- **Data:** 2026-06-22
- **Branch sugerida:** `feat/stock-ledger`
- **Módulos afetados:** `inventory` (dono do ledger), `os` (consumidor via service público)
- **Status:** design aprovado (escopo enxuto)

---

## 1. Problema

Ao cancelar uma OS que estava em execução, os itens-produto **não voltam ao
estoque**. A baixa acontece na transição para `em_execucao`
([`os.service.ts:482`](../../../back/src/modules/os/os.service.ts#L482), método
`applyStock`), controlada por um booleano `stock_applied` (idempotente por OS).
Esse booleano tem **dois furos**:

1. **Cancelamento** (`em_execucao → cancelada`): nada estorna a baixa.
2. **Edição em execução**: a OS em `em_execucao` continua editável
   ([`os.service.ts:421`](../../../back/src/modules/os/os.service.ts#L421) só
   bloqueia status terminais). Adicionar/remover/alterar a quantidade de um
   item-produto **depois** da baixa não ajusta o estoque.

A causa-raiz é o `stock_applied` saber apenas "aplicou / não aplicou" — não sabe
*o quê* nem *quanto*, então não há como estornar de forma correta.

## 2. Decisão de produto (contexto)

Discutimos como ERPs tratam cancelamento com cobrança parcial. Conclusões que
guiam o escopo:

- **Estoque físico e cobrança são coisas separadas.** Peça instalada continua
  baixada (foi gasta de verdade) mesmo se a OS for cancelada; peça que ficou na
  prateleira volta.
- **Os itens da OS são o registro do que foi feito e cobrado.** "Cliente pagou
  metade" se resolve **editando a OS** para refletir o que de fato foi entregue —
  o total recalcula sozinho e vira o valor real.

### Fora de escopo (evolução futura — YAGNI por enquanto)

Estas ideias foram levantadas e **deliberadamente adiadas** até haver demanda
real de cliente:

- Status explícito `concluida_parcialmente` na FSM.
- Snapshot **orçado × realizado** lado a lado (planejado vs executado por item).
- Marcação item-a-item "instalado vs. não instalado" na UI de cancelamento.

O ledger desenhado abaixo já guarda o histórico necessário para construir
qualquer uma delas depois, sem retrabalho de fundação.

## 3. Escopo desta entrega

1. **Tabela `stock_movement`** (diário de estoque), dona do módulo `inventory`,
   substituindo a *semântica* do booleano `stock_applied`.
2. **Cancelar OS** → estorna (movimento de entrada) tudo que havia sido baixado e
   não foi consumido.
3. **Editar item-produto de OS em execução** → gera movimento compensatório
   (remover peça = estorna; reduzir qtd = estorna a diferença; aumentar = baixa a
   mais). Isso cobre a "conclusão parcial" via edição.

## 4. Arquitetura

### 4.1. Saldo materializado + diário

`inventory_item.current_stock` **continua existindo** como saldo materializado —
as queries de métrica/relatório que já o leem
([`inventory.repository.ts`](../../../back/src/modules/inventory/inventory.repository.ts),
`stockValue`, `listForReport`, `countBelowMin`) **não mudam**. O
`stock_movement` é o diário (journal); cada movimento ajusta o saldo
atomicamente, na mesma transação.

### 4.2. Regra única que substitui `stock_applied`

Uma OS **consome** estoque enquanto seu status pertence a:

```
CONSUMINDO = { em_execucao, concluida, entregue }
```

Nos demais status (`aberta`, `aguardando_aprovacao`, `aprovada`, `cancelada`) a
OS **não consome**.

A cada mudança de status e a cada edição de item-produto, a OS **reconcilia**
cada linha-produto vinculada ao estoque:

```
alvo   = consome(status) ? quantidade_da_linha : 0
prev   = consumo já registrado para essa linha   // derivado do diário, ver 4.3
delta  = alvo - prev
se delta ≠ 0:
    movimento_estoque = -delta          // consumir reduz saldo; estornar aumenta
    grava stock_movement(stock_delta = movimento_estoque, reason)
    current_stock += movimento_estoque  // consumo valida saldo ≥ 0
```

Idempotente por construção (re-rodar com o mesmo alvo gera `delta = 0`). Cobre
todos os casos com **uma** função:

| Ação | alvo | efeito |
|---|---|---|
| `→ em_execucao` | quantidade | baixa |
| `→ cancelada` | 0 | estorna tudo |
| reduzir qtd (em execução) | nova qtd | estorna a diferença |
| remover item (em execução) | 0 | estorna a linha |
| aumentar qtd (em execução) | nova qtd | baixa a mais |
| `cancelada → aberta` (reabrir) e depois re-executar | quantidade | re-baixa |

### 4.3. "Aponta, não invade" — quem é dono do quê

- **`inventory` é dono do `stock_movement`** e de toda a contabilidade. Deriva o
  `prev` (consumo já registrado de uma linha) somando os próprios movimentos por
  `ref_item_id` — **não precisa de coluna nova na tabela da OS**.
- **`os` só chama o service público** do inventory, passando o `id` da linha
  (`ref_item_id`), o `ref_id` da OS e a quantidade-alvo. A OS **nunca** toca
  `stock_movement` nem `inventory_item`.

Novo método público no `InventoryService` (assinatura conceitual):

```ts
// Reconcilia o consumo de UMA linha de origem (ex.: item de OS) para a quantidade-alvo.
// Idempotente. Abre a própria tx (runWithTenant) — NÃO chamar dentro de withTenantTx.
reconcileConsumption(tenantId: string, args: {
  inventoryItemId: string;
  refType: 'service_order';
  refId: string;        // id da OS
  refItemId: string;    // id da linha service_order_item
  targetQty: number;    // alvo de consumo (0 = liberar tudo)
  createdBy?: string | null;
}): Promise<void>
```

Internamente: `prev = -Σ(stock_delta where ref_item_id = refItemId)`;
`delta = targetQty - prev`; se `delta ≠ 0`, grava movimento e ajusta saldo.

> **Pool de conexões:** segue o padrão atual do `applyStock` — as chamadas ao
> inventory rodam **fora** de qualquer `withTenantTx` da OS (cada uma abre a
> própria via `runWithTenant`). Nunca aninhar (esgota o pool).

> **Best-effort vs. consistência:** o `applyStock` atual engole erros (estoque
> insuficiente não bloqueia a transição). Mantemos esse comportamento na v1 —
> reconciliação é best-effort e loga aviso; a transição/edição não falha por
> causa de estoque. (Decisão revisável; ver §8.)

### 4.4. Pontos de chamada na OS

- `changeStatus` ([`os.service.ts:432`](../../../back/src/modules/os/os.service.ts#L432)):
  após persistir o novo status, reconciliar **todas** as linhas-produto para o
  alvo conforme `consome(novoStatus)`. Substitui o bloco `if (to === 'em_execucao'
  && !order.stock_applied) applyStock(...)`.
- `addItem` / `updateItem` / `deleteItem`
  ([`os.service.ts:519`](../../../back/src/modules/os/os.service.ts#L519) em
  diante): se a OS está em status `CONSUMINDO`, reconciliar a linha afetada após a
  escrita (add → alvo=qtd; update → alvo=novaQtd; delete → alvo=0 antes de
  apagar, ou reconciliar por `ref_item_id` após).

### 4.5. Timeline / auditoria

- Estorno por cancelamento adiciona um evento de nota (interno) na timeline da OS
  resumindo o que voltou ao estoque (best-effort, não bloqueia).
- Movimentos relevantes podem virar `audit.log` (`inventory_stock_movement`),
  seguindo o padrão dos outros mutadores do inventory.

## 5. Schema — migração `0024_stock_movement` (aditiva, 3 lugares)

Refletir em: `sql/auth-multitenant-schema.sql` (canônico/idempotente) +
`prisma/migrations/0024_stock_movement/migration.sql` + `prisma/schema.prisma`.

### 5.1. Tabela `stock_movement` (tenant-scoped, RLS + FORCE)

| coluna | tipo | nota |
|---|---|---|
| `id` | uuid PK | |
| `tenant_id` | uuid | RLS `tenant_id = current_tenant_id()` |
| `inventory_item_id` | uuid FK → `inventory_item` | indexado |
| `stock_delta` | numeric | negativo = saída (consumo); positivo = entrada (estorno) |
| `reason` | text | `os_consumption` \| `os_reversal` (extensível) |
| `ref_type` | text | `service_order` (genérico) |
| `ref_id` | uuid | id da OS |
| `ref_item_id` | uuid null | id da `service_order_item` — chave da reconciliação |
| `created_by` | uuid null | |
| `created_at` | timestamptz default now() | |

Índices: `(tenant_id)`, `(inventory_item_id)`, `(ref_item_id)`,
`(ref_type, ref_id)`. RLS + FORCE com a policy padrão
`tenant_id = current_tenant_id()`.

### 5.2. Backfill das OS já aplicadas

Para cada `service_order_item` que seja produto vinculado ao estoque, cuja OS
tenha `stock_applied = true` e status ainda em `CONSUMINDO`, inserir **um
movimento-espelho** `stock_delta = -quantity`, `reason = 'os_consumption'`,
`ref_item_id = item.id`. **Não** ajustar `current_stock` no backfill (o saldo já
reflete a baixa histórica) — o objetivo é só fazer o `prev` derivado bater com a
realidade, para que futuros estornos calculem o `delta` certo.

### 5.3. `stock_applied`

Deprecado: paramos de **ler/escrever** o campo na lógica nova. A coluna é
**mantida** (migração aditiva, não quebrar baseline). Pode ser removida numa
limpeza futura.

## 6. Frontend

Nenhuma mudança estrutural obrigatória nesta entrega. A correção é
backend-driven: cancelar/editar a OS passa a estornar o estoque, e a tela de
estoque (que já lê `current_stock`) reflete sozinha. Opcional (fica para a UX
de cancelamento): um diálogo de confirmação no cancelar mostrando "X itens
voltarão ao estoque" — registrado como melhoria, não bloqueante.

## 7. Testes (evidência antes de "pronto")

Backend (`npm run back:lint` 0 warnings + `back:test` + `back:test:e2e`):

- **Unit (reconciliação):** idempotência (rodar 2× → 1 movimento); consumo na
  entrada em execução; estorno total no cancelamento; estorno parcial ao reduzir
  qtd; estorno ao remover item; baixa extra ao aumentar qtd; linha de serviço
  (sem `inventory_item_id`) é ignorada; saldo nunca fica negativo (ou erro
  controlado, conforme §4.3).
- **e2e (`back/test/os.e2e-spec.ts`):** fluxo abrir → addItem produto → executar
  (estoque baixou) → cancelar (estoque voltou); fluxo executar → reduzir qtd
  (estoque parcial volta) → concluir (saldo permanece).
- **Isolamento de tenant:** movimentos de A não afetam saldo/leitura de B.

## 8. Decisões em aberto (resolver na fase de plano)

1. **Best-effort vs. bloquear:** manter o comportamento atual (estoque
   insuficiente não impede a transição, só loga) ou passar a bloquear? Proposta:
   manter best-effort na v1.
2. **Reabertura (`cancelada → aberta`):** ao reabrir, a OS volta a `aberta`
   (não-consumindo) — estoque permanece estornado até reentrar em execução. A
   reconciliação na próxima transição cobre isso naturalmente. Confirmar que é o
   comportamento desejado.
3. **Granularidade de auditoria:** logar 1 evento por movimento ou 1 resumo por
   ação? Proposta: resumo por ação na timeline + `audit.log` por ação.
```
