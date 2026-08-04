-- ============================================================
-- 0042 — Origem 'expense' nos lançamentos de despesa ANTIGOS — aditivo, idempotente
-- ============================================================
-- A 0040 fez a baixa gravar `sale_kind='expense'` + `sale_id` no lançamento, o que
-- criou o caminho caixa → despesa. Só que isso vale para as baixas NOVAS: toda
-- conta paga antes continuava com origem nula, e clicar nela no extrato não fazia
-- nada — a metade do histórico ficaria clicável e a outra não, sem nenhuma razão
-- visível para o usuário.
--
-- O dado para consertar já existe: `expense.cash_entry_id` guarda o vínculo desde
-- sempre, só no sentido oposto. Este backfill escreve a volta.
UPDATE cash_entry ce
   SET sale_kind = 'expense',
       sale_id   = e.id
  FROM expense e
 WHERE e.cash_entry_id = ce.id
   -- Só onde está NULO: nunca sobrescreve origem existente ('os', 'sale'). Se um
   -- lançamento já aponta para outra coisa, ele não é nosso para mexer.
   AND ce.sale_kind IS NULL
   -- Coerência de tenant, mesmo com a FK garantindo: escrita entre tabelas de
   -- módulos diferentes é o lugar onde um erro atravessaria a fronteira do tenant.
   AND ce.tenant_id = e.tenant_id;
