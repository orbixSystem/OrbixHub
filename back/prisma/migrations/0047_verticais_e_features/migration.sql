-- back/prisma/migrations/0047_verticais_e_features/migration.sql
-- ============================================================
-- 0047 — Verticais (nicho) e funcionalidades por tenant — aditivo
-- ============================================================
-- Design: docs/superpowers/specs/2026-08-17-verticais-nicho-features-design.md
--
-- Dois eixos ORTOGONAIS:
--   * NICHO manda só no VOCABULÁRIO. `tenant.vertical` aponta o pacote
--     ('veiculos' | 'equipamentos'); os textos e os campos do formulário vivem
--     no CÓDIGO (back/src/verticals/<key>/), não aqui.
--   * FUNCIONALIDADE é capacidade que liga/desliga POR MÓDULO: `tenant_feature`.
--
-- Por que o catálogo NÃO vem para o banco: ele só muda com deploy (feature nova
-- = código novo), então em tabela cada texto novo viraria uma migration em vez
-- de um objeto tipado com type-check e teste. Se um dia existir tela de admin
-- de plataforma, as tabelas de catálogo entram de forma aditiva e o resolvedor
-- passa a consultá-las antes do código.
-- Por isso `feature_key` é TEXTO, não FK: o catálogo está no código e a chave é
-- validada contra ele na escrita.
--
-- REGRA INVARIANTE: linha em `tenant_feature` só existe quando o dono mexeu no
-- toggle. Ausência = herda do pacote da vertical. É o que impede o retorno do
-- snapshot congelado (08/06/2026: `updateConfig` gravava o subjectFields inteiro
-- e o autocomplete FIPE quebrou em 11 de 18 tenants). Uma capacidade nova
-- alcança todo tenant do nicho sem migration de dados.
--
-- NUMERAÇÃO: 0046 está em voo na branch kaue-dev (retire_legacy_sales_module);
-- esta usa 0047 para as duas conviverem quando ambas chegarem na qa. O buraco
-- é inofensivo — as migrations são aditivas e independentes entre si.

-- ---- tenant.vertical ----
-- ALTER + backfill dentro do MESMO guard: o backfill roda exatamente uma vez,
-- no momento em que a coluna nasce. Reaplicar depois não mexe em tenant nenhum
-- (senão uma reaplicação transformaria um tenant genérico novo em oficina).
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'tenant' AND column_name = 'vertical'
  ) THEN
    ALTER TABLE tenant ADD COLUMN vertical text;
    -- Todo tenant que já existia é oficina (6 em produção, conferido em
    -- 10/08/2026, todos rodando o DEFAULT_CUSTOMERS_CONFIG de oficina). Sem
    -- isto eles cairiam no pacote padrão e veriam "Objeto" onde viam "Veículo".
    UPDATE tenant SET vertical = 'veiculos';
  END IF;
END $$;

-- ---- tenant_feature ----
-- Sem índice extra em (tenant_id): a PK (tenant_id, feature_key) já serve as
-- buscas por tenant pelo prefixo.
CREATE TABLE IF NOT EXISTS tenant_feature (
  tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  feature_key text NOT NULL,
  enabled     boolean NOT NULL,
  source      text NOT NULL DEFAULT 'manual',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, feature_key)
);

ALTER TABLE tenant_feature ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenant_feature FORCE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'tenant_feature' AND policyname = 'tenant_isolation'
  ) THEN
    CREATE POLICY tenant_isolation ON tenant_feature
    USING (tenant_id = current_tenant_id())
    WITH CHECK (tenant_id = current_tenant_id());
  END IF;
END $$;

-- DELETE é concedido de propósito, ao contrário das tabelas de negócio: apagar
-- a linha é como o dono diz "volta ao padrão do meu nicho", e uma preferência
-- de toggle não é registro histórico. A regra "sem hard delete" protege dado de
-- negócio (OS, venda, cliente), não isto.
GRANT SELECT, INSERT, UPDATE, DELETE ON tenant_feature TO app_user;
