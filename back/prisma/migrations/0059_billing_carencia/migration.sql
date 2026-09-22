-- 0059 — carência depois do vencimento (aditivo, idempotente)
--
-- A régua combinada com o dono: vencido, o cliente fica em SOMENTE LEITURA por
-- alguns dias; passada a carência sem pagar, o acesso fecha de vez até o
-- pagamento.
--
-- Isso existe porque cortar tudo no dia do vencimento é hostil com quem
-- esqueceu o boleto — e nunca cortar é hostil com quem paga em dia. A carência
-- dá tempo de regularizar sem tirar do cliente a consulta ao que é dele.
--
-- A janela é contada a partir da PRÓPRIA data de vencimento (fim do acesso
-- pago, ou fim do teste), e não de quando o job rodou: assim o resultado não
-- depende de o job ter falhado num dia nem de a máquina ter ficado fora do ar.
CREATE OR REPLACE FUNCTION billing_find_grace_expired(dias int)
RETURNS TABLE (tenant_id uuid, subscription_id uuid)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT s.tenant_id, s.id FROM subscription s
  WHERE s.status = 'past_due'
    AND COALESCE(s.current_period_end, s.trial_ends_at) IS NOT NULL
    AND COALESCE(s.current_period_end, s.trial_ends_at) < now() - make_interval(days => dias)
$$;
REVOKE ALL ON FUNCTION billing_find_grace_expired(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION billing_find_grace_expired(int) TO app_user;
