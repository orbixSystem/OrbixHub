-- back/prisma/migrations/0051_support_ticket/migration.sql
-- ============================================================
-- 0051 — Suporte por CHAMADO, não thread única — aditivo
-- ============================================================
-- A 0050 criou uma conversa só por tenant. Na prática o cliente tem assuntos
-- distintos ao mesmo tempo ("a nota não sai" e "o caixa não fecha"), e numa
-- thread única eles se atropelam: ninguém sabe qual pergunta a resposta
-- responde, e nada pode ser dado por encerrado sem encerrar o resto.
--
-- Cada chamado tem assunto e status próprios. `support_message` passa a
-- pertencer a um chamado.

CREATE TABLE IF NOT EXISTS support_ticket (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  subject         text NOT NULL,
  -- 'aberto' | 'resolvido'. Sem "em andamento": estado que ninguém consegue
  -- explicar a diferença vira ruído na lista.
  status          text NOT NULL DEFAULT 'aberto',
  created_by      uuid REFERENCES users(id) ON DELETE SET NULL,
  -- Ordena a lista pelo que teve movimento, não pelo que foi aberto primeiro.
  last_message_at timestamptz NOT NULL DEFAULT now(),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'support_ticket_status_chk') THEN
    ALTER TABLE support_ticket ADD CONSTRAINT support_ticket_status_chk
      CHECK (status IN ('aberto','resolvido'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_support_ticket_tenant_mov
  ON support_ticket(tenant_id, last_message_at DESC);

ALTER TABLE support_ticket ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_ticket FORCE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'support_ticket' AND policyname = 'tenant_isolation'
  ) THEN
    CREATE POLICY tenant_isolation ON support_ticket
    USING (tenant_id = current_tenant_id())
    WITH CHECK (tenant_id = current_tenant_id());
  END IF;
END $$;

GRANT SELECT, INSERT, UPDATE ON support_ticket TO app_user;

-- ---- mensagem passa a pertencer a um chamado ----
ALTER TABLE support_message
  ADD COLUMN IF NOT EXISTS ticket_id uuid REFERENCES support_ticket(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_support_message_ticket
  ON support_message(ticket_id, created_at);

-- Backfill: mensagens da 0050 (thread solta) viram um chamado por tenant. Num
-- banco novo não há linha nenhuma e o bloco não faz nada.
DO $$
DECLARE t record; novo uuid;
BEGIN
  FOR t IN SELECT DISTINCT tenant_id FROM support_message WHERE ticket_id IS NULL
  LOOP
    INSERT INTO support_ticket (tenant_id, subject, last_message_at)
    SELECT t.tenant_id, 'Atendimento anterior', COALESCE(max(created_at), now())
      FROM support_message WHERE tenant_id = t.tenant_id AND ticket_id IS NULL
    RETURNING id INTO novo;

    UPDATE support_message SET ticket_id = novo
     WHERE tenant_id = t.tenant_id AND ticket_id IS NULL;
  END LOOP;
END $$;
