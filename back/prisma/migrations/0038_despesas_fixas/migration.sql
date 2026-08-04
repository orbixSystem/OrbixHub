-- ============================================================
-- 0038 — Despesas fixas (modelos de lançamento) — aditivo, idempotente
-- ============================================================
-- Modelo de despesa recorrente: nome + valor, para lançar no caixa em um toque.
-- É PRESET, não agendador: nada entra no livro caixa sem alguém confirmar — valor
-- que aparece sozinho é valor que ninguém reconhece na conferência.
--
-- Tabela própria (e não um array em `tenant_module.settings['cashier']`) porque o
-- app é offline-first: jsonb sincroniza como UM blob, então dois aparelhos
-- cadastrando modelos offline perderiam um dos dois no LWW. Linha sincroniza por
-- linha. De lambuja: CHECK, unique de nome e índice para o pull.
CREATE TABLE IF NOT EXISTS cash_expense_template (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  name        text NOT NULL,
  -- 0 = "o valor varia" (ex.: conta de luz): o atalho preenche só o nome e deixa
  -- o valor para digitar. Evita um segundo conceito de "modelo sem valor".
  amount      numeric(14,2) NOT NULL DEFAULT 0,
  category    text NOT NULL DEFAULT 'despesa',
  -- Forma sugerida; NULL = não opinar e usar o default do caixa.
  method      text,
  status      text NOT NULL DEFAULT 'active',
  created_by  uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT cash_expense_template_name_chk     CHECK (length(btrim(name)) > 0),
  CONSTRAINT cash_expense_template_amount_chk   CHECK (amount >= 0),
  -- Só saídas: o atalho existe para despesa/sangria. Recebimento nasce de OS ou
  -- venda, nunca de um modelo solto.
  CONSTRAINT cash_expense_template_category_chk CHECK (category IN ('despesa','sangria')),
  CONSTRAINT cash_expense_template_method_chk   CHECK (method IS NULL OR method IN ('pix','dinheiro','cartao_credito','cartao_debito','outro')),
  CONSTRAINT cash_expense_template_status_chk   CHECK (status IN ('active','disabled'))
);

-- Sem hard delete (regra 6): desativar preserva o histórico de quem lançou o quê.
-- O unique vale só entre os ativos — assim "Aluguel" pode ser recriado depois de
-- desativado sem colidir com o antigo.
CREATE UNIQUE INDEX IF NOT EXISTS uq_cash_expense_template_name
  ON cash_expense_template (tenant_id, lower(btrim(name)))
  WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_cash_expense_template_tenant_status
  ON cash_expense_template(tenant_id, status);
-- Pull incremental do sync (offline) varre por updated_at.
CREATE INDEX IF NOT EXISTS idx_cash_expense_template_tenant_updated
  ON cash_expense_template(tenant_id, updated_at);

-- RLS + FORCE + policy (idempotente).
DO $$
BEGIN
  ALTER TABLE cash_expense_template ENABLE ROW LEVEL SECURITY;
  ALTER TABLE cash_expense_template FORCE ROW LEVEL SECURITY;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'cash_expense_template' AND policyname = 'tenant_isolation'
  ) THEN
    CREATE POLICY tenant_isolation ON cash_expense_template
      USING (tenant_id = current_tenant_id())
      WITH CHECK (tenant_id = current_tenant_id());
  END IF;
END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON cash_expense_template TO app_user;
