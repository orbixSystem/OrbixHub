-- 0060 — motivo do bloqueio e controle do aviso de vencimento (aditivo, idempotente)
--
-- `block_reason` é o texto que o CLIENTE lê. Fica uma frase só, guardada uma
-- vez, porque a tela do app e o e-mail precisam dizer exatamente a mesma coisa:
-- duas fontes para a mesma explicação viram duas explicações diferentes no dia
-- em que alguém mexe numa e esquece a outra.
--
-- `aviso_vencimento_para` guarda A DATA QUE O AVISO ANUNCIOU, não um "já
-- avisei". É o que faz "avisar uma vez" significar "uma vez por prazo" sem
-- tabela de controle nem contador para alguém zerar na mão: renovou para outra
-- data, o valor diverge do `current_period_end` e o próximo vencimento volta a
-- avisar. Cliente de três anos recebe três avisos, um por ciclo, e nunca dois
-- pelo mesmo.
ALTER TABLE subscription ADD COLUMN IF NOT EXISTS block_reason           text;
ALTER TABLE subscription ADD COLUMN IF NOT EXISTS blocked_at             timestamptz;
ALTER TABLE subscription ADD COLUMN IF NOT EXISTS aviso_vencimento_para  timestamptz;

-- Quem está a <= N dias de vencer e ainda não foi avisado PARA ESTA data.
--
-- `status = 'active'` de propósito: quem já está em past_due/canceled não
-- precisa de aviso prévio — já recebeu o e-mail do vencimento ou do bloqueio.
CREATE OR REPLACE FUNCTION billing_find_vencimento_proximo(dias int)
RETURNS TABLE (tenant_id uuid, subscription_id uuid, vence_em timestamptz)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT s.tenant_id, s.id, s.current_period_end
  FROM subscription s
  WHERE s.status = 'active'
    AND s.current_period_end IS NOT NULL
    AND s.current_period_end > now()
    AND s.current_period_end <= now() + make_interval(days => dias)
    AND (s.aviso_vencimento_para IS DISTINCT FROM s.current_period_end)
$$;
REVOKE ALL ON FUNCTION billing_find_vencimento_proximo(int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION billing_find_vencimento_proximo(int) TO app_user;
