-- ============================================================
-- 0006 — Per-request membership check
-- ============================================================
-- The 15-min access token carries (sub, tid) but no live session state, so a
-- member deactivated mid-session kept working until the token expired. This
-- SECURITY DEFINER predicate lets a guard verify, on every authenticated
-- request, that the (user, tenant) membership is still active + non-expired.
CREATE OR REPLACE FUNCTION auth_membership_active(p_user_id uuid, p_tenant_id uuid)
RETURNS boolean
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM membership m
    WHERE m.user_id = p_user_id
      AND m.tenant_id = p_tenant_id
      AND m.status = 'active'
      AND (m.access_expires_at IS NULL OR m.access_expires_at > now())
  )
$$;
REVOKE ALL ON FUNCTION auth_membership_active(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth_membership_active(uuid, uuid) TO app_user;
