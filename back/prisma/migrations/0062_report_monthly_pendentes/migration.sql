-- back/prisma/migrations/0062_report_monthly_pendentes/migration.sql
-- ============================================================
-- 0062 — quem AINDA não tem o resumo do mês (aditivo, idempotente)
-- ============================================================
-- A 0061 listava todos os tenants elegíveis, e o job gerava tudo de uma vez.
-- Isso não sobrevive ao mundo real: a faixa gratuita do provedor de IA é de
-- 20 requisições por DIA. Numa base com 31 oficinas, as 11 últimas receberiam
-- para sempre o texto automático — e ninguém perceberia, porque o resumo
-- chegaria do mesmo jeito.
--
-- Com esta função o job vira uma ESTEIRA: roda nos primeiros dias do mês e, a
-- cada dia, atende só quem ainda não foi atendido. Em dois ou três dias todo
-- mundo tem o texto escrito, dentro da cota gratuita.
--
-- `report_monthly_summary` tem RLS; esta função é SECURITY DEFINER justamente
-- para enxergar além de um tenant — ela devolve só ponteiros, e tudo que lê
-- dado do cliente continua passando pela RLS via runWithTenant.
CREATE OR REPLACE FUNCTION report_find_tenants_missing_monthly_summary(p_period date)
RETURNS TABLE (tenant_id uuid, tenant_name text)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT DISTINCT t.id, t.name
  FROM tenant t
  JOIN tenant_module tm ON tm.tenant_id = t.id AND tm.enabled = true
  JOIN module m ON m.id = tm.module_id AND m.key = 'report' AND m.retired_at IS NULL
  JOIN subscription s ON s.tenant_id = t.id AND s.status <> 'canceled'
  WHERE NOT EXISTS (
    SELECT 1 FROM report_monthly_summary r
    WHERE r.tenant_id = t.id AND r.period = p_period
  )
  ORDER BY t.name
$$;
REVOKE ALL ON FUNCTION report_find_tenants_missing_monthly_summary(date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION report_find_tenants_missing_monthly_summary(date) TO app_user;
