-- ============================================================
-- 0005 — Access expiry (membership-level, set at invite time)
-- ============================================================
ALTER TABLE membership ADD COLUMN IF NOT EXISTS access_expires_at timestamptz;
ALTER TABLE invite     ADD COLUMN IF NOT EXISTS access_expires_at timestamptz;

-- Enforce active + non-expired access at login / refresh / switch-tenant.
-- (Same 3-column signature, so CREATE OR REPLACE is enough.) This also closes a
-- pre-existing gap: deactivated members (status='disabled') could previously log in.
CREATE OR REPLACE FUNCTION auth_find_user_memberships(p_user_id uuid)
RETURNS TABLE (tenant_id uuid, tenant_slug text, role_key text)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT m.tenant_id, t.slug, r.key
  FROM membership m
  JOIN tenant t ON t.id = m.tenant_id
  JOIN role r ON r.id = m.role_id
  WHERE m.user_id = p_user_id
    AND m.status = 'active'
    AND (m.access_expires_at IS NULL OR m.access_expires_at > now())
$$;
REVOKE ALL ON FUNCTION auth_find_user_memberships(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth_find_user_memberships(uuid) TO app_user;
