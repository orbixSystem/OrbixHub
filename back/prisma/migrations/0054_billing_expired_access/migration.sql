-- 0054 — acesso vencido: a companheira de billing_find_expired_trials().
--
-- Sem ela, `current_period_end` era enfeite: o acesso só caía quando o TESTE
-- vencia, e um contrato encerrado seguia valendo para sempre. Agora o painel
-- administrativo pode dar prazo (ou tirar) e a data significa alguma coisa.
--
-- `canceled` fica de FORA de propósito: já é o estado final, e reprocessá-lo
-- todo dia só geraria auditoria repetida sobre quem já está bloqueado.
CREATE OR REPLACE FUNCTION billing_find_expired_access()
RETURNS TABLE (tenant_id uuid, subscription_id uuid)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT s.tenant_id, s.id FROM subscription s
  WHERE s.status = 'active'
    AND s.current_period_end IS NOT NULL
    AND s.current_period_end < now()
$$;
REVOKE ALL ON FUNCTION billing_find_expired_access() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION billing_find_expired_access() TO app_user;
