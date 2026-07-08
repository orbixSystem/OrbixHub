-- 0031_offline_sync — aditiva. Caixa por dispositivo + versão p/ sync + idempotência do push.
ALTER TABLE cash_session ADD COLUMN IF NOT EXISTS device_id uuid;
DROP INDEX IF EXISTS uq_cash_session_one_open;
-- 1 sessão aberta por (tenant, ponto de caixa); NULL = ponto legado/único.
CREATE UNIQUE INDEX IF NOT EXISTS uq_cash_session_open_device
  ON cash_session (tenant_id, COALESCE(device_id, '00000000-0000-0000-0000-000000000000'::uuid))
  WHERE status = 'open';

ALTER TABLE service_order_item ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE cash_entry        ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE OR REPLACE FUNCTION orbix_set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END $$;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['customer','subject','inventory_item','service_order',
                           'service_order_item','cash_session','cash_entry'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_updated_at ON %I', t, t);
    EXECUTE format('CREATE TRIGGER trg_%s_updated_at BEFORE UPDATE ON %I
                    FOR EACH ROW EXECUTE FUNCTION orbix_set_updated_at()', t, t);
  END LOOP;
END $$;

CREATE TABLE IF NOT EXISTS sync_mutation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  author_user_id uuid NOT NULL,
  client_mutation_id uuid NOT NULL,
  entity text NOT NULL,
  op text NOT NULL,
  result text NOT NULL,               -- applied | discarded | error
  error_message text,
  entity_id uuid,
  applied_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_sync_mutation UNIQUE (tenant_id, author_user_id, client_mutation_id)
);
CREATE INDEX IF NOT EXISTS idx_sync_mutation_tenant ON sync_mutation(tenant_id);
ALTER TABLE sync_mutation ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_mutation FORCE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='sync_mutation') THEN
    CREATE POLICY tenant_isolation ON sync_mutation
      USING (tenant_id = current_tenant_id())
      WITH CHECK (tenant_id = current_tenant_id());
  END IF;
END $$;
GRANT SELECT, INSERT, UPDATE, DELETE ON sync_mutation TO app_user;
