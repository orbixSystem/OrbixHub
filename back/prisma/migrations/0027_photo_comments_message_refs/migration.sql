-- 0027 — Comentários em fotos da OS (thread) + citação/resposta no chat.
-- Aditivo. "Aponta não invade": message guarda photo_id como ponteiro puro
-- (sem FK) + snapshot da url; a thread de comentários é dona do próprio registro
-- e referencia a foto por id.

-- Thread de comentários por foto da OS (staff e cliente).
CREATE TABLE IF NOT EXISTS service_order_photo_comment (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      uuid        NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  photo_id       uuid        NOT NULL REFERENCES service_order_photo(id) ON DELETE CASCADE,
  author_kind    text        NOT NULL CHECK (author_kind IN ('staff','customer')),
  author_user_id uuid        REFERENCES users(id) ON DELETE SET NULL,
  author_name    text,
  body           text        NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'service_order_photo_comment' AND policyname = 'tenant_isolation'
  ) THEN
    ALTER TABLE service_order_photo_comment ENABLE ROW LEVEL SECURITY;
    ALTER TABLE service_order_photo_comment FORCE ROW LEVEL SECURITY;
    CREATE POLICY tenant_isolation ON service_order_photo_comment
      USING (tenant_id = current_tenant_id());
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_sopc_tenant_photo
  ON service_order_photo_comment (tenant_id, photo_id, created_at);

GRANT SELECT, INSERT, UPDATE, DELETE ON service_order_photo_comment TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON service_order_photo_comment TO app_migrator;

-- Citação/resposta no chat: uma mensagem pode responder outra (reply_to_id, mesma
-- tabela) e/ou citar uma foto da OS (photo_id ponteiro puro + photo_url snapshot).
ALTER TABLE message
  ADD COLUMN IF NOT EXISTS reply_to_id uuid REFERENCES message(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS photo_id    uuid,
  ADD COLUMN IF NOT EXISTS photo_url   text;
