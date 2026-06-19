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
-- 0010 — Inventory (Produtos) — aditivo, idempotente
-- ============================================================
-- Catálogo de PRODUTOS (uma única tabela). Genérico/multi-vertical.
-- Sem kind/serviço (serviço é o módulo 3), sem inventory_movement
-- (estoque ajustado direto em current_stock). Preços DECIMAIS.
-- Campos da vertical vivem em attributes (jsonb) + itemFields (config).
-- RLS + FORCE como toda tabela tenant-scoped.

CREATE TABLE IF NOT EXISTS inventory_item (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  name              text NOT NULL,
  sku               text,
  manufacturer_code text,
  barcode           text,
  category          text,
  brand             text,
  unit              text,
  sale_price        numeric(14,2),
  cost_price        numeric(14,2),
  margin_pct        numeric(7,2),
  current_stock     numeric(14,3) NOT NULL DEFAULT 0,
  min_stock         numeric(14,3),
  attributes        jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_active         boolean NOT NULL DEFAULT true,
  deleted_at        timestamptz,
  kind              text NOT NULL DEFAULT 'product',
  duration_minutes  integer,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

-- soft delete (aditivo): deleted_at NULL = ativo; setado = excluído. Idempotente p/ DBs já criados.
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

-- 0013 — tipo produto|serviço (+ duração p/ serviço). Aditivo. Idempotente p/ DBs já criados.
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS kind text NOT NULL DEFAULT 'product';
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS duration_minutes integer;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_item_kind_chk') THEN
    ALTER TABLE inventory_item ADD CONSTRAINT inventory_item_kind_chk CHECK (kind IN ('product','service'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_inventory_item_tenant_barcode
  ON inventory_item(tenant_id, barcode);
CREATE INDEX IF NOT EXISTS idx_inventory_item_tenant_mfrcode
  ON inventory_item(tenant_id, manufacturer_code);
CREATE INDEX IF NOT EXISTS idx_inventory_item_tenant_sku
  ON inventory_item(tenant_id, sku);
CREATE UNIQUE INDEX IF NOT EXISTS uq_inventory_item_tenant_barcode
  ON inventory_item(tenant_id, barcode) WHERE barcode IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_inventory_item_tenant_sku
  ON inventory_item(tenant_id, sku) WHERE sku IS NOT NULL;

-- RLS + FORCE + policy na tabela nova (idempotente).
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['inventory_item']
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

-- ============================================================
-- 0011 — catalog_product (cache durável de catálogo por GTIN; GLOBAL, sem RLS)
-- ============================================================
-- Dado público de referência (EAN→produto) compartilhado entre todos os tenants.
-- Não é tenant-scoped; não guarda quem consultou. Alimentado pelo lookup código-first.
CREATE TABLE IF NOT EXISTS catalog_product (
  gtin       text PRIMARY KEY,
  name       text NOT NULL,
  brand      text,
  ncm        text,
  category   text,
  source     text NOT NULL,                 -- 'cosmos' | 'openfoodfacts' | ...
  fetched_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON catalog_product TO app_user;

-- ============================================================
-- 0014 — Ordens de Serviço (service_order + service_order_item) — aditivo, idempotente
-- ============================================================
-- Cabeçalho da OS + itens (produtos do estoque / serviços / avulsos). Genérico:
-- "veículo" vem do subject (módulo customers) — só guardamos id + snapshot.
-- "Aponta, não invade": customer_id/subject_id/inventory_item_id são ponteiros;
-- nomes/preços são snapshot no momento. Preços DECIMAIS. RLS + FORCE.

CREATE TABLE IF NOT EXISTS service_order (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  number          text NOT NULL,                  -- ex.: 'OS-0001' (único por tenant)
  customer_id     uuid NOT NULL,                  -- ponteiro (módulo customers)
  customer_name   text NOT NULL,                  -- snapshot
  subject_id      uuid,                            -- ponteiro (subject/veículo) — nullable
  subject_label   text,                            -- snapshot
  status          text NOT NULL DEFAULT 'aberta',
  assigned_to     uuid,                            -- mecânico responsável
  opened_by       uuid,
  complaint       text,
  diagnosis       text,
  scheduled_start timestamptz,
  scheduled_end   timestamptz,
  started_at      timestamptz,
  finished_at     timestamptz,
  opened_at       timestamptz NOT NULL DEFAULT now(),
  closed_at       timestamptz,
  discount        numeric(14,2) NOT NULL DEFAULT 0,
  total           numeric(14,2) NOT NULL DEFAULT 0,
  stock_applied   boolean NOT NULL DEFAULT false,
  public_token    uuid NOT NULL DEFAULT gen_random_uuid(),
  deleted_at      timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'service_order_status_chk') THEN
    ALTER TABLE service_order ADD CONSTRAINT service_order_status_chk
      CHECK (status IN ('aberta','aguardando_aprovacao','aprovada','em_execucao','concluida','entregue','cancelada'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_service_order_tenant_status
  ON service_order(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_service_order_tenant_customer
  ON service_order(tenant_id, customer_id);
CREATE INDEX IF NOT EXISTS idx_service_order_tenant_subject
  ON service_order(tenant_id, subject_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_service_order_tenant_number
  ON service_order(tenant_id, number);
CREATE UNIQUE INDEX IF NOT EXISTS uq_service_order_public_token
  ON service_order(public_token);

CREATE TABLE IF NOT EXISTS service_order_item (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  order_id          uuid NOT NULL REFERENCES service_order(id) ON DELETE CASCADE,
  kind              text NOT NULL,                 -- 'product' | 'service'
  inventory_item_id uuid,                           -- ponteiro (módulo inventory) — null = avulso
  name              text NOT NULL,                  -- snapshot
  quantity          numeric(14,3) NOT NULL DEFAULT 1,
  unit_price        numeric(14,2) NOT NULL DEFAULT 0,
  discount          numeric(14,2) NOT NULL DEFAULT 0,
  total             numeric(14,2) NOT NULL DEFAULT 0,
  created_at        timestamptz NOT NULL DEFAULT now()
);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'service_order_item_kind_chk') THEN
    ALTER TABLE service_order_item ADD CONSTRAINT service_order_item_kind_chk
      CHECK (kind IN ('product','service'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_service_order_item_tenant_order
  ON service_order_item(tenant_id, order_id);

-- RLS + FORCE + policy nas tabelas novas (idempotente).
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['service_order','service_order_item']
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

GRANT SELECT, INSERT, UPDATE, DELETE ON service_order TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON service_order_item TO app_user;

-- ============================================================
-- 0015 — Timeline da OS (service_order_event) — aditivo, idempotente
-- ============================================================
-- Linha do tempo da OS: eventos auto-gerados (created/status_change) + notas
-- manuais (note) + fotos (photo, Fase 3). Cada evento tem flag `visible_public`
-- (entra ou não na página pública de acompanhamento). RLS + FORCE.

CREATE TABLE IF NOT EXISTS service_order_event (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  order_id        uuid NOT NULL REFERENCES service_order(id) ON DELETE CASCADE,
  kind            text NOT NULL,                  -- 'created' | 'status_change' | 'note' | 'photo'
  message         text,
  status_snapshot text,
  photo_id        uuid,                            -- ponteiro p/ service_order_photo (Fase 3) — nullable
  visible_public  boolean NOT NULL DEFAULT false,
  created_by      uuid,
  created_at      timestamptz NOT NULL DEFAULT now()
);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'service_order_event_kind_chk') THEN
    ALTER TABLE service_order_event ADD CONSTRAINT service_order_event_kind_chk
      CHECK (kind IN ('created','status_change','note','photo'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_service_order_event_tenant_order_created
  ON service_order_event(tenant_id, order_id, created_at);

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['service_order_event']
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

GRANT SELECT, INSERT, UPDATE, DELETE ON service_order_event TO app_user;

-- ============================================================
-- 0016 — Fotos da OS (service_order_photo) — aditivo, idempotente
-- ============================================================
-- Fotos anexadas a uma OS. O arquivo binário vive no object storage (StorageProvider:
-- disco local em dev / MinIO/S3 em prod); aqui guardamos apenas `storage_key` (chave no
-- bucket) + `url` (pública servida pelo provider). Cada upload também gera um evento
-- 'photo' na timeline (service_order_event.photo_id aponta p/ esta tabela). RLS + FORCE.

CREATE TABLE IF NOT EXISTS service_order_photo (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  order_id      uuid NOT NULL REFERENCES service_order(id) ON DELETE CASCADE,
  storage_key   text NOT NULL,
  url           text NOT NULL,
  caption       text,
  uploaded_by   uuid,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_service_order_photo_tenant_order
  ON service_order_photo(tenant_id, order_id);

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['service_order_photo']
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

GRANT SELECT, INSERT, UPDATE, DELETE ON service_order_photo TO app_user;

-- ============================================================
-- 0017 — Mensagens + Notificações (genéricos) — aditivo, idempotente
-- ============================================================
-- Dois módulos genéricos, reusáveis e independentes da OS:
--   * messages: conversation/message com contexto genérico via ref_type/ref_id
--     (hoje só ref_type='os', mas serve a qualquer módulo depois).
--   * notifications: notification tenant-wide (qualquer staff do tenant vê).
-- Todas tenant-scoped: RLS + FORCE + policy tenant_isolation + GRANT app_user.

CREATE TABLE IF NOT EXISTS conversation (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  ref_type        text NOT NULL,                  -- contexto genérico (ex.: 'os')
  ref_id          uuid NOT NULL,                  -- id da entidade dona do contexto
  title           text,                           -- snapshot legível (ex.: nome do cliente)
  ref_label       text,                           -- snapshot do rótulo da origem (ex.: 'OS-0001')
  channel         text NOT NULL DEFAULT 'public_link',
  staff_unread    integer NOT NULL DEFAULT 0,     -- contador de não-lidas pelo staff
  last_message_at timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_conversation_tenant_last_message
  ON conversation(tenant_id, last_message_at);
CREATE UNIQUE INDEX IF NOT EXISTS uq_conversation_tenant_ref
  ON conversation(tenant_id, ref_type, ref_id);

CREATE TABLE IF NOT EXISTS message (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  conversation_id uuid NOT NULL REFERENCES conversation(id) ON DELETE CASCADE,
  sender          text NOT NULL,                  -- 'customer' | 'staff'
  author_name     text,
  body            text NOT NULL,
  read_at         timestamptz,
  created_by      uuid,
  created_at      timestamptz NOT NULL DEFAULT now()
);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'message_sender_chk') THEN
    ALTER TABLE message ADD CONSTRAINT message_sender_chk
      CHECK (sender IN ('customer','staff'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_message_tenant_conversation_created
  ON message(tenant_id, conversation_id, created_at);

CREATE TABLE IF NOT EXISTS notification (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  type        text NOT NULL,                      -- 'message' | …
  title       text NOT NULL,
  body        text,
  ref_type    text,                               -- p/ navegar até a origem
  ref_id      uuid,
  read_at     timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notification_tenant_read_created
  ON notification(tenant_id, read_at, created_at);

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['conversation','message','notification']
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

GRANT SELECT, INSERT, UPDATE, DELETE ON conversation TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON message TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON notification TO app_user;

-- ============================================================
-- 0018 — Acompanhamento público da OS (SECURITY DEFINER) — aditivo, idempotente
-- ============================================================
-- Fluxo público (página de tracking / chat do cliente) resolve tenant+OS a partir
-- do public_token SEM JWT — nunca confiando em input do cliente. Mapeia
-- public_token → (tenant_id, order_id), só para OS não deletadas.
CREATE OR REPLACE FUNCTION os_resolve_by_public_token(p_token uuid)
RETURNS TABLE (tenant_id uuid, order_id uuid)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT tenant_id, id FROM service_order
  WHERE public_token = p_token AND deleted_at IS NULL
  LIMIT 1
$$;
REVOKE ALL ON FUNCTION os_resolve_by_public_token(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION os_resolve_by_public_token(uuid) TO app_user;

-- ============================================================
-- 0019 — Templates de serviço (service_order_template + _item) — aditivo, idempotente
-- ============================================================
-- Template nomeado (ex.: "Revisão completa") + itens pré-definidos. "Aplicar" a uma
-- OS pré-preenche os itens. "Aponta, não invade": inventory_item_id é ponteiro
-- (módulo inventory); name/unit_price são snapshot. Preços DECIMAIS. RLS + FORCE.

CREATE TABLE IF NOT EXISTS service_order_template (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  name        text NOT NULL,
  description text,
  deleted_at  timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_service_order_template_tenant
  ON service_order_template(tenant_id);
CREATE INDEX IF NOT EXISTS idx_service_order_template_tenant_name
  ON service_order_template(tenant_id, name);

CREATE TABLE IF NOT EXISTS service_order_template_item (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  template_id       uuid NOT NULL REFERENCES service_order_template(id) ON DELETE CASCADE,
  kind              text NOT NULL,                 -- 'product' | 'service'
  inventory_item_id uuid,                           -- ponteiro (módulo inventory) — null = avulso
  name              text NOT NULL,                  -- snapshot
  quantity          numeric(14,3) NOT NULL DEFAULT 1,
  unit_price        numeric(14,2),
  created_at        timestamptz NOT NULL DEFAULT now()
);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'service_order_template_item_kind_chk') THEN
    ALTER TABLE service_order_template_item ADD CONSTRAINT service_order_template_item_kind_chk
      CHECK (kind IN ('product','service'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_service_order_template_item_tenant_template
  ON service_order_template_item(tenant_id, template_id);

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['service_order_template','service_order_template_item']
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

GRANT SELECT, INSERT, UPDATE, DELETE ON service_order_template TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON service_order_template_item TO app_user;

-- ============================================================
-- 0020 — Empresa: CNPJ + razão social + nome fantasia no tenant (aditivo)
-- CNPJ é nullable na coluna (tenants antigos não têm); a obrigatoriedade
-- no cadastro é regra de aplicação. Unicidade global via índice parcial.
-- ============================================================
ALTER TABLE tenant ADD COLUMN IF NOT EXISTS cnpj        text;
ALTER TABLE tenant ADD COLUMN IF NOT EXISTS legal_name  text;  -- razão social
ALTER TABLE tenant ADD COLUMN IF NOT EXISTS trade_name  text;  -- nome fantasia
CREATE UNIQUE INDEX IF NOT EXISTS uq_tenant_cnpj ON tenant(cnpj) WHERE cnpj IS NOT NULL;
