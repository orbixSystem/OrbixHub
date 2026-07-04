-- ============================================================
-- 0025 — Módulo `invoice` (Nota Fiscal) — aditivo, idempotente
-- ============================================================
-- Emissão de nota a partir da OS. ONLINE-ONLY (depende de gateway fiscal externo).
-- Documento AGNÓSTICO: `document_type` ∈ nfse|nfce|nfe (MVP = nfse / serviço;
-- produto vem depois). A nota faz SNAPSHOT das linhas da OS (serviço E produto) —
-- é dona do próprio registro; guarda só o id da OS/cliente (ponteiro, "aponta não
-- invade"), NUNCA lê a tabela service_order. Valores DECIMAIS. RLS + FORCE.
--
-- Gateway fiscal abstrato (padrão do payment/): Noop em dev, GovBrNfseGateway real.
-- Status flui por webhook idempotente (tabela global `invoice_webhook_event`) e o
-- tenant é resolvido no servidor por função SECURITY DEFINER — nunca do payload.

-- ---- cabeçalho da nota -------------------------------------------------------
CREATE TABLE IF NOT EXISTS invoice (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  document_type     text NOT NULL DEFAULT 'nfse',   -- nfse | nfce | nfe
  status            text NOT NULL DEFAULT 'draft',  -- draft|processing|authorized|rejected|canceled|error
  environment       text NOT NULL DEFAULT 'homologacao', -- homologacao | producao
  order_id          uuid,                            -- ponteiro p/ OS (módulo os) — nullable
  order_number      text,                            -- snapshot
  customer_id       uuid,                            -- ponteiro p/ cliente (módulo customers)
  customer_name     text,                            -- snapshot
  customer_document text,                            -- snapshot (CPF/CNPJ do tomador)
  series            text,                            -- série fiscal (atribuída na autorização)
  number            text,                            -- número fiscal (atribuído na autorização)
  access_key        text,                            -- chave de acesso (NFe/NFCe) / código de verificação
  service_amount    numeric(14,2) NOT NULL DEFAULT 0,
  product_amount    numeric(14,2) NOT NULL DEFAULT 0,
  total_amount      numeric(14,2) NOT NULL DEFAULT 0,
  external_id       text,                            -- id no gateway/DPS
  pdf_url           text,
  xml_url           text,
  rejection_reason  text,
  issued_by         uuid,                            -- user que emitiu
  canceled_at       timestamptz,
  authorized_at     timestamptz,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'invoice_document_type_chk') THEN
    ALTER TABLE invoice ADD CONSTRAINT invoice_document_type_chk
      CHECK (document_type IN ('nfse','nfce','nfe'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'invoice_status_chk') THEN
    ALTER TABLE invoice ADD CONSTRAINT invoice_status_chk
      CHECK (status IN ('draft','processing','authorized','rejected','canceled','error'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'invoice_environment_chk') THEN
    ALTER TABLE invoice ADD CONSTRAINT invoice_environment_chk
      CHECK (environment IN ('homologacao','producao'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_invoice_tenant_status
  ON invoice(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_invoice_tenant_order
  ON invoice(tenant_id, order_id);
CREATE INDEX IF NOT EXISTS idx_invoice_tenant_created
  ON invoice(tenant_id, created_at);
-- external_id é único por gateway (usado para resolver a nota no webhook).
CREATE UNIQUE INDEX IF NOT EXISTS uq_invoice_external_id
  ON invoice(external_id) WHERE external_id IS NOT NULL;

-- ---- linhas (snapshot dos itens da OS: serviço E produto) --------------------
CREATE TABLE IF NOT EXISTS invoice_line (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  invoice_id   uuid NOT NULL REFERENCES invoice(id) ON DELETE CASCADE,
  kind         text NOT NULL,                        -- 'product' | 'service'
  name         text NOT NULL,                        -- snapshot
  quantity     numeric(14,3) NOT NULL DEFAULT 1,
  unit_price   numeric(14,2) NOT NULL DEFAULT 0,
  total        numeric(14,2) NOT NULL DEFAULT 0,
  created_at   timestamptz NOT NULL DEFAULT now()
);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'invoice_line_kind_chk') THEN
    ALTER TABLE invoice_line ADD CONSTRAINT invoice_line_kind_chk
      CHECK (kind IN ('product','service'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_invoice_line_tenant_invoice
  ON invoice_line(tenant_id, invoice_id);

-- ---- timeline / eventos fiscais ---------------------------------------------
CREATE TABLE IF NOT EXISTS invoice_event (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  invoice_id   uuid NOT NULL REFERENCES invoice(id) ON DELETE CASCADE,
  kind         text NOT NULL,                        -- created|sent|authorized|rejected|canceled|error
  message      text,
  status_snapshot text,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_invoice_event_tenant_invoice
  ON invoice_event(tenant_id, invoice_id);

-- RLS + FORCE + policy nas tabelas de tenant (idempotente).
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['invoice','invoice_line','invoice_event']
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

GRANT SELECT, INSERT, UPDATE, DELETE ON invoice TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON invoice_line TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON invoice_event TO app_user;

-- ---- idempotência de webhook (tabela GLOBAL, sem RLS) ------------------------
-- Espelha billing_webhook_event: o gateway fiscal notifica autorização/rejeição;
-- deduplicamos por external_event_id. O tenant é resolvido no servidor (função
-- SECURITY DEFINER abaixo) — nunca confiando no payload.
CREATE TABLE IF NOT EXISTS invoice_webhook_event (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  external_event_id text NOT NULL UNIQUE,
  type              text NOT NULL,
  payload           jsonb NOT NULL,
  received_at       timestamptz NOT NULL DEFAULT now(),
  processed_at      timestamptz
);
GRANT SELECT, INSERT, UPDATE ON invoice_webhook_event TO app_user;

-- ---- resolver tenant/nota pelo external_id (SECURITY DEFINER) ----------------
-- O webhook fiscal chega SEM JWT; `invoice` é RLS e app_user não a lê sem tenant.
-- Esta função (roda como o dono, app_owner) resolve a nota pelo id do gateway; o
-- update roda em runWithTenant(tenant_id, ...). Espelha os_resolve_by_public_token.
CREATE OR REPLACE FUNCTION invoice_resolve_by_external_id(p_external_id text)
RETURNS TABLE (tenant_id uuid, invoice_id uuid)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT tenant_id, id FROM invoice WHERE external_id = p_external_id
$$;
REVOKE ALL ON FUNCTION invoice_resolve_by_external_id(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION invoice_resolve_by_external_id(text) TO app_user;

-- ---- catálogo: módulo + permissão + planos + backfill ------------------------
-- `invoice.issue` já existe no catálogo (seed baseline). Adicionamos `invoice.read`.
INSERT INTO permission (key, name) VALUES
  ('invoice.read','Ver notas fiscais')
ON CONFLICT (key) DO NOTHING;

-- owner (todas), gerente (todas exceto billing.manage), caixa e mechanic recebem
-- invoice.read; owner/gerente/caixa também podem emitir (invoice.issue).
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON p.key = 'invoice.read'
WHERE r.key IN ('owner','gerente','caixa','mechanic')
ON CONFLICT DO NOTHING;

INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON p.key = 'invoice.issue'
WHERE r.key IN ('owner','gerente','caixa')
ON CONFLICT DO NOTHING;

-- Módulo contratável. Incluído em trial + pro (grátis no trial p/ conversão;
-- paywall futuro = remover de um plano). is_core=false.
INSERT INTO module (key, name, is_core) VALUES
  ('invoice','Nota Fiscal', false)
ON CONFLICT (key) DO NOTHING;

INSERT INTO plan_module (plan_id, module_id)
SELECT pl.id, m.id FROM plan pl JOIN module m ON m.key = 'invoice'
WHERE pl.key IN ('trial','pro')
ON CONFLICT DO NOTHING;

-- Backfill: todo tenant existente ganha o módulo `invoice` habilitado (source 'plan').
INSERT INTO tenant_module (tenant_id, module_id, enabled, source)
SELECT t.id, m.id, true, 'plan'
FROM tenant t CROSS JOIN module m
WHERE m.key = 'invoice'
ON CONFLICT (tenant_id, module_id) DO NOTHING;
