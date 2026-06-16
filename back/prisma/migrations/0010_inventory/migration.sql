-- ============================================================
-- 0010 — Inventory (Estoque & Serviços) — aditivo, idempotente
-- ============================================================
-- Catálogo de itens (produto/serviço) + movimentações de estoque.
-- Genérico/multi-vertical. RLS + FORCE como toda tabela tenant-scoped.
-- Preços em centavos (int); quantidades numeric(14,3).

CREATE TABLE IF NOT EXISTS inventory_item (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  kind             text NOT NULL,                       -- 'product' | 'service'
  name             text NOT NULL,
  code             text,
  barcode          text,
  category         text,
  unit             text NOT NULL DEFAULT 'un',
  sale_price_cents integer NOT NULL DEFAULT 0,
  cost_price_cents integer,
  margin_percent   numeric(7,2),
  sellable         boolean NOT NULL DEFAULT true,
  track_stock      boolean NOT NULL DEFAULT true,
  stock_qty        numeric(14,3) NOT NULL DEFAULT 0,
  min_qty          numeric(14,3),
  duration_minutes integer,
  brand            text,
  status           text NOT NULL DEFAULT 'active',      -- 'active' | 'archived'
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'inventory_item_kind_chk') THEN
    ALTER TABLE inventory_item ADD CONSTRAINT inventory_item_kind_chk CHECK (kind IN ('product','service'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'inventory_item_status_chk') THEN
    ALTER TABLE inventory_item ADD CONSTRAINT inventory_item_status_chk CHECK (status IN ('active','archived'));
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_inventory_item_tenant_kind ON inventory_item(tenant_id, kind);
CREATE INDEX IF NOT EXISTS idx_inventory_item_tenant_status ON inventory_item(tenant_id, status);
CREATE UNIQUE INDEX IF NOT EXISTS uq_inventory_item_tenant_code
  ON inventory_item(tenant_id, code) WHERE code IS NOT NULL;

CREATE TABLE IF NOT EXISTS inventory_movement (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  item_id       uuid NOT NULL REFERENCES inventory_item(id) ON DELETE CASCADE,
  type          text NOT NULL,                          -- 'in' | 'out' | 'adjust'
  quantity      numeric(14,3) NOT NULL,
  balance_after numeric(14,3) NOT NULL,
  reason        text,
  ref_type      text,
  ref_id        uuid,
  note          text,
  created_by    uuid,
  created_at    timestamptz NOT NULL DEFAULT now()
);
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'inventory_movement_type_chk') THEN
    ALTER TABLE inventory_movement ADD CONSTRAINT inventory_movement_type_chk CHECK (type IN ('in','out','adjust'));
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_inventory_movement_tenant_item
  ON inventory_movement(tenant_id, item_id, created_at DESC);

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['inventory_item','inventory_movement']
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
GRANT SELECT, INSERT, UPDATE, DELETE ON inventory_movement TO app_user;

-- inventory passa a fazer parte do plano trial (além do pro, que já tem tudo).
INSERT INTO plan_module (plan_id, module_id)
SELECT pl.id, m.id FROM plan pl JOIN module m ON m.key = 'inventory'
WHERE pl.key = 'trial'
ON CONFLICT DO NOTHING;
