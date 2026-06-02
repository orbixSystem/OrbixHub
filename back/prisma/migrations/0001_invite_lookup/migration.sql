-- ============================================================
-- auth_find_invite_by_hash (SECURITY DEFINER)
-- ============================================================
-- Invite acceptance happens WITHOUT a JWT, so the tenant is unknown at request
-- time. `invite` is RLS and app_user cannot read it without a tenant context.
-- This SECURITY DEFINER lookup (runs as the function owner, app_owner) lets the
-- app resolve the invite by its unguessable token hash; the membership write
-- then runs under runWithTenant(tenant_id, ...). Mirrors auth_find_user_memberships.
CREATE OR REPLACE FUNCTION auth_find_invite_by_hash(p_token_hash text)
RETURNS TABLE (invite_id uuid, tenant_id uuid, email_normalized text,
               role_id uuid, expires_at timestamptz, accepted_at timestamptz)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT id, tenant_id, email_normalized, role_id, expires_at, accepted_at
  FROM invite WHERE token_hash = p_token_hash
$$;
REVOKE ALL ON FUNCTION auth_find_invite_by_hash(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth_find_invite_by_hash(text) TO app_user;
