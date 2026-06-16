-- ============================================================
-- OrbixHub baseline schema — auth & multitenant
-- Applied by app_owner. App connects as app_user (RLS enforced).
-- Migrations run as app_migrator (BYPASSRLS).
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto"; -- gen_random_uuid()

-- ---- Roles (idempotent) ----
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_migrator') THEN
    CREATE ROLE app_migrator LOGIN PASSWORD 'app_migrator_pw' BYPASSRLS;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_user') THEN
    CREATE ROLE app_user LOGIN PASSWORD 'app_user_pw' NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE;
  END IF;
END $$;

-- Returns the tenant set for the current transaction, or NULL if unset.
-- The 'true' arg => missing_ok, so unset returns NULL (fail-safe: policies match nothing).
CREATE OR REPLACE FUNCTION current_tenant_id() RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT NULLIF(current_setting('app.current_tenant_id', true), '')::uuid
$$;

-- ============================================================
-- Global / auth tables (no RLS)
-- ============================================================

-- ---- tenant ----
CREATE TABLE tenant (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  slug        text NOT NULL UNIQUE,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- ---- users (global identity; a user may belong to many tenants) ----
CREATE TABLE users (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email_normalized    text NOT NULL UNIQUE,  -- lower(trim(email)); case-insensitive identity
  full_name           text NOT NULL,
  password_hash       text NOT NULL,
  email_verified_at   timestamptz,
  failed_login_count  int NOT NULL DEFAULT 0,
  locked_until        timestamptz,
  last_tenant_id      uuid REFERENCES tenant(id) ON DELETE SET NULL,
  mfa_secret          text,           -- TOTP seam (inactive)
  mfa_enabled         boolean NOT NULL DEFAULT false,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);
-- NOTE: the app stores email_normalized = lower(trim(email)). UNIQUE on it gives
-- case-insensitive identity without the citext extension (keeps Prisma
-- introspection clean — no Unsupported types).

-- ---- role (global catalog) ----
CREATE TABLE role (
  id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key   text NOT NULL UNIQUE,   -- 'owner' | 'mechanic'
  name  text NOT NULL
);

-- ---- permission (global catalog) ----
CREATE TABLE permission (
  id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key   text NOT NULL UNIQUE,   -- e.g. 'os.write'
  name  text NOT NULL
);

-- ---- role_permission ----
CREATE TABLE role_permission (
  role_id        uuid NOT NULL REFERENCES role(id) ON DELETE CASCADE,
  permission_id  uuid NOT NULL REFERENCES permission(id) ON DELETE CASCADE,
  PRIMARY KEY (role_id, permission_id)
);

-- ---- refresh_token (opaque, hashed, rotating) ----
CREATE TABLE refresh_token (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  family_id   uuid NOT NULL,
  token_hash  text NOT NULL UNIQUE,         -- sha-256 of opaque token
  rotated_to  uuid REFERENCES refresh_token(id) ON DELETE SET NULL,
  revoked_at  timestamptz,
  expires_at  timestamptz NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_refresh_token_family ON refresh_token(family_id);
CREATE INDEX idx_refresh_token_user ON refresh_token(user_id);

-- ---- one_time_token (email verify / password reset / invite accept) ----
CREATE TABLE one_time_token (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES users(id) ON DELETE CASCADE,
  purpose     text NOT NULL,                -- 'email_verify' | 'password_reset'
  token_hash  text NOT NULL UNIQUE,
  consumed_at timestamptz,
  expires_at  timestamptz NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_ott_user_purpose ON one_time_token(user_id, purpose);

-- ---- login_attempt (audit/forensics for lockout) ----
CREATE TABLE login_attempt (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email_normalized text NOT NULL,
  user_id      uuid REFERENCES users(id) ON DELETE SET NULL,
  ip           inet,
  success      boolean NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_login_attempt_email_time ON login_attempt(email_normalized, created_at);

-- ---- billing catalog (global) ----
CREATE TABLE module (
  id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key   text NOT NULL UNIQUE,   -- 'os' | 'inventory' | ...
  name  text NOT NULL
);
CREATE TABLE plan (
  id     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key    text NOT NULL UNIQUE,  -- 'trial' | 'pro' | ...
  name   text NOT NULL,
  price_cents int NOT NULL DEFAULT 0
);
CREATE TABLE plan_module (
  plan_id   uuid NOT NULL REFERENCES plan(id) ON DELETE CASCADE,
  module_id uuid NOT NULL REFERENCES module(id) ON DELETE CASCADE,
  PRIMARY KEY (plan_id, module_id)
);

-- ============================================================
-- Tenant-scoped tables (RLS + FORCE)
-- ============================================================

-- ---- membership (user <-> tenant <-> role) ----
CREATE TABLE membership (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id  uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role_id    uuid NOT NULL REFERENCES role(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, user_id)
);
CREATE INDEX idx_membership_user ON membership(user_id);

-- ---- invite ----
CREATE TABLE invite (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  email_normalized text NOT NULL,
  role_id     uuid NOT NULL REFERENCES role(id),
  token_hash  text NOT NULL UNIQUE,
  invited_by  uuid REFERENCES users(id) ON DELETE SET NULL,
  accepted_at timestamptz,
  expires_at  timestamptz NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_invite_tenant ON invite(tenant_id);

-- ---- subscription (one per tenant) ----
CREATE TABLE subscription (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  plan_id     uuid NOT NULL REFERENCES plan(id),
  status      text NOT NULL,  -- 'trialing'|'active'|'past_due'|'canceled'
  external_subscription_id text,
  trial_ends_at timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id)
);

-- ---- tenant_module (enabled modules per tenant) ----
CREATE TABLE tenant_module (
  tenant_id  uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  module_id  uuid NOT NULL REFERENCES module(id) ON DELETE CASCADE,
  enabled    boolean NOT NULL DEFAULT true,
  PRIMARY KEY (tenant_id, module_id)
);

-- ---- audit_log ----
CREATE TABLE audit_log (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  action      text NOT NULL,    -- 'login'|'password_change'|'invite'|'subscription_change'
  target      text,
  metadata    jsonb,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_audit_tenant_time ON audit_log(tenant_id, created_at);

-- ============================================================
-- Enable RLS + FORCE + policy on the five tenant tables
-- ============================================================
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['membership','tenant_module','subscription','invite','audit_log']
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY;', t);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY;', t);
    EXECUTE format($f$
      CREATE POLICY tenant_isolation ON %I
      USING (tenant_id = current_tenant_id())
      WITH CHECK (tenant_id = current_tenant_id());
    $f$, t);
  END LOOP;
END $$;

-- ============================================================
-- auth_find_user_memberships (SECURITY DEFINER)
-- ============================================================
-- Lets the tenant-picker list a user's tenants pre-context, WITHOUT giving the
-- app BYPASSRLS. SECURITY DEFINER runs as the function owner (app_owner).
CREATE OR REPLACE FUNCTION auth_find_user_memberships(p_user_id uuid)
RETURNS TABLE (tenant_id uuid, tenant_slug text, role_key text)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT m.tenant_id, t.slug, r.key
  FROM membership m
  JOIN tenant t ON t.id = m.tenant_id
  JOIN role r ON r.id = m.role_id
  WHERE m.user_id = p_user_id
$$;
REVOKE ALL ON FUNCTION auth_find_user_memberships(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth_find_user_memberships(uuid) TO app_user;

-- ============================================================
-- Grants for app_user (least privilege)
-- ============================================================
GRANT USAGE ON SCHEMA public TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
GRANT EXECUTE ON FUNCTION current_tenant_id() TO app_user;
-- Future tables created by app_owner inherit these defaults:
ALTER DEFAULT PRIVILEGES FOR ROLE app_owner IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;
GRANT USAGE ON SCHEMA public TO app_migrator;

-- ============================================================
-- Seeds (roles, permissions, role_permission, modules, plans)
-- ============================================================
INSERT INTO role (key, name) VALUES
  ('owner','Dono'), ('mechanic','Mecânico')
ON CONFLICT (key) DO NOTHING;

INSERT INTO permission (key, name) VALUES
  ('os.read','Ver OS'), ('os.write','Editar OS'),
  ('inventory.read','Ver estoque'), ('inventory.write','Editar estoque'),
  ('users.manage','Gerenciar usuários'), ('billing.manage','Gerenciar assinatura'),
  ('tenant.manage','Gerenciar oficina')
ON CONFLICT (key) DO NOTHING;

-- owner gets all permissions; mechanic gets operational read/write only
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r, permission p WHERE r.key = 'owner'
ON CONFLICT DO NOTHING;
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON p.key IN ('os.read','os.write','inventory.read')
WHERE r.key = 'mechanic'
ON CONFLICT DO NOTHING;

INSERT INTO module (key, name) VALUES
  ('os','Ordens de Serviço'), ('inventory','Estoque'), ('customers','Clientes')
ON CONFLICT (key) DO NOTHING;

INSERT INTO plan (key, name, price_cents) VALUES
  ('trial','Trial', 0), ('pro','Pro', 9900)
ON CONFLICT (key) DO NOTHING;

-- trial includes os+customers+inventory; pro includes everything
INSERT INTO plan_module (plan_id, module_id)
SELECT pl.id, m.id FROM plan pl JOIN module m ON m.key IN ('os','customers','inventory')
WHERE pl.key = 'trial'
ON CONFLICT DO NOTHING;
INSERT INTO plan_module (plan_id, module_id)
SELECT pl.id, m.id FROM plan pl, module m WHERE pl.key = 'pro'
ON CONFLICT DO NOTHING;

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

-- ============================================================
-- 0002_billing — additive billing columns, webhook idempotency,
-- controlled resolvers (idempotent; safe to re-run via ci-db-setup).
-- ============================================================
ALTER TABLE module        ADD COLUMN IF NOT EXISTS is_core boolean NOT NULL DEFAULT false;
ALTER TABLE plan          ADD COLUMN IF NOT EXISTS billing_period text NOT NULL DEFAULT 'monthly';
ALTER TABLE tenant_module ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'plan';
ALTER TABLE tenant_module ADD COLUMN IF NOT EXISTS settings jsonb;
ALTER TABLE tenant_module ADD COLUMN IF NOT EXISTS valid_until timestamptz;
ALTER TABLE subscription  ADD COLUMN IF NOT EXISTS current_period_start timestamptz;
ALTER TABLE subscription  ADD COLUMN IF NOT EXISTS current_period_end   timestamptz;
ALTER TABLE subscription  ADD COLUMN IF NOT EXISTS canceled_at          timestamptz;

CREATE TABLE IF NOT EXISTS billing_webhook_event (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  external_event_id  text NOT NULL UNIQUE,
  type               text NOT NULL,
  payload            jsonb NOT NULL,
  received_at        timestamptz NOT NULL DEFAULT now(),
  processed_at       timestamptz
);
GRANT SELECT, INSERT, UPDATE, DELETE ON billing_webhook_event TO app_user;

-- Webhook (no JWT) resolves its tenant from the external subscription id.
CREATE OR REPLACE FUNCTION billing_resolve_tenant_by_subscription(p_external_subscription_id text)
RETURNS uuid
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT s.tenant_id FROM subscription s
  WHERE s.external_subscription_id = p_external_subscription_id
  LIMIT 1
$$;
REVOKE ALL ON FUNCTION billing_resolve_tenant_by_subscription(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION billing_resolve_tenant_by_subscription(text) TO app_user;

-- Daily trial-expiry job (no per-tenant context) finds due trials via this lookup.
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

UPDATE plan SET billing_period = 'monthly' WHERE key IN ('trial','pro');

-- ============================================================
-- 0003 — Employees & Settings (aditivo, idempotente)
-- ============================================================

-- membership.status (active|disabled) — nunca apagamos membros, só desativamos
ALTER TABLE membership ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active';
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'membership_status_chk') THEN
    ALTER TABLE membership ADD CONSTRAINT membership_status_chk CHECK (status IN ('active','disabled'));
  END IF;
END $$;

-- tenant.settings (jsonb) — preferências de empresa/branding
ALTER TABLE tenant ADD COLUMN IF NOT EXISTS settings jsonb NOT NULL DEFAULT '{}'::jsonb;

-- Permissões novas (catálogo global). subject.* = objeto de serviço (genérico).
INSERT INTO permission (key, name) VALUES
  ('customer.read','Ver clientes'), ('customer.write','Editar clientes'),
  ('subject.read','Ver objetos'), ('subject.write','Editar objetos'),
  ('os.approve','Aprovar OS'),
  ('tracking.manage','Gerenciar acompanhamento'),
  ('cashier.read','Ver caixa'), ('cashier.write','Operar caixa'),
  ('invoice.issue','Emitir nota'),
  ('finance.read','Ver financeiro'), ('finance.write','Editar financeiro'),
  ('report.read','Ver relatórios'),
  ('settings.manage','Gerenciar configurações')
ON CONFLICT (key) DO NOTHING;

-- Cargos novos (roles globais; decisão "role mínima")
INSERT INTO role (key, name) VALUES
  ('gerente','Gerente'), ('caixa','Caixa / Atendente')
ON CONFLICT (key) DO NOTHING;

-- owner: re-grant garante que ganhe as permissões novas também
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r, permission p WHERE r.key = 'owner'
ON CONFLICT DO NOTHING;

-- gerente: todas, exceto billing.manage
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r, permission p
WHERE r.key = 'gerente' AND p.key <> 'billing.manage'
ON CONFLICT DO NOTHING;

-- mechanic: operacional (inclui as novas customer.*/subject.*/tracking.manage)
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON p.key IN
  ('customer.read','customer.write','subject.read','subject.write',
   'os.read','os.write','inventory.read','tracking.manage')
WHERE r.key = 'mechanic'
ON CONFLICT DO NOTHING;

-- caixa: atendimento + caixa + nota
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON p.key IN
  ('customer.read','customer.write','subject.read','subject.write',
   'os.read','os.write','inventory.read',
   'cashier.read','cashier.write','invoice.issue')
WHERE r.key = 'caixa'
ON CONFLICT DO NOTHING;

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

-- ============================================================
-- 0007 — Customers & Subjects (aditivo, idempotente)
-- ============================================================
-- Cadastros-base genéricos do módulo `customers`:
--   customer = contato/pagador; subject = o que recebe o serviço (genérico —
--   "Veículo" na oficina, "Pet" no petshop). RLS + FORCE como toda tabela
--   tenant-scoped. `identifier` (placa, na oficina) é indexado p/ busca rápida;
--   o específico do vertical mora em `attributes` (jsonb).

CREATE TABLE IF NOT EXISTS customer (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  name        text NOT NULL,
  type        text NOT NULL DEFAULT 'PF',   -- 'PF' | 'PJ'
  document    text,                          -- opcional; único por tenant quando preenchido
  phone       text,
  email       text,
  address     text,
  notes       text,
  status      text NOT NULL DEFAULT 'active',-- 'active' | 'archived' (sem hard delete)
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'customer_type_chk') THEN
    ALTER TABLE customer ADD CONSTRAINT customer_type_chk CHECK (type IN ('PF','PJ'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'customer_status_chk') THEN
    ALTER TABLE customer ADD CONSTRAINT customer_status_chk CHECK (status IN ('active','archived'));
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_customer_tenant_time ON customer(tenant_id, created_at);
-- Documento único por tenant SOMENTE quando preenchido (índice único parcial).
CREATE UNIQUE INDEX IF NOT EXISTS uq_customer_tenant_document
  ON customer(tenant_id, document) WHERE document IS NOT NULL;

CREATE TABLE IF NOT EXISTS subject (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES customer(id) ON DELETE CASCADE,
  label       text,                          -- apelido (ex.: "Gol do João")
  identifier  text,                          -- genérico/indexado: placa na oficina
  attributes  jsonb,                         -- marca/modelo/ano/cor/km na oficina
  status      text NOT NULL DEFAULT 'active',-- 'active' | 'archived'
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'subject_status_chk') THEN
    ALTER TABLE subject ADD CONSTRAINT subject_status_chk CHECK (status IN ('active','archived'));
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_subject_tenant_identifier ON subject(tenant_id, identifier);
CREATE INDEX IF NOT EXISTS idx_subject_tenant_customer ON subject(tenant_id, customer_id);

-- RLS + FORCE + policy nas duas tabelas novas (idempotente).
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['customer','subject']
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY;', t);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY;', t);
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = t AND policyname = 'tenant_isolation') THEN
      EXECUTE format($f$
        CREATE POLICY tenant_isolation ON %I
        USING (tenant_id = current_tenant_id())
        WITH CHECK (tenant_id = current_tenant_id());
      $f$, t);
    END IF;
  END LOOP;
END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON customer TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON subject TO app_user;

-- ============================================================
-- 0008 — Customer soft delete (aditivo, idempotente)
-- ============================================================
-- "Excluir" cliente = soft delete (status 'deleted'), distinto de 'archived'.
-- Nunca hard delete (regra de ouro #6). Estende o CHECK de status.
ALTER TABLE customer DROP CONSTRAINT IF EXISTS customer_status_chk;
ALTER TABLE customer ADD CONSTRAINT customer_status_chk
  CHECK (status IN ('active','archived','deleted'));

-- ============================================================
-- 0009 — Subject soft delete (aditivo, idempotente)
-- ============================================================
ALTER TABLE subject DROP CONSTRAINT IF EXISTS subject_status_chk;
ALTER TABLE subject ADD CONSTRAINT subject_status_chk
  CHECK (status IN ('active','archived','deleted'));

-- ============================================================
-- 0010 — Inventory (Estoque & Serviços) — aditivo, idempotente
-- ============================================================
-- Catálogo de itens (produto/serviço) + movimentações de estoque.
-- Genérico/multi-vertical. RLS + FORCE como toda tabela tenant-scoped.
-- Preços em centavos (int); quantidades numeric(14,3).

CREATE TABLE IF NOT EXISTS inventory_item (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  kind             text NOT NULL,                       -- 'product' | 'service'
  name             text NOT NULL,
  code             text,
  barcode          text,
  category         text,
  unit             text NOT NULL DEFAULT 'un',
  sale_price_cents integer NOT NULL DEFAULT 0,
  cost_price_cents integer,
  margin_percent   numeric(7,2),
  sellable         boolean NOT NULL DEFAULT true,
  track_stock      boolean NOT NULL DEFAULT true,
  stock_qty        numeric(14,3) NOT NULL DEFAULT 0,
  min_qty          numeric(14,3),
  duration_minutes integer,
  brand            text,
  status           text NOT NULL DEFAULT 'active',      -- 'active' | 'archived'
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'inventory_item_kind_chk') THEN
    ALTER TABLE inventory_item ADD CONSTRAINT inventory_item_kind_chk CHECK (kind IN ('product','service'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'inventory_item_status_chk') THEN
    ALTER TABLE inventory_item ADD CONSTRAINT inventory_item_status_chk CHECK (status IN ('active','archived'));
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_inventory_item_tenant_kind ON inventory_item(tenant_id, kind);
CREATE INDEX IF NOT EXISTS idx_inventory_item_tenant_status ON inventory_item(tenant_id, status);
CREATE UNIQUE INDEX IF NOT EXISTS uq_inventory_item_tenant_code
  ON inventory_item(tenant_id, code) WHERE code IS NOT NULL;

CREATE TABLE IF NOT EXISTS inventory_movement (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  item_id       uuid NOT NULL REFERENCES inventory_item(id) ON DELETE CASCADE,
  type          text NOT NULL,                          -- 'in' | 'out' | 'adjust'
  quantity      numeric(14,3) NOT NULL,
  balance_after numeric(14,3) NOT NULL,
  reason        text,
  ref_type      text,
  ref_id        uuid,
  note          text,
  created_by    uuid,
  created_at    timestamptz NOT NULL DEFAULT now()
);
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'inventory_movement_type_chk') THEN
    ALTER TABLE inventory_movement ADD CONSTRAINT inventory_movement_type_chk CHECK (type IN ('in','out','adjust'));
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_inventory_movement_tenant_item
  ON inventory_movement(tenant_id, item_id, created_at DESC);

-- RLS + FORCE + policy nas duas tabelas novas (idempotente).
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['inventory_item','inventory_movement']
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY;', t);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY;', t);
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = t AND policyname = 'tenant_isolation') THEN
      EXECUTE format($f$
        CREATE POLICY tenant_isolation ON %I
        USING (tenant_id = current_tenant_id())
        WITH CHECK (tenant_id = current_tenant_id());
      $f$, t);
    END IF;
  END LOOP;
END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON inventory_item TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON inventory_movement TO app_user;
