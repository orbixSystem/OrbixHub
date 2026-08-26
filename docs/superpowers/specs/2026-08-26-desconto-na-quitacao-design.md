# Desconto na quitação — design

**Data:** 2026-08-26
**Status:** aprovado (abordagem A)

## 1. Problema

Falta registrar o desconto concedido **no momento de receber**. Hoje, quando o
cliente deve R$ 100 e o operador aceita R$ 90 para fechar a conta, não há como
representar isso: ou se registra R$ 90 e a dívida fica eternamente com R$ 10 em
aberto, ou se altera o total do documento — e aí o comprovante já entregue ao
cliente deixa de bater.

**Desconto já existe no produto, mas é outro conceito.** `sale.discount`,
`service_order.discount` e `service_order_item.discount` abatem o **valor do
documento**, no momento em que ele é criado. Isto aqui é diferente: a dívida já
existe, o documento já foi emitido, e o que se perdoa é o **saldo**.

Nenhum dos módulos `cashier`, `receivables` ou `expenses` tem hoje qualquer
menção a desconto.

## 2. Decisão

O documento fica **intacto**. O desconto é atributo do **recebimento**.

Receber R$ 90 numa dívida de R$ 100 com R$ 10 de desconto grava **um**
`cash_entry` com `amount = 90` e `discount = 10`. A venda continua valendo
R$ 100; o relatório do dia mostra R$ 90 de entrada e R$ 10 de desconto
concedido, separados.

### Por que em `cash_entry`

`cash_entry` já é o ponto único por onde todo dinheiro entra:

- tem `sale_id` + `sale_kind` — cobre venda e OS;
- tem relação com `receivable_installment` — cobre fiado;
- já tem estorno (`reversed_at`, `reversed_by`, `reversal_reason`);
- o módulo `os` já consulta o caixa via `CashierService` para saldo de
  pagamento (não toca a tabela alheia — regra 1).

Uma coluna ali cobre fiado, OS e lançamento avulso de uma vez. **Estorno sai de
graça**: estornar o lançamento desfaz o desconto junto, pelo mecanismo que já
existe.

### Alternativas descartadas

**Lançamento separado de tipo `discount`** (dois `cash_entry`, um de R$ 90 e um
de R$ 10). Mais explícito na linha do tempo, mas as duas escritas precisam ser
atômicas, o replay offline precisa manter o par junto e o estorno precisa
reverter os dois — três modos de falha novos para ganhar legibilidade que a
coluna também entrega.

**Tabela `settlement_discount`.** Auditoria máxima, mas é tabela nova + RLS +
sync + repository para algo que é sempre 1:1 com um recebimento. `audit_log` já
cobre quem concedeu, quando e quanto.

## 3. Modelo de dados

Migration **0055**, aditiva, nos três lugares da regra 3
(`sql/auth-multitenant-schema.sql` + `prisma/migrations/0055_*/migration.sql` +
`schema.prisma`):

```sql
ALTER TABLE cash_entry ADD COLUMN IF NOT EXISTS discount        numeric(14,2) NOT NULL DEFAULT 0;
ALTER TABLE cash_entry ADD COLUMN IF NOT EXISTS discount_reason text;
ALTER TABLE cash_entry ADD CONSTRAINT cash_entry_discount_nonneg CHECK (discount >= 0);
```

O default `0` é a verdade sobre as linhas existentes: nenhuma teve desconto.
`cash_entry` já é tenant-scoped com RLS + FORCE (verificado no banco:
`relrowsecurity = t`, `relforcerowsecurity = t`); colunas novas herdam a policy
e o grant da tabela, então não há GRANT a acrescentar.

### A constraint que bloqueia o desconto total

`cash_entry` tem hoje `CONSTRAINT cash_entry_amount_chk CHECK (amount > 0)`.
Perdoar a dívida inteira — desconto de 100%, nada entra em dinheiro — produz
`amount = 0` e o insert **falha**. E esse é justamente o caso em que mais se
quer o registro: dívida encerrada sem um centavo entrar é a decisão mais grave
que o operador toma.

A migration 0055 troca a constraint:

```sql
ALTER TABLE cash_entry DROP CONSTRAINT IF EXISTS cash_entry_amount_chk;
ALTER TABLE cash_entry ADD  CONSTRAINT cash_entry_amount_chk
  CHECK (amount >= 0 AND (amount > 0 OR discount > 0));
```

Continua proibido o lançamento vazio (`amount = 0` sem desconto), que é erro de
operação e não significa nada. O que passa a ser possível é o lançamento cujo
valor está inteiramente no desconto.

Trocar constraint é a única parte não puramente aditiva desta migration. É
segura porque a nova é **mais permissiva** que a antiga: toda linha que passava
na velha passa na nova. Nenhum dado existente é invalidado.

Sem hard delete: desfazer um desconto é estornar o lançamento, não apagar.

## 4. Regra de quitação

É a única mudança de semântica no cálculo, e vive num lugar só — o cálculo de
saldo do `CashierService`:

| antes | depois |
|---|---|
| dívida fecha quando `Σ amount >= saldo` | dívida fecha quando `Σ (amount + discount) >= saldo` |

`sale.total` e `service_order.total` **não são tocados**. Há teste explícito
para isso (§9), porque é exatamente o que a decisão do §2 promete e o que uma
refatoração distraída quebraria primeiro.

### Alvo do desconto

O desconto abate **o saldo que está sendo quitado naquela operação**:

- pagando uma parcela → abate aquela parcela;
- quitando o título inteiro → abate o título.

A UI diz sobre o que o desconto incide, para o operador não descobrir depois.

> **Assumido, não confirmado.** A pergunta "desconto em parcela abate a parcela
> ou o título?" ficou sem resposta explícita. Esta é a generalização coerente
> com `cash_entry.discount`: o desconto pertence ao recebimento, e o recebimento
> tem um alvo. Se a regra desejada for outra (ex.: desconto sempre no título),
> muda o cálculo de saldo e a UI — reabrir antes de implementar.

## 5. Alçada e teto

- Permissão nova **`cashier.discount`**, semeada em `owner` e `gerente`
  (existem hoje `cashier.read`, `cashier.write`, `cashier.manage`).
- Teto por tenant em Configurações, registrado pelo próprio módulo `cashier` no
  `SettingsSectionRegistry`: `desconto_max_percentual` e `desconto_max_valor`.
  Vazio = sem teto. Owner sem teto por definição.
- **Validação no backend**, em `createEntry` (`cashier.service.impl.ts:418`) e
  `payInstallment` (`cashier.controller.ts:233`). Sem a permissão ou acima do
  teto → 403 com mensagem no formato padrão. Esconder o campo na UI não é
  proteger; o backend é a verdade.
- `AuditService.log` em todo desconto concedido: valor, motivo, documento.

`SettingsFieldType` hoje aceita `text | email | tel | url | color | bool |
select | image` — **não tem tipo numérico**. Teto de dinheiro como texto livre
convida erro de digitação e, no celular, o teclado errado. A spec inclui somar
`'number'` ao union e tratá-lo no renderizador de seções do front. É aditivo e
nenhum consumidor existente muda.

## 6. Offline

**Restrição derivada do código, não escolha.** Receber já funciona offline:
`enqueue(_entries, 'create')` e `enqueue(_installments, 'pay')` em
`local_first_cashier_repository.dart`. Se o desconto exigisse conexão, ele seria
a única operação de dinheiro que não funciona offline — regressão no fluxo que
já existe.

`discount` e `discount_reason` entram nos payloads que já estão na fila. Nenhum
verbo novo no outbox, nenhuma tabela local nova, nenhuma mudança no
`rowIdOfPayload`.

O teto é revalidado no servidor durante o replay. Desconto que exceda faz a
mutação falhar e aparecer no painel de pendências, como qualquer outra rejeição
— o cliente offline não é autoridade sobre alçada.

## 7. Front

Campo **Desconto** no modal de receber fiado (título e parcela) e no de receber
OS, com o saldo recalculando ao vivo:

```
Saldo ............ R$ 100,00
Desconto ......... R$  10,00
A receber ........ R$  90,00
```

- Só aparece para quem tem `cashier.discount` (lido de `me.permissions`, runtime
  — nunca hardcoded).
- Motivo opcional, texto curto.
- 403 do backend tratado com elegância, não com stack trace.
- Acesso via repository (interface no domain), models freezed, estado selado.

**Fora de escopo, por decisão:**

- **Venda avulsa no ato** mantém o `sale.discount` que já existe. A venda está
  sendo criada agora; reduzir o total é o comportamento certo e o comprovante
  nasce coerente. Dois campos de desconto na mesma tela confundiriam.
- **Lançamento avulso do caixa** sem documento por trás não tem saldo de que
  descontar — `amount` já é o que entrou. O campo só aparece quando o lançamento
  quita algo (`sale_id` preenchido ou parcela vinculada).

## 8. Relatórios e comprovante

`SUM(discount)` separado de `SUM(amount)`: "entrou R$ X, abriu mão de R$ Y".
Sem isso o desconto vira buraco invisível no fechamento — a conta fecha e
ninguém sabe por quê.

No comprovante, linha de desconto explícita, para o cliente entender por que a
dívida fechou com menos do que devia.

## 9. Testes

| o quê | por quê |
|---|---|
| isolamento de tenant | regra não-negociável; tenant A não vê desconto de B |
| quitação com `amount + discount` | é a mudança de semântica do §4 |
| **`sale.total` não muda** | é a promessa central do §2 |
| recusa sem `cashier.discount` | alçada é backend, não UI |
| recusa acima do teto (% e valor) | idem |
| estorno reverte o desconto junto | o "de graça" do §2 precisa ser verificado, não presumido |
| replay offline idempotente | desconto não pode duplicar ao reenviar |
| desconto > saldo | deve ser recusado, não gerar saldo negativo |
| desconto de 100% (`amount = 0`) | é o caso que a constraint antiga barrava |
| lançamento vazio (`amount = 0`, `discount = 0`) | continua recusado pelo banco |

## 10. Ordem de construção

1. Migration 0055 nos três lugares + `prisma generate`.
2. Permissão `cashier.discount` no seed + cargos.
3. Backend: DTO, validação de alçada/teto, cálculo de saldo, auditoria.
4. `'number'` no `SettingsFieldType` + seção de config do caixa.
5. Front: repository → notifier → campo nos dois modais.
6. Offline: campos nos payloads existentes.
7. Relatório e comprovante.

Backend antes do front, porque a alçada mora lá e o front só reflete.
