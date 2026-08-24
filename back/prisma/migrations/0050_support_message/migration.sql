-- back/prisma/migrations/0050_support_message/migration.sql
-- ============================================================
-- 0050 — Canal de suporte do tenant com a Orbix — aditivo
-- ============================================================
-- Uma thread por tenant: o cliente escreve para o suporte da Orbix e o suporte
-- responde. Enquanto o sistema de admin não existe, a chegada é notificada por
-- e-mail (SUPPORT_EMAIL); depois, o admin lê por `/admin/...`.
--
-- POR QUE TABELA PRÓPRIA e não o módulo `messages`:
--   lá o remetente é 'customer' | 'staff', com o sentido do chat da OS — nele
--   "staff" é a oficina e "customer" é o cliente final dela. No suporte os
--   papéis invertem (a oficina é quem pede ajuda), e a thread apareceria
--   misturada no inbox de Mensagens do cliente, junto das conversas de OS.
--   Reaproveitar sairia mais barato hoje e mais confuso para sempre.
--
-- `from_orbix` em vez de um enum de remetente: só existem dois lados, e um
-- booleano não admite terceiro estado inválido.

CREATE TABLE IF NOT EXISTS support_message (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  body           text NOT NULL,
  -- false = o cliente escreveu; true = o suporte da Orbix respondeu.
  from_orbix     boolean NOT NULL DEFAULT false,
  -- Quem escreveu do lado do tenant. Nulo quando a mensagem é da Orbix.
  author_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  -- Snapshot do nome no momento do envio: se a pessoa sair da empresa, a
  -- conversa continua legível (mesma razão do snapshot da OS).
  author_name    text,
  -- Quando o OUTRO lado leu. Cliente lendo marca as da Orbix; o admin lendo
  -- marca as do cliente.
  read_at        timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_support_message_tenant_time
  ON support_message(tenant_id, created_at);

-- Não lidas do cliente (o que o suporte ainda não viu) — a consulta que o
-- admin vai fazer para montar a fila de atendimento.
CREATE INDEX IF NOT EXISTS idx_support_message_unread
  ON support_message(tenant_id) WHERE read_at IS NULL AND from_orbix = false;

ALTER TABLE support_message ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_message FORCE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'support_message' AND policyname = 'tenant_isolation'
  ) THEN
    CREATE POLICY tenant_isolation ON support_message
    USING (tenant_id = current_tenant_id())
    WITH CHECK (tenant_id = current_tenant_id());
  END IF;
END $$;

-- Sem DELETE: conversa de suporte é histórico de atendimento.
GRANT SELECT, INSERT, UPDATE ON support_message TO app_user;
