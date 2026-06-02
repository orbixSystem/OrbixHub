-- ============================================================
-- 0002_billing — additive billing columns, webhook idempotency,
-- controlled resolvers. Existing columns are never altered.
--
-- Apply path in this project: the idempotent DDL below is also folded into
-- sql/auth-multitenant-schema.sql, which scripts/ci-db-setup.ts runs AS
-- app_owner (a superuser). SECURITY DEFINER functions are therefore owned by
-- app_owner and bypass RLS, exactly like auth_find_user_memberships. This file
-- mirrors that DDL for environments driven by `prisma migrate deploy`.
-- ============================================================

-- ---- additive columns (idempotent) ----
ALTER TABLE module        ADD COLUMN IF NOT EXISTS is_core boolean NOT NULL DEFAULT false;
ALTER TABLE plan          ADD COLUMN IF NOT EXISTS billing_period text NOT NULL DEFAULT 'monthly';
ALTER TABLE tenant_module ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'plan';
ALTER TABLE tenant_module ADD COLUMN IF NOT EXISTS settings jsonb;
ALTER TABLE tenant_module ADD COLUMN IF NOT EXISTS valid_until timestamptz;
ALTER TABLE subscription  ADD COLUMN IF NOT EXISTS current_period_start timestamptz;
ALTER TABLE subscription  ADD COLUMN IF NOT EXISTS current_period_end   timestamptz;
ALTER TABLE subscription  ADD COLUMN IF NOT EXISTS canceled_at          timestamptz;

-- ---- webhook idempotency (platform table, no RLS) ----
CREATE TABLE IF NOT EXISTS billing_webhook_event (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  external_event_id  text NOT NULL UNIQUE,
  type               text NOT NULL,
  payload            jsonb NOT NULL,
  received_at        timestamptz NOT NULL DEFAULT now(),
  processed_at       timestamptz
);
-- app_user needs explicit DML here (default privileges only target app_owner-created
-- tables; under prisma migrate deploy this table would be created by app_migrator).
GRANT SELECT, INSERT, UPDATE, DELETE ON billing_webhook_event TO app_user;

-- ---- resolver: external subscription id -> tenant_id (webhook has no JWT) ----
CREATE OR REPLACE FUNCTION billing_resolve_tenant_by_subscription(p_external_subscription_id text)
RETURNS uuid
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT s.tenant_id FROM subscription s
  WHERE s.external_subscription_id = p_external_subscription_id
  LIMIT 1
$$;
REVOKE ALL ON FUNCTION billing_resolve_tenant_by_subscription(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION billing_resolve_tenant_by_subscription(text) TO app_user;

-- ---- elevated lookup of expired trials for the daily job ----
CREATE OR REPLACE FUNCTION billing_find_expired_trials()
RETURNS TABLE (tenant_id uuid, subscription_id uuid)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT s.tenant_id, s.id FROM subscription s
  WHERE s.status = 'trialing'
    AND s.trial_ends_at IS NOT NULL
    AND s.trial_ends_at < now()
$$;
REVOKE ALL ON FUNCTION billing_find_expired_trials() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION billing_find_expired_trials() TO app_user;

-- ---- seed billing_period on existing plans (idempotent) ----
UPDATE plan SET billing_period = 'monthly' WHERE key IN ('trial','pro');
