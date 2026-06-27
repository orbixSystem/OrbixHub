-- ============================================================
-- 0017 — Mensagens + Notificações (genéricos) — aditivo, idempotente
-- ============================================================
-- Dois módulos genéricos, reusáveis e independentes da OS:
--   * messages: conversation/message com contexto genérico via ref_type/ref_id
--     (hoje só ref_type='os', mas serve a qualquer módulo depois).
--   * notifications: notification tenant-wide (qualquer staff do tenant vê).
-- Todas tenant-scoped: RLS + FORCE + policy tenant_isolation + GRANT app_user.

CREATE TABLE IF NOT EXISTS conversation (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  ref_type        text NOT NULL,                  -- contexto genérico (ex.: 'os')
  ref_id          uuid NOT NULL,                  -- id da entidade dona do contexto
  title           text,                           -- snapshot legível (ex.: nome do cliente)
  channel         text NOT NULL DEFAULT 'public_link',
  staff_unread    integer NOT NULL DEFAULT 0,     -- contador de não-lidas pelo staff
  last_message_at timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_conversation_tenant_last_message
  ON conversation(tenant_id, last_message_at);
-- Uma conversa por (ref_type, ref_id) dentro do tenant (idempotência no service).
CREATE UNIQUE INDEX IF NOT EXISTS uq_conversation_tenant_ref
  ON conversation(tenant_id, ref_type, ref_id);

CREATE TABLE IF NOT EXISTS message (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  conversation_id uuid NOT NULL REFERENCES conversation(id) ON DELETE CASCADE,
  sender          text NOT NULL,                  -- 'customer' | 'staff'
  author_name     text,
  body            text NOT NULL,
  read_at         timestamptz,
  created_by      uuid,
  created_at      timestamptz NOT NULL DEFAULT now()
);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'message_sender_chk') THEN
    ALTER TABLE message ADD CONSTRAINT message_sender_chk
      CHECK (sender IN ('customer','staff'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_message_tenant_conversation_created
  ON message(tenant_id, conversation_id, created_at);

CREATE TABLE IF NOT EXISTS notification (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  type        text NOT NULL,                      -- 'message' | …
  title       text NOT NULL,
  body        text,
  ref_type    text,                               -- p/ navegar até a origem
  ref_id      uuid,
  read_at     timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notification_tenant_read_created
  ON notification(tenant_id, read_at, created_at);

-- RLS + FORCE + policy (idempotente) p/ as três tabelas.
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['conversation','message','notification']
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

GRANT SELECT, INSERT, UPDATE, DELETE ON conversation TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON message TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON notification TO app_user;
