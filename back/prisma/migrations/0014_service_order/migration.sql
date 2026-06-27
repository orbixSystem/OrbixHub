-- ============================================================
-- 0014 — Ordens de Serviço (service_order + service_order_item) — aditivo, idempotente
-- ============================================================
-- Cabeçalho da OS + itens (produtos do estoque / serviços / avulsos). Genérico:
-- "veículo" vem do subject (módulo customers) — só guardamos id + snapshot.
-- "Aponta, não invade": customer_id/subject_id/inventory_item_id são ponteiros;
-- nomes/preços são snapshot no momento. Preços DECIMAIS. RLS + FORCE.

CREATE TABLE IF NOT EXISTS service_order (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  number          text NOT NULL,                  -- ex.: 'OS-0001' (único por tenant)
  customer_id     uuid NOT NULL,                  -- ponteiro (módulo customers)
  customer_name   text NOT NULL,                  -- snapshot
  subject_id      uuid,                            -- ponteiro (subject/veículo) — nullable
  subject_label   text,                            -- snapshot
  status          text NOT NULL DEFAULT 'aberta',
  assigned_to     uuid,                            -- mecânico responsável
  opened_by       uuid,
  complaint       text,
  diagnosis       text,
  scheduled_start timestamptz,
  scheduled_end   timestamptz,
  started_at      timestamptz,
  finished_at     timestamptz,
  opened_at       timestamptz NOT NULL DEFAULT now(),
  closed_at       timestamptz,
  discount        numeric(14,2) NOT NULL DEFAULT 0,
  total           numeric(14,2) NOT NULL DEFAULT 0,
  stock_applied   boolean NOT NULL DEFAULT false,
  public_token    uuid NOT NULL DEFAULT gen_random_uuid(),
  deleted_at      timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'service_order_status_chk') THEN
    ALTER TABLE service_order ADD CONSTRAINT service_order_status_chk
      CHECK (status IN ('aberta','aguardando_aprovacao','aprovada','em_execucao','concluida','entregue','cancelada'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_service_order_tenant_status
  ON service_order(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_service_order_tenant_customer
  ON service_order(tenant_id, customer_id);
CREATE INDEX IF NOT EXISTS idx_service_order_tenant_subject
  ON service_order(tenant_id, subject_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_service_order_tenant_number
  ON service_order(tenant_id, number);
CREATE UNIQUE INDEX IF NOT EXISTS uq_service_order_public_token
  ON service_order(public_token);

CREATE TABLE IF NOT EXISTS service_order_item (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  order_id          uuid NOT NULL REFERENCES service_order(id) ON DELETE CASCADE,
  kind              text NOT NULL,                 -- 'product' | 'service'
  inventory_item_id uuid,                           -- ponteiro (módulo inventory) — null = avulso
  name              text NOT NULL,                  -- snapshot
  quantity          numeric(14,3) NOT NULL DEFAULT 1,
  unit_price        numeric(14,2) NOT NULL DEFAULT 0,
  discount          numeric(14,2) NOT NULL DEFAULT 0,
  total             numeric(14,2) NOT NULL DEFAULT 0,
  created_at        timestamptz NOT NULL DEFAULT now()
);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'service_order_item_kind_chk') THEN
    ALTER TABLE service_order_item ADD CONSTRAINT service_order_item_kind_chk
      CHECK (kind IN ('product','service'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_service_order_item_tenant_order
  ON service_order_item(tenant_id, order_id);

-- RLS + FORCE + policy nas tabelas novas (idempotente).
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['service_order','service_order_item']
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

GRANT SELECT, INSERT, UPDATE, DELETE ON service_order TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON service_order_item TO app_user;
