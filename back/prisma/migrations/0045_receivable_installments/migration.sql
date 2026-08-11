-- back/prisma/migrations/0045_receivable_installments/migration.sql
-- ============================================================
-- 0045 — Parcelamento de fiado (receivable_installment)
-- ============================================================
-- Permite registrar um plano de parcelas para uma venda/OS em fiado.
-- Cada linha = uma parcela com vencimento. Quando quitada, recebe
-- `paid_at` + `entry_id` (aponta para o cash_entry correspondente).
-- Independente: aponta por id para venda/OS, nunca toca a tabela delas.

CREATE TABLE IF NOT EXISTS receivable_installment (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  sale_kind   text NOT NULL,
  sale_id     uuid NOT NULL,
  amount      numeric(14,2) NOT NULL CHECK (amount > 0),
  due_date    date NOT NULL,
  paid_at     timestamptz,
  entry_id    uuid REFERENCES cash_entry(id) ON DELETE SET NULL,
  notes       text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ri_sale_kind_chk CHECK (sale_kind IN ('os','sale'))
);

CREATE INDEX IF NOT EXISTS idx_ri_tenant_sale   ON receivable_installment(tenant_id, sale_kind, sale_id);
CREATE INDEX IF NOT EXISTS idx_ri_tenant_due    ON receivable_installment(tenant_id, due_date) WHERE paid_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_ri_tenant_status ON receivable_installment(tenant_id, paid_at);

ALTER TABLE receivable_installment ENABLE ROW LEVEL SECURITY;
ALTER TABLE receivable_installment FORCE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'receivable_installment' AND policyname = 'tenant_isolation'
  ) THEN
    CREATE POLICY tenant_isolation ON receivable_installment
    USING (tenant_id = current_tenant_id())
    WITH CHECK (tenant_id = current_tenant_id());
  END IF;
END $$;

GRANT SELECT, INSERT, UPDATE ON receivable_installment TO app_user;
