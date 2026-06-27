-- ============================================================
-- 0020 — Empresa: CNPJ + razão social + nome fantasia no tenant (aditivo)
-- ============================================================
ALTER TABLE tenant ADD COLUMN IF NOT EXISTS cnpj        text;
ALTER TABLE tenant ADD COLUMN IF NOT EXISTS legal_name  text;  -- razão social
ALTER TABLE tenant ADD COLUMN IF NOT EXISTS trade_name  text;  -- nome fantasia
CREATE UNIQUE INDEX IF NOT EXISTS uq_tenant_cnpj ON tenant(cnpj) WHERE cnpj IS NOT NULL;
