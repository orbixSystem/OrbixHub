-- ============================================================
-- 0007 — Customers & Subjects (aditivo, idempotente)
-- ============================================================
-- Cadastros-base genéricos do módulo `customers`:
--   customer = contato/pagador; subject = o que recebe o serviço (genérico —
--   "Veículo" na oficina, "Pet" no petshop). RLS + FORCE como toda tabela
--   tenant-scoped. `identifier` (placa, na oficina) é indexado p/ busca rápida;
--   o específico do vertical mora em `attributes` (jsonb).

CREATE TABLE IF NOT EXISTS customer (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  name        text NOT NULL,
  type        text NOT NULL DEFAULT 'PF',   -- 'PF' | 'PJ'
  document    text,                          -- opcional; único por tenant quando preenchido
  phone       text,
  email       text,
  address     text,
  notes       text,
  status      text NOT NULL DEFAULT 'active',-- 'active' | 'archived' (sem hard delete)
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'customer_type_chk') THEN
    ALTER TABLE customer ADD CONSTRAINT customer_type_chk CHECK (type IN ('PF','PJ'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'customer_status_chk') THEN
    ALTER TABLE customer ADD CONSTRAINT customer_status_chk CHECK (status IN ('active','archived'));
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_customer_tenant_time ON customer(tenant_id, created_at);
CREATE UNIQUE INDEX IF NOT EXISTS uq_customer_tenant_document
  ON customer(tenant_id, document) WHERE document IS NOT NULL;

CREATE TABLE IF NOT EXISTS subject (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES customer(id) ON DELETE CASCADE,
  label       text,
  identifier  text,
  attributes  jsonb,
  status      text NOT NULL DEFAULT 'active',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'subject_status_chk') THEN
    ALTER TABLE subject ADD CONSTRAINT subject_status_chk CHECK (status IN ('active','archived'));
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_subject_tenant_identifier ON subject(tenant_id, identifier);
CREATE INDEX IF NOT EXISTS idx_subject_tenant_customer ON subject(tenant_id, customer_id);

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['customer','subject']
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

GRANT SELECT, INSERT, UPDATE, DELETE ON customer TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON subject TO app_user;
