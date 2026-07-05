-- 0029 — Módulo `sales` (venda avulsa de produto / caixa). Aditivo.
-- Venda direta ao cliente (fora da OS de serviço). Baixa estoque via o seam
-- público do inventory (reconcileConsumption, ref_type='sale'). "Aponta não
-- invade": guarda só customer_id / inventory_item_id + snapshots.

CREATE TABLE IF NOT EXISTS sale (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      uuid        NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  number         text        NOT NULL,
  customer_id    uuid,
  customer_name  text,
  status         text        NOT NULL DEFAULT 'concluida'
                   CHECK (status IN ('concluida','cancelada')),
  payment_method text        NOT NULL DEFAULT 'dinheiro'
                   CHECK (payment_method IN ('dinheiro','cartao','pix','outro')),
  discount       numeric(14,2) NOT NULL DEFAULT 0,
  subtotal       numeric(14,2) NOT NULL DEFAULT 0,
  total          numeric(14,2) NOT NULL DEFAULT 0,
  stock_applied  boolean     NOT NULL DEFAULT false,
  sold_by        uuid,
  canceled_at    timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='sale' AND policyname='tenant_isolation') THEN
    ALTER TABLE sale ENABLE ROW LEVEL SECURITY;
    ALTER TABLE sale FORCE ROW LEVEL SECURITY;
    CREATE POLICY tenant_isolation ON sale USING (tenant_id = current_tenant_id());
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_sale_tenant_number ON sale (tenant_id, number);
CREATE INDEX IF NOT EXISTS idx_sale_tenant_created ON sale (tenant_id, created_at);
CREATE INDEX IF NOT EXISTS idx_sale_tenant_customer ON sale (tenant_id, customer_id);
CREATE INDEX IF NOT EXISTS idx_sale_tenant_status ON sale (tenant_id, status);
GRANT SELECT, INSERT, UPDATE, DELETE ON sale TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON sale TO app_migrator;

CREATE TABLE IF NOT EXISTS sale_item (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         uuid        NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  sale_id           uuid        NOT NULL REFERENCES sale(id) ON DELETE CASCADE,
  inventory_item_id uuid,
  kind              text        NOT NULL DEFAULT 'product'
                      CHECK (kind IN ('product','service')),
  name              text        NOT NULL,
  quantity          numeric(14,3) NOT NULL DEFAULT 1,
  unit_price        numeric(14,2) NOT NULL DEFAULT 0,
  discount          numeric(14,2) NOT NULL DEFAULT 0,
  total             numeric(14,2) NOT NULL DEFAULT 0,
  created_at        timestamptz NOT NULL DEFAULT now()
);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='sale_item' AND policyname='tenant_isolation') THEN
    ALTER TABLE sale_item ENABLE ROW LEVEL SECURITY;
    ALTER TABLE sale_item FORCE ROW LEVEL SECURITY;
    CREATE POLICY tenant_isolation ON sale_item USING (tenant_id = current_tenant_id());
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_sale_item_tenant_sale ON sale_item (tenant_id, sale_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON sale_item TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON sale_item TO app_migrator;

-- Seeds: módulo contratável + planos + permissões (caixa já tem cashier.*;
-- owner/gerente ganham gestão) + backfill dos tenants existentes.
INSERT INTO module (key, name, is_core) VALUES ('sales','Vendas', false)
ON CONFLICT (key) DO NOTHING;

INSERT INTO plan_module (plan_id, module_id)
SELECT pl.id, m.id FROM plan pl JOIN module m ON m.key = 'sales'
WHERE pl.key IN ('trial','pro')
ON CONFLICT DO NOTHING;

INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON p.key IN ('cashier.read','cashier.write')
WHERE r.key IN ('owner','gerente')
ON CONFLICT DO NOTHING;

INSERT INTO tenant_module (tenant_id, module_id, enabled, source)
SELECT t.id, m.id, true, 'plan'
FROM tenant t CROSS JOIN module m
WHERE m.key = 'sales'
ON CONFLICT (tenant_id, module_id) DO NOTHING;
