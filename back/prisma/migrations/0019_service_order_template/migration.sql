-- ============================================================
-- 0019 — Templates de serviço (service_order_template + _item) — aditivo, idempotente
-- ============================================================
-- Template nomeado (ex.: "Revisão completa") + itens pré-definidos. "Aplicar" a uma
-- OS pré-preenche os itens. "Aponta, não invade": inventory_item_id é ponteiro
-- (módulo inventory); name/unit_price são snapshot. Preços DECIMAIS. RLS + FORCE.

CREATE TABLE IF NOT EXISTS service_order_template (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  name        text NOT NULL,
  description text,
  deleted_at  timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_service_order_template_tenant
  ON service_order_template(tenant_id);
CREATE INDEX IF NOT EXISTS idx_service_order_template_tenant_name
  ON service_order_template(tenant_id, name);

CREATE TABLE IF NOT EXISTS service_order_template_item (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  template_id       uuid NOT NULL REFERENCES service_order_template(id) ON DELETE CASCADE,
  kind              text NOT NULL,                 -- 'product' | 'service'
  inventory_item_id uuid,                           -- ponteiro (módulo inventory) — null = avulso
  name              text NOT NULL,                  -- snapshot
  quantity          numeric(14,3) NOT NULL DEFAULT 1,
  unit_price        numeric(14,2),
  created_at        timestamptz NOT NULL DEFAULT now()
);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'service_order_template_item_kind_chk') THEN
    ALTER TABLE service_order_template_item ADD CONSTRAINT service_order_template_item_kind_chk
      CHECK (kind IN ('product','service'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_service_order_template_item_tenant_template
  ON service_order_template_item(tenant_id, template_id);

-- RLS + FORCE + policy nas tabelas novas (idempotente).
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['service_order_template','service_order_template_item']
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

GRANT SELECT, INSERT, UPDATE, DELETE ON service_order_template TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON service_order_template_item TO app_user;
