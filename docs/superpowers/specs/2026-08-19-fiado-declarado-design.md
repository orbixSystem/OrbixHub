# Fiado declarado — o título só vira dívida depois de passar pelo caixa

Data: 2026-08-19 · Status: aprovado, não implementado

## Problema

Hoje "fiado" não existe como estado: o módulo `receivables` é um orquestrador
sem tabela própria que **deriva** a dívida. O `openTitles` considera devedora
toda OS que não está `cancelada` e cujo pago é menor que o total.

Como uma OS nasce `aberta` já com os itens lançados e zero recebido, ela entra
na carteira de fiado **no ato da criação** — antes de o serviço ter sido feito,
antes de qualquer conversa sobre pagamento. A carteira de cobrança fica poluída
de trabalho em andamento.

O segundo sintoma vem do diálogo "Receber título" (`receive_title_dialog.dart`),
que tem `Validators.positiveNumber` mais uma trava `if (valor <= 0)`. O operador
que não recebeu nada e quer registrar "isso vai ficar fiado" não consegue: a tela
exige um valor maior que zero.

Observação: a **venda avulsa já se comporta como desejado** — o campo "Valor
recebido" aceita zero e existe o modal "Registrar como fiado?". A trava é só no
diálogo de receber título.

## Decisão

Fiado deixa de ser derivado e passa a ser **declarado**. Um título (OS ou venda)
aparece na carteira quando tem **saldo** *e* **passou pelo caixa**.

"Passou pelo caixa" é verdadeiro quando qualquer uma destas vale:

1. existe lançamento de caixa ligado ao título (recebimento parcial) — já existe;
2. existe plano de parcelas do título (`receivable_installment`) — já existe;
3. existe o marcador `fiado_at` — o caso "recebeu zero e o operador declarou".

Só o caso 3 exige estado novo. Os outros dois já deixam rastro no banco.

### Risco aceito e sua mitigação

Uma OS finalizada (`concluida` ou `entregue`) e não paga que ninguém levou ao
caixa deixa de aparecer no Fiado — dívida que ninguém cobra. Mitigação decidida: a aba Fiado ganha uma
faixa no topo contando esses títulos ("3 OS finalizadas sem acerto no caixa"),
clicável, que lista e leva ao diálogo de receber. Nada some da vista; a carteira
de fiado é que fica limpa.

## Schema — migration 0049 (aditiva, nos 3 lugares)

```sql
ALTER TABLE service_order ADD COLUMN IF NOT EXISTS fiado_at timestamptz;
ALTER TABLE sale          ADD COLUMN IF NOT EXISTS fiado_at timestamptz;
```

Refletir em `back/sql/auth-multitenant-schema.sql`,
`back/prisma/migrations/0049_fiado_declarado/migration.sql` e
`back/prisma/schema.prisma`.

### Backfill (obrigatório — sem ele dívida real some da tela)

No dia do deploy, todo título hoje visível no Fiado **sem** lançamento de caixa
desapareceria. Em produção isso inclui dívida real. Regra escolhida:

- OS com status `entregue` ou `concluida` e saldo > 0 → `fiado_at = created_at`
- venda ativa com saldo > 0 → `fiado_at = created_at`
- OS `aberta` com saldo → **fica sem marcador** e sai do Fiado (é o bug corrigido)

O backfill é idempotente (`WHERE fiado_at IS NULL`), seguro para re-execução no
baseline canônico.

## Backend

Cada módulo dono expõe a ação; o `receivables` continua **somente leitura**
("aponta, não invade"):

- `POST /os/:id/fiado` → `OsService.markFiado(user, id)`
- `POST /sale/:id/fiado` → `SaleService.markFiado(user, id)`

Ambos idempotentes (não sobrescrevem `fiado_at` já preenchido), sob
`withTenantTx`, com `@Permissions` do módulo dono e `AuditService.log`.

`ReceivablesService.openTitles` passa a exigir a condição de passagem pelo caixa.
Nova leitura para a faixa: títulos FINALIZADOS (`concluida` ou `entregue`), com
saldo, sem nenhuma das três provas de passagem. Mesmo critério do backfill —
finalizado é `concluida` ou `entregue`, em todo lugar.

## Sync offline

Duas operações novas em `sync.registry.ts`: `service_order.markFiado` e
`sale.markFiado`. Sem elas, declarar fiado offline entra na fila e o servidor
recusa o lote inteiro (400) — falha já vista neste app com
`receivable_installment`.

A coluna `fiado_at` desce sozinha no pull: o payload é a linha crua.

## Front

**`receive_title_dialog.dart`** — cai o `Validators.positiveNumber` e a trava
`valor <= 0`. O botão principal se nomeia pelo estado, sem controle novo:

| Valor digitado | Rótulo do botão | Ação |
|---|---|---|
| igual ao saldo | "Registrar" | lançamento de caixa |
| entre zero e o saldo | "Registrar e deixar o resto fiado" | lançamento de caixa |
| zero | "Deixar fiado" | `markFiado` |

No parcial não se chama `markFiado`: o próprio lançamento já é a prova de
passagem. A trava de "receber mais que o saldo" permanece.

**Venda avulsa** — o modal "Registrar como fiado?" que já existe passa a levar a
intenção junto na criação (campo `fiado` no DTO de `sale.create`), em vez de uma
segunda chamada. Assim funciona offline sem depender de duas mutações em ordem.

**Aba Fiado** — faixa no topo com a contagem de finalizadas sem acerto, clicável,
abrindo a lista e o diálogo de receber.

## Testes

Backend:
- `openTitles` nos quatro cenários: OS `aberta` fora; finalizada sem passagem fora;
  com lançamento dentro; com `fiado_at` dentro.
- `markFiado` idempotente e auditado; negado sem a permissão do módulo.
- isolamento por tenant (A não enxerga título de B).
- a leitura da faixa conta `concluida` e `entregue` sem passagem, e ignora `aberta`.

Front:
- rótulo do botão em cada um dos três estados;
- valor zero passa pela validação e chama `markFiado`;
- parcial NÃO chama `markFiado`;
- a faixa mostra a contagem certa e some quando zero.

## Fora de escopo

- Data de vencimento / aging do fiado (o módulo já assume esse limite hoje).
- Migrar o fiado para tabela própria de títulos — continua sendo o próximo passo
  se a escala passar do teto de varredura, como já registrado no service.
