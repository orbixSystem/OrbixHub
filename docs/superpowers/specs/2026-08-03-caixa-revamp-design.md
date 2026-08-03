# Revamp do Caixa + Controle de Fiado — design

**Data:** 2026-08-03 · **Status:** IMPLEMENTADO

| Entrega | Commit |
|---|---|
| `kind` no update, validação de valores, responsável padrão | `c4467d5` |
| Abertura sugerida + conferência de fechamento ao vivo | `958e62e` |
| Módulo backend `receivables` | `69376f0` |
| Aba Fiado | `af84c71` |
| Detalhe da venda + cancelar-e-refazer | `9e9dc75` |

Verificação final: **452 testes no front**, **314 no back**, `flutter analyze`
e ESLint sem nenhum aviso.

**Achado extra durante a implementação:** o `EntryDialog` tinha `saleKind: 'os'`
fixo — o caixa nunca soube receber uma VENDA de balcão em fiado, só OS. Não
estava no relato original e quebraria o fiado de venda avulsa. Coberto pelo
novo diálogo de recebimento, que aceita as duas origens e barra valor acima do
saldo (viraria dinheiro fantasma no caixa).

**Três incidentes de ambiente, todos dado local desatualizado e não código:**
caixa ausente no menu (tenant antigo sem `tenant_module` do `cashier`, backfill
nunca aplicado); `past_due forbids this operation` (trial do tenant de demo
vencido em 01/08, job diário marcou past_due — o guard funcionando como
projetado); e o `ci-db-setup.ts` que **não é reaplicável** num banco existente
(falha com `relation "tenant" already exists`), o que explica por que backfills
de módulos novos não chegam a bancos locais já criados.

## Problema

O caixa foi reprovado pelo dono do produto ("extremamente cru e bugado"). O
diagnóstico mostrou que o backend é maduro e a UI ignora o que ele entrega:

| Gap relatado | Causa real |
|---|---|
| Fechamento não importa valores | `getCurrentSession` já devolve `totals.expected` e `byMethod`; o diálogo promete "calculamos o esperado" e não mostra nada (`cashier_dialogs.dart:181`) |
| Abertura não importa valores | Hardcoded em `'0'` (`cashier_dialogs.dart:88`). Único gap que precisa de dado novo |
| Histórico cru | `listSessions` (back) e `SessionPage` (front) existem e nenhuma tela usa |
| Não detalha o que foi vendido | `SaleRepository.listSales/getSale/cancelSale` implementados, nenhuma tela chama |
| Erro ao editar item | `ItemDraft.toJson()` emitia `kind`, que `UpdateInventoryItemDto` não aceita |
| Venda avulsa aceita letras | É a única tela do app sem `inputFormatters` (7 outras usam) |
| Sem controle de fiado | Não existe visão agregada de quem deve |
| Responsável da OS confunde | Campo obrigatório nascendo vazio (`order_form_dialog.dart:51`) |

## Decisões

**Fiado = venda/OS com saldo > 0.** Sem tabela, sem flag, sem migration: uma
venda que ninguém pagou já é fiado. `payment_status` (`a_receber`/`parcial`/
`pago`) já é derivado do caixa em OS e em vendas.

**Vencimento, aging e limite de crédito ficam fora de escopo** — não foram
pedidos e exigiriam migration. O desenho não os impede.

**"Editar venda" = cancelar e refazer.** Cancela com motivo (auditado, estorna
estoque, estorna o lançamento) e abre nova venda pré-preenchida. **"Excluir" =
cancelar** — o projeto proíbe hard delete (regra 6) e apagar destruiria o rastro
de dinheiro.

**Módulo novo `receivables`, fino e sem tabela própria.** Compõe os services
públicos de OS, Vendas e Caixa. Não pode morar no `cashier`: OS e Vendas já
dependem dele e inverter criaria ciclo. Mesmo padrão do `sync`, que orquestra
vários services sem tocar tabela alheia ("aponta, não invade").

## Arquitetura

```
receivables (novo, sem tabela)
  ├─ OsService        (listOrders → total + payment_status)
  ├─ SaleService      (listSales  → total + payment_status + items)
  └─ CashierService   (getPaymentSummaryBatch → pago/saldo)
```

Endpoints (`@RequiresModule('cashier')`, `cashier.read`):
- `GET /receivables` → por cliente: `{ customerId, customerName, totalDue, titleCount }`
- `GET /receivables/:customerId` → títulos separados: origem (`os`|`sale`),
  número, data, total, pago, saldo **e itens**

Receber usa o `createEntry` existente (aceita parcial, aponta `saleKind`+`saleId`).

## Escopo

**Backend**
1. `deviceId` opcional no `SessionQueryDto` + filtro no repo → abertura sugerida
2. Módulo `receivables` (controller fino → service que compõe) + testes

**Front**
3. `inputFormatters` em todos os campos de valor da venda avulsa + validator no
   "Valor recebido" (hoje `TextField` cru)
4. Fechamento: esperado, diferença recalculada ao digitar, quebra por forma
5. Abertura: pré-preenchida com o contado do último fechamento do mesmo ponto
6. Aba "Fiado": devedores → títulos → itens → receber
7. Venda expandida: itens, pagamentos, cancelar-e-refazer
8. Responsável da OS pré-selecionado com o usuário logado (`assigned_to` = userId)

**Já concluído:** o bug do `kind` (`toUpdateJson()` nos dois call sites, 5 testes).

## Testes

- Back: composição do `receivables` (cliente sem dívida, saldo parcial, venda
  cancelada fora da conta), filtro por `deviceId`
- Front: formatters rejeitando letras, esperado/diferença no fechamento,
  agrupamento por cliente, responsável pré-selecionado

## Risco aceito

Sem paginação por dívida, o fiado agrupa em memória. Para uma oficina são
dezenas de registros. Se virar milhares, aí vale o título a receber com tabela
própria — custo que não se paga agora.
