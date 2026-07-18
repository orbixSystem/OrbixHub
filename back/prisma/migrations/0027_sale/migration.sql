-- back/prisma/migrations/0027_sale/migration.sql
-- ============================================================
-- 0027 — Módulo `sale` (Venda avulsa / Balcão) — aditivo, idempotente
-- ============================================================
-- Venda de balcão como entidade PRÓPRIA (não é OS). `sale` = cabeçalho (cliente
-- OPCIONAL — balcão pode ser sem cadastro; total; fiscal_status snapshot). `sale_item`
-- = linhas (snapshot do item de estoque). A baixa de estoque é via InventoryService
-- ("aponta, não invade"); o pagamento é DERIVADO do Caixa (a venda não guarda valor
-- pago); a nota é disparada via InvoiceService (Fiscal é dono do status). Cancelamento
-- é LÓGICO (status='canceled'), nunca hard delete. RLS + FORCE como toda tabela
-- tenant-scoped. Permissões sale.read/sale.write semeadas e mapeadas (owner/gerente/caixa).

CREATE TABLE IF NOT EXISTS sale (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  number             text NOT NULL,                  -- ex.: 'VND-0001' (único por tenant)
  customer_id        uuid,                            -- ponteiro (customers) — NULLABLE (balcão s/ cadastro)
  customer_name      text,                            -- snapshot (nullable)
  status             text NOT NULL DEFAULT 'active',  -- 'active' | 'canceled'
  total              numeric(14,2) NOT NULL DEFAULT 0,
  fiscal_status      text,                            -- snapshot do status fiscal (Fiscal é dono)
  fiscal_external_id text,
  fiscal_emitted_at  timestamptz,
  created_by         uuid,
  canceled_by        uuid,
  canceled_at        timestamptz,                     -- estorno lógico (nunca hard delete)
  canceled_reason    text,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT sale_status_chk CHECK (status IN ('active','canceled')),
  CONSTRAINT sale_fiscal_status_chk
    CHECK (fiscal_status IS NULL OR fiscal_status IN ('nao_emitida','processando','emitida','rejeitada'))
);

CREATE INDEX IF NOT EXISTS idx_sale_tenant_status   ON sale(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_sale_tenant_customer ON sale(tenant_id, customer_id);
CREATE INDEX IF NOT EXISTS idx_sale_tenant_created  ON sale(tenant_id, created_at);
CREATE UNIQUE INDEX IF NOT EXISTS uq_sale_tenant_number ON sale(tenant_id, number);

CREATE TABLE IF NOT EXISTS sale_item (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  sale_id           uuid NOT NULL REFERENCES sale(id) ON DELETE CASCADE,
  kind              text NOT NULL,                 -- 'product' | 'service'
  inventory_item_id uuid,                           -- ponteiro (inventory) — null = avulso
  name              text NOT NULL,                  -- snapshot
  quantity          numeric(14,3) NOT NULL DEFAULT 1,
  unit_price        numeric(14,2) NOT NULL DEFAULT 0,
  subtotal          numeric(14,2) NOT NULL DEFAULT 0,
  created_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT sale_item_kind_chk CHECK (kind IN ('product','service'))
);

CREATE INDEX IF NOT EXISTS idx_sale_item_tenant_sale ON sale_item(tenant_id, sale_id);

-- RLS + FORCE + policy (idempotente).
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['sale','sale_item']
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

GRANT SELECT, INSERT, UPDATE, DELETE ON sale      TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON sale_item TO app_user;

-- Permissões do módulo (catálogo global) + mapeamento nos cargos.
INSERT INTO permission (key, name) VALUES
  ('sale.read','Ver vendas'), ('sale.write','Registrar vendas')
ON CONFLICT (key) DO NOTHING;

-- owner: re-grant garante que ganhe as permissões novas também.
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r, permission p WHERE r.key = 'owner'
ON CONFLICT DO NOTHING;

-- gerente: todas, exceto billing.manage.
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r, permission p
WHERE r.key = 'gerente' AND p.key <> 'billing.manage'
ON CONFLICT DO NOTHING;

-- caixa: vendas (operador do balcão).
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON p.key IN ('sale.read','sale.write')
WHERE r.key = 'caixa'
ON CONFLICT DO NOTHING;

-- Módulo contratado `sale` — habilitado em trial + pro (como cashier/report). is_core=false.
INSERT INTO module (key, name, is_core) VALUES
  ('sale','Vendas', false)
ON CONFLICT (key) DO NOTHING;

INSERT INTO plan_module (plan_id, module_id)
SELECT pl.id, m.id FROM plan pl JOIN module m ON m.key = 'sale'
WHERE pl.key IN ('trial','pro')
ON CONFLICT DO NOTHING;

-- Backfill: todo tenant existente ganha o módulo `sale` habilitado (source 'plan').
INSERT INTO tenant_module (tenant_id, module_id, enabled, source)
SELECT t.id, m.id, true, 'plan'
FROM tenant t CROSS JOIN module m
WHERE m.key = 'sale'
ON CONFLICT (tenant_id, module_id) DO NOTHING;
