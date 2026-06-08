-- ============================================================
-- 0004 — Invite lifecycle (soft-cancel + optional expiry)
-- ============================================================
ALTER TABLE invite ADD COLUMN IF NOT EXISTS canceled_at timestamptz;
ALTER TABLE invite ALTER COLUMN expires_at DROP NOT NULL;  -- NULL = sem expiração

-- The lookup function must now expose canceled_at (and expires_at may be NULL).
-- RETURNS TABLE signature changes → DROP + CREATE (idempotent via IF EXISTS).
DROP FUNCTION IF EXISTS auth_find_invite_by_hash(text);
CREATE FUNCTION auth_find_invite_by_hash(p_hash text)
RETURNS TABLE (invite_id uuid, tenant_id uuid, email_normalized text,
               role_id uuid, expires_at timestamptz, accepted_at timestamptz,
               canceled_at timestamptz)
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT id, tenant_id, email_normalized, role_id, expires_at, accepted_at, canceled_at
  FROM invite WHERE token_hash = p_hash
$$;
REVOKE ALL ON FUNCTION auth_find_invite_by_hash(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth_find_invite_by_hash(text) TO app_user;
