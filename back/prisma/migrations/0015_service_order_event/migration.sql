-- ============================================================
-- 0015 — Timeline da OS (service_order_event) — aditivo, idempotente
-- ============================================================
-- Linha do tempo da OS: eventos auto-gerados (created/status_change) + notas
-- manuais (note) + fotos (photo, Fase 3). Cada evento tem flag `visible_public`
-- (entra ou não na página pública de acompanhamento). RLS + FORCE.

CREATE TABLE IF NOT EXISTS service_order_event (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  order_id        uuid NOT NULL REFERENCES service_order(id) ON DELETE CASCADE,
  kind            text NOT NULL,                  -- 'created' | 'status_change' | 'note' | 'photo'
  message         text,
  status_snapshot text,
  photo_id        uuid,                            -- ponteiro p/ service_order_photo (Fase 3) — nullable
  visible_public  boolean NOT NULL DEFAULT false,
  created_by      uuid,
  created_at      timestamptz NOT NULL DEFAULT now()
);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'service_order_event_kind_chk') THEN
    ALTER TABLE service_order_event ADD CONSTRAINT service_order_event_kind_chk
      CHECK (kind IN ('created','status_change','note','photo'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_service_order_event_tenant_order_created
  ON service_order_event(tenant_id, order_id, created_at);

-- RLS + FORCE + policy (idempotente).
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['service_order_event']
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

GRANT SELECT, INSERT, UPDATE, DELETE ON service_order_event TO app_user;
