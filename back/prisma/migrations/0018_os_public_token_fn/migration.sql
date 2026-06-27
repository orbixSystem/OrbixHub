-- 0018 — Acompanhamento público da OS (SECURITY DEFINER) — aditivo, idempotente
-- Fluxo público (página de tracking / chat do cliente) resolve tenant+OS a partir
-- do public_token SEM JWT — nunca confiando em input do cliente. Mapeia
-- public_token → (tenant_id, order_id), só para OS não deletadas. Espelha o estilo
-- de billing_resolve_tenant_by_subscription.
CREATE OR REPLACE FUNCTION os_resolve_by_public_token(p_token uuid)
RETURNS TABLE (tenant_id uuid, order_id uuid)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT tenant_id, id FROM service_order
  WHERE public_token = p_token AND deleted_at IS NULL
  LIMIT 1
$$;
REVOKE ALL ON FUNCTION os_resolve_by_public_token(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION os_resolve_by_public_token(uuid) TO app_user;
