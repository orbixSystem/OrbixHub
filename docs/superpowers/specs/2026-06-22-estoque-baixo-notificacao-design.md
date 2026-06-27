# Notificação de estoque baixo — Design

> Data: 2026-06-22 · Branch alvo: `feat/config-empresa-tema` (ou nova `feat/estoque-baixo-notificacao`)
> Módulos tocados: `inventory` (backend) · `notifications` (consumido, não alterado) · front `notifications` (polimento)

## 1. Objetivo

Quando um produto cruza para **estoque baixo** (`current_stock <= min_stock`), criar uma
**notificação tenant-wide** avisando que aquele produto está com o estoque baixo. O staff vê
o aviso na sininha do app (sistema de notificações que já existe).

## 2. Contexto (estado atual — código é a verdade)

- **Sistema de notificações já existe e é genérico/tenant-wide.** `NotificationsService.notify(tenantId, { type, title, body, refType, refId })` cria a notificação; o módulo é `@Global`, então qualquer módulo injeta o service e chama `notify(...)` ("aponta, não invade" — ninguém toca a tabela `notification`). O `messages` já usa esse padrão.
- **O estoque já tem o conceito de "baixo".** `inventory_item` tem `current_stock` e `min_stock` (nullable). O repositório e o endpoint `lowStock` já filtram por `min_stock != null && current_stock <= min_stock`.
- **Onde o saldo cai:**
  - `InventoryService.decrementStock(tenantId, id, qty)` — baixa programática.
  - `InventoryService.updateItem(user, id, dto)` — ajuste manual do saldo na tela.
- **Quando a OS baixa estoque:** ao entrar em `em_execucao`, a OS chama `applyStock` → `inventory.decrementStock` por item-produto, idempotente via `stock_applied`, best-effort, fora de transação. Logo, o aviso de estoque baixo sairá **no início da execução do serviço**, item por item.

## 3. Decisões de produto (confirmadas)

1. **Gatilho: só na virada.** Notifica apenas quando o produto CRUZA de saldo OK para baixo
   (`!wasLow && isLow`). Não repete enquanto seguir baixo. Reabastecer acima do mínimo e baixar
   de novo **rearma** o aviso. Sem flag de estado persistida — a virada é derivada de antes/depois.
2. **Origem: consumo + ajuste manual.** Dispara tanto no `decrementStock` (consumo pela OS)
   quanto no `updateItem` (edição manual do saldo ou do próprio mínimo na tela de estoque).
3. **"Baixo" exige `min_stock` definido (Opção A).** Produto sem `min_stock` **nunca** dispara.
   Quem quer ser avisado configura o mínimo do produto. Previsível e simples.
4. **Só `kind === 'product'`.** Serviço não controla estoque.

## 4. Lógica da virada

Para uma operação que leva o saldo de `prevStock` para `nextStock`, com mínimo `min`:

```
wasLow = (min != null) && (prevStock <= min)
isLow  = (min != null) && (nextStock <= min)
disparar  ⟺  !wasLow && isLow   &&  kind === 'product'
```

- **`decrementStock`:** `prevStock = item.current_stock` (antes do ajuste), `nextStock = next`,
  `min = item.min_stock`. (O mínimo não muda nesta operação, então a virada depende só do saldo.)
- **`updateItem`:** o "antes" usa `existing.current_stock` / `existing.min_stock`; o "depois" usa
  os **valores efetivos** após o update — `nextStock = dto.currentStock ?? existing.current_stock`,
  `min = dto.minStock ?? existing.min_stock`. Assim cobre quem edita o saldo **ou** o mínimo
  (ex.: subir o mínimo acima do saldo atual também é uma virada para baixo).

### Comportamento via OS
A transição `→ em_execucao` baixa vários itens em sequência (`applyStock`). Cada produto que
cruzar o mínimo gera **sua própria** notificação — N produtos em virada = N notificações
(correto: são produtos diferentes). Cada produto avisa no máximo 1x por cruzamento.

## 5. Implementação — backend

### 5.1 `InventoryService` injeta `NotificationsService`
`NotificationsModule` é `@Global`, então basta adicionar `NotificationsService` ao construtor do
`InventoryService` — sem alterar `InventoryModule.imports`.

### 5.2 Helper privado
```ts
private async notifyLowStockCrossing(
  tenantId: string,
  item: { id: string; name: string; unit: string | null },
  nextStock: number,
  min: number,
): Promise<void> {
  const unidade = item.unit?.trim() ? ` ${item.unit.trim()}` : '';
  await this.notifications.notify(tenantId, {
    type: 'inventory_low_stock',
    title: `Estoque baixo: ${item.name}`,
    body: `Restam ${nextStock}${unidade} (mínimo ${min})`,
    refType: 'inventory_item',
    refId: item.id,
  });
}
```
Chamado **fora** da `withTenantTx`/`runWithTenant` (o `notify` abre a própria tx via
`runWithTenant`; aninhar transações esgota o pool — mesmo padrão do `messages`).
**Best-effort:** uma falha ao notificar **não** quebra a baixa de estoque (try/catch + log de aviso),
espelhando o `applyStock` da OS. Em particular, no `decrementStock` o saldo já foi persistido na tx
antes da chamada de notificação.

### 5.3 `decrementStock`
Após a tx que persiste `next`, computar a virada com `prevStock = current_stock` lido no início e
`min = min_stock`; se cruzou, chamar o helper. Retornar o item como hoje.

### 5.4 `updateItem`
A tx retorna o item atualizado. Computar `wasLow` a partir do `existing` (já lido dentro da tx) e
`isLow` a partir dos valores efetivos. Se `!wasLow && isLow`, chamar o helper depois da tx
(o `audit.log` já roda fora da tx ali — manter a mesma ordem). Guardar `existing.current_stock`,
`existing.min_stock`, `kind` num escopo acessível após a tx.

### 5.5 Onde NÃO dispara
`incrementStock` (entrada de estoque) nunca dispara. `createItem` não dispara (criar um item já
abaixo do mínimo não é uma "virada" causada por consumo; fora de escopo — pode ser reavaliado).

## 6. Implementação — front (polimento)

`front/lib/features/notifications/presentation/notifications_bell.dart`:
- Ícone próprio para `type == 'inventory_low_stock'` (ex.: `Icons.inventory_2_outlined`) no avatar
  da linha (`_NotificationRow`) — hoje só `message` tem ícone dedicado; demais usam o sino genérico.
- No tap (`_onTapItem`): se `type == 'inventory_low_stock'`, navegar para `/m/inventory`
  (rota real da tela de estoque — ver `app_router.dart`) em vez de não fazer nada.
  O ícone `Icons.inventory_2_outlined` já é o do item de menu "Estoque" (`nav_items.dart`) — manter consistente.

**Limite honesto:** o **toast + som em tempo real** hoje só dispara via WebSocket de mensagens
(`RealtimeChat`). A notificação de estoque vai aparecer na próxima atualização da sininha (ao abrir
o painel, ou quando o não-lido recarregar), **não** como pop instantâneo. Emitir evento realtime
para estoque está **fora deste escopo**.

## 7. Sem mudança de schema

Reusa a tabela `notification` (já existe, RLS+FORCE). Nenhuma migration. Nenhum novo endpoint.

## 8. Testes

**Backend — unit (`InventoryService`, mock do `NotificationsService`):**
- Virada por `decrementStock` (saldo cai de > min para <= min) → `notify` chamado 1x com o payload certo.
- Baixar de novo um item já-baixo → `notify` **não** chamado.
- Produto **sem** `min_stock` → nunca chama `notify` (Opção A).
- `kind === 'service'` → nunca chama (já barrado antes por "Serviço não controla estoque").
- `updateItem` editando o saldo cruzando o mínimo → chama 1x.
- `updateItem` **subindo o mínimo** acima do saldo atual → chama 1x (virada pelo mínimo).
- Rearmar: baixo → reabastece acima do mínimo (`incrementStock`/update) → baixa de novo → chama de novo.
- Falha no `notify` não propaga (decrement conclui normalmente).

**Backend — e2e:**
- OS entra em `em_execucao` consumindo um produto com `min_stock` definido e cruzando o mínimo →
  `GET /notifications` mostra a notificação `inventory_low_stock`.
- Isolamento de tenant: A não vê a notificação de B.

**Front:**
- `flutter analyze` 0 issues; render do `_NotificationRow` com `type == 'inventory_low_stock'`
  mostra o ícone de estoque (widget test leve, se couber no padrão existente).

## 9. Evidência antes de "pronto"

`npm run back:lint` (0 warnings) + `back:test` + `back:test:e2e`; `flutter analyze` (0 issues) +
`flutter test`. Citar o output real (regra de ouro 11 da skill de arquitetura).
