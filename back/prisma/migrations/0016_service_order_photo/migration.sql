-- ============================================================
-- 0016 — Fotos da OS (service_order_photo) — aditivo, idempotente
-- ============================================================
-- Fotos anexadas a uma OS. O arquivo binário vive no object storage (StorageProvider:
-- disco local em dev / MinIO/S3 em prod); aqui guardamos apenas `storage_key` (chave no
-- bucket) + `url` (pública servida pelo provider). Cada upload também gera um evento
-- 'photo' na timeline (service_order_event.photo_id aponta p/ esta tabela). RLS + FORCE.

CREATE TABLE IF NOT EXISTS service_order_photo (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  order_id      uuid NOT NULL REFERENCES service_order(id) ON DELETE CASCADE,
  storage_key   text NOT NULL,
  url           text NOT NULL,
  caption       text,
  uploaded_by   uuid,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_service_order_photo_tenant_order
  ON service_order_photo(tenant_id, order_id);

-- RLS + FORCE + policy (idempotente).
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['service_order_photo']
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

GRANT SELECT, INSERT, UPDATE, DELETE ON service_order_photo TO app_user;
