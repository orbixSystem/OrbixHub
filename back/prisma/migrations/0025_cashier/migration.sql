-- back/prisma/migrations/0025_cashier/migration.sql
-- ============================================================
-- 0025 — Módulo `cashier` (Caixa) — aditivo, idempotente
-- ============================================================
-- Registrador de dinheiro + livro caixa. `cash_session` = sessão do dia (abre/fecha
-- com expected×counted×difference; 1 aberta por tenant via índice parcial). `cash_entry`
-- = lançamentos (entradas/saídas). Um recebimento APONTA para a venda via
-- (sale_kind, sale_id) e lê o total pelo service da venda — "aponta, não invade"
-- (nunca toca service_order). Estorno é LÓGICO (reversed_at), nunca hard delete.
-- RLS + FORCE como toda tabela tenant-scoped.

CREATE TABLE IF NOT EXISTS cash_session (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id               uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  opened_by               uuid NOT NULL,
  opened_at               timestamptz NOT NULL DEFAULT now(),
  opening_amount          numeric(14,2) NOT NULL DEFAULT 0,
  closed_by               uuid,
  closed_at               timestamptz,
  closing_amount_counted  numeric(14,2),
  closing_amount_expected numeric(14,2),
  difference              numeric(14,2),
  status                  text NOT NULL DEFAULT 'open',
  notes                   text,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT cash_session_status_chk CHECK (status IN ('open','closed'))
);

CREATE INDEX IF NOT EXISTS idx_cash_session_tenant ON cash_session(tenant_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_cash_session_one_open
  ON cash_session(tenant_id) WHERE status = 'open';

CREATE TABLE IF NOT EXISTS cash_entry (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  cash_session_id uuid NOT NULL REFERENCES cash_session(id) ON DELETE CASCADE,
  direction       text NOT NULL,
  amount          numeric(14,2) NOT NULL,
  method          text NOT NULL,
  category        text NOT NULL,
  sale_kind       text,
  sale_id         uuid,
  description     text,
  reversed_at     timestamptz,
  reversed_by     uuid,
  reversal_reason text,
  created_by      uuid NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT cash_entry_direction_chk CHECK (direction IN ('in','out')),
  CONSTRAINT cash_entry_amount_chk    CHECK (amount > 0),
  CONSTRAINT cash_entry_method_chk    CHECK (method IN ('pix','dinheiro','cartao_credito','cartao_debito','outro')),
  CONSTRAINT cash_entry_category_chk  CHECK (category IN ('os_payment','venda_avulsa','despesa','sangria','suprimento')),
  CONSTRAINT cash_entry_sale_kind_chk CHECK (sale_kind IS NULL OR sale_kind IN ('os','sale'))
);

CREATE INDEX IF NOT EXISTS idx_cash_entry_tenant_session  ON cash_entry(tenant_id, cash_session_id);
CREATE INDEX IF NOT EXISTS idx_cash_entry_tenant_sale     ON cash_entry(tenant_id, sale_kind, sale_id);
CREATE INDEX IF NOT EXISTS idx_cash_entry_tenant_created  ON cash_entry(tenant_id, created_at);
CREATE INDEX IF NOT EXISTS idx_cash_entry_tenant_category ON cash_entry(tenant_id, category);
CREATE INDEX IF NOT EXISTS idx_cash_entry_tenant_method   ON cash_entry(tenant_id, method);

-- RLS + FORCE + policy (idempotente).
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['cash_session','cash_entry']
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY;', t);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY;', t);
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = t AND policyname = 'tenant_isolation') THEN
      EXECUTE format($f$
        CREATE POLICY tenant_isolation ON %I
        USING (tenant_id = current_tenant_id())
        WITH CHECK (tenant_id = current_tenant_id());
      $f$, t);
    END IF;
  END LOOP;
END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON cash_session TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON cash_entry   TO app_user;

-- Módulo contratado `cashier` — habilitado em trial + pro. is_core=false.
INSERT INTO module (key, name, is_core) VALUES
  ('cashier','Caixa', false)
ON CONFLICT (key) DO NOTHING;

INSERT INTO plan_module (plan_id, module_id)
SELECT pl.id, m.id FROM plan pl JOIN module m ON m.key = 'cashier'
WHERE pl.key IN ('trial','pro')
ON CONFLICT DO NOTHING;

INSERT INTO tenant_module (tenant_id, module_id, enabled, source)
SELECT t.id, m.id, true, 'plan'
FROM tenant t CROSS JOIN module m
WHERE m.key = 'cashier'
ON CONFLICT (tenant_id, module_id) DO NOTHING;
