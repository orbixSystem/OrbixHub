-- back/prisma/migrations/0061_report_monthly_summary/migration.sql
-- ============================================================
-- 0061 — resumo mensal dos relatórios (aditivo, idempotente)
-- ============================================================
-- O módulo `report` nunca teve tabela: ele compõe tudo on-the-fly pelos
-- services dos módulos donos. Esta é a primeira exceção, e ela se justifica
-- porque o resumo mensal NÃO é uma consulta — é um fato datado:
--
--   * o texto foi escrito uma vez, no dia 1º, sobre o mês que fechou. Gerar de
--     novo em outubro produziria outro texto (o modelo não é determinístico) e
--     o dono veria o "mesmo" relatório mudar sozinho;
--   * cada geração custa uma chamada paga de API;
--   * o histórico é o produto: comparar o que foi dito em agosto com o que
--     aconteceu em setembro é metade do valor.
--
-- `metrics` e `signals` ficam em jsonb de propósito: são o retrato do mês
-- conforme a regra da época. Normalizar em colunas obrigaria uma migration a
-- cada métrica nova e, pior, reescreveria o passado — um resumo de 2026 passaria
-- a ser lido pela régua de 2027.
CREATE TABLE IF NOT EXISTS report_monthly_summary (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  -- Primeiro dia do mês analisado (2026-09-01 = resumo de setembro).
  period       date NOT NULL,
  metrics      jsonb NOT NULL,
  signals      jsonb NOT NULL,
  narrative    jsonb NOT NULL,
  -- Qual modelo escreveu — ou 'resumo-automatico' quando foi o texto nosso.
  ai_model     text NOT NULL,
  -- 'ok' = veio do modelo; 'fallback' = montado sem IA. A tela diz qual foi;
  -- esconder isso seria creditar à IA um texto que ela não escreveu.
  ai_status    text NOT NULL DEFAULT 'ok',
  generated_at timestamptz NOT NULL DEFAULT now(),
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- A unique é o que torna o job idempotente: rodar duas vezes no dia 1º (retry,
-- deploy no meio da madrugada, duas instâncias) não gera dois resumos nem duas
-- chamadas pagas.
CREATE UNIQUE INDEX IF NOT EXISTS report_monthly_summary_tenant_period_key
  ON report_monthly_summary (tenant_id, period);

ALTER TABLE report_monthly_summary ENABLE ROW LEVEL SECURITY;
ALTER TABLE report_monthly_summary FORCE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'report_monthly_summary' AND policyname = 'tenant_isolation'
  ) THEN
    CREATE POLICY tenant_isolation ON report_monthly_summary
    USING (tenant_id = current_tenant_id())
    WITH CHECK (tenant_id = current_tenant_id());
  END IF;
END $$;

GRANT SELECT, INSERT, UPDATE ON report_monthly_summary TO app_user;

-- Quem deve receber o resumo mensal.
--
-- A varredura do job roda ANTES de haver tenant no contexto, então a RLS
-- bloquearia o `app_user` — mesma situação de `billing_find_expired_trials` e
-- `expenses_find_recurrences_to_extend`. A função devolve só ponteiros
-- (id + nome); tudo que lê dado do cliente volta a passar pela RLS via
-- `runWithTenant`.
--
-- `status <> 'canceled'`: quem cancelou não recebe e-mail mensal de um sistema
-- que não usa mais. `enabled = true` porque o módulo `report` é contratável —
-- resumo é entrega do módulo, não cortesia para quem não o tem.
CREATE OR REPLACE FUNCTION report_find_tenants_for_monthly_summary()
RETURNS TABLE (tenant_id uuid, tenant_name text)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT DISTINCT t.id, t.name
  FROM tenant t
  JOIN tenant_module tm ON tm.tenant_id = t.id AND tm.enabled = true
  JOIN module m ON m.id = tm.module_id AND m.key = 'report' AND m.retired_at IS NULL
  JOIN subscription s ON s.tenant_id = t.id AND s.status <> 'canceled'
$$;
REVOKE ALL ON FUNCTION report_find_tenants_for_monthly_summary() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION report_find_tenants_for_monthly_summary() TO app_user;
