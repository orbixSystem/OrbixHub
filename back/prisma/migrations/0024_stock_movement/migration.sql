-- back/prisma/migrations/0024_stock_movement/migration.sql
-- ============================================================
-- 0024 — Stock movement (diário de estoque) — aditivo, idempotente
-- ============================================================
-- Diário de movimentos do estoque. current_stock continua como SALDO
-- materializado; cada movimento o ajusta. Substitui a semântica do booleano
-- service_order.stock_applied (mantido por ora, deprecado). Genérico via
-- ref_type/ref_id/ref_item_id. RLS + FORCE como toda tabela tenant-scoped.

CREATE TABLE IF NOT EXISTS stock_movement (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  inventory_item_id uuid NOT NULL REFERENCES inventory_item(id) ON DELETE CASCADE,
  stock_delta       numeric(14,3) NOT NULL,        -- negativo = saída; positivo = entrada
  reason            text NOT NULL,                 -- 'os_consumption' | 'os_reversal'
  ref_type          text NOT NULL,                 -- 'service_order'
  ref_id            uuid NOT NULL,                 -- id da OS
  ref_item_id       uuid,                          -- id da service_order_item (chave da reconciliação)
  created_by        uuid,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_stock_movement_tenant
  ON stock_movement(tenant_id);
CREATE INDEX IF NOT EXISTS idx_stock_movement_item
  ON stock_movement(inventory_item_id);
CREATE INDEX IF NOT EXISTS idx_stock_movement_ref_item
  ON stock_movement(ref_item_id);
CREATE INDEX IF NOT EXISTS idx_stock_movement_ref
  ON stock_movement(ref_type, ref_id);

-- RLS + FORCE + policy (idempotente).
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['stock_movement']
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

GRANT SELECT, INSERT, UPDATE, DELETE ON stock_movement TO app_user;

-- Backfill: para OS já aplicadas (stock_applied) e ainda consumindo, insere um
-- movimento-espelho por linha-produto para que o consumo DERIVADO bata com o
-- saldo histórico. NÃO ajusta current_stock (o saldo já reflete a baixa).
-- Guardado por NOT EXISTS → idempotente em re-execução.
INSERT INTO stock_movement
  (tenant_id, inventory_item_id, stock_delta, reason, ref_type, ref_id, ref_item_id)
SELECT i.tenant_id, i.inventory_item_id, -i.quantity, 'os_consumption',
       'service_order', i.order_id, i.id
FROM service_order_item i
JOIN service_order o ON o.id = i.order_id
WHERE o.stock_applied = true
  AND o.status IN ('em_execucao','concluida','entregue')
  AND i.kind = 'product'
  AND i.inventory_item_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM stock_movement sm WHERE sm.ref_item_id = i.id
  );
