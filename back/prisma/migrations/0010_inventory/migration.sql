-- ============================================================
-- 0010 — Inventory (Produtos) — aditivo, idempotente
-- ============================================================
-- Catálogo de PRODUTOS (uma única tabela). Genérico/multi-vertical.
-- Sem kind/serviço (serviço é o módulo 3), sem inventory_movement
-- (estoque ajustado direto em current_stock). Preços DECIMAIS.
-- Campos da vertical vivem em attributes (jsonb) + itemFields (config).
-- RLS + FORCE como toda tabela tenant-scoped.

CREATE TABLE IF NOT EXISTS inventory_item (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  name              text NOT NULL,
  sku               text,
  manufacturer_code text,
  barcode           text,
  category          text,
  brand             text,
  unit              text,
  sale_price        numeric(14,2),
  cost_price        numeric(14,2),
  margin_pct        numeric(7,2),
  current_stock     numeric(14,3) NOT NULL DEFAULT 0,
  min_stock         numeric(14,3),
  attributes        jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_active         boolean NOT NULL DEFAULT true,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inventory_item_tenant_barcode
  ON inventory_item(tenant_id, barcode);
CREATE INDEX IF NOT EXISTS idx_inventory_item_tenant_mfrcode
  ON inventory_item(tenant_id, manufacturer_code);
CREATE INDEX IF NOT EXISTS idx_inventory_item_tenant_sku
  ON inventory_item(tenant_id, sku);
CREATE UNIQUE INDEX IF NOT EXISTS uq_inventory_item_tenant_barcode
  ON inventory_item(tenant_id, barcode) WHERE barcode IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_inventory_item_tenant_sku
  ON inventory_item(tenant_id, sku) WHERE sku IS NOT NULL;

-- RLS + FORCE + policy na tabela nova (idempotente).
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['inventory_item']
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

GRANT SELECT, INSERT, UPDATE, DELETE ON inventory_item TO app_user;

-- inventory passa a fazer parte do plano trial (além do pro, que já tem tudo).
INSERT INTO plan_module (plan_id, module_id)
SELECT pl.id, m.id FROM plan pl JOIN module m ON m.key = 'inventory'
WHERE pl.key = 'trial'
ON CONFLICT DO NOTHING;
