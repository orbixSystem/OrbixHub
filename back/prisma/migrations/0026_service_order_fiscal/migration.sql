-- back/prisma/migrations/0026_service_order_fiscal/migration.sql
-- ============================================================
-- 0026 — Status fiscal (snapshot) na OS/venda — aditivo, idempotente
-- ============================================================
-- A OS dispara a emissão de nota via o módulo Fiscal (service público) e guarda
-- um SNAPSHOT do status fiscal devolvido — só para exibir. O Fiscal continua
-- DONO do dado. Pagamento NÃO tem coluna: é derivado do Caixa em runtime.

ALTER TABLE service_order ADD COLUMN IF NOT EXISTS fiscal_status text;
ALTER TABLE service_order ADD COLUMN IF NOT EXISTS fiscal_external_id text;
ALTER TABLE service_order ADD COLUMN IF NOT EXISTS fiscal_emitted_at timestamptz;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'service_order_fiscal_status_chk') THEN
    ALTER TABLE service_order ADD CONSTRAINT service_order_fiscal_status_chk
      CHECK (fiscal_status IS NULL OR fiscal_status IN ('nao_emitida','processando','emitida','rejeitada'));
  END IF;
END $$;
