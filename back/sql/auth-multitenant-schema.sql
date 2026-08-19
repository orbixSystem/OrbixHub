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
CREATE TABLE IF NOT EXISTS tenant (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  slug        text NOT NULL UNIQUE,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- ---- users (global identity; a user may belong to many tenants) ----
CREATE TABLE IF NOT EXISTS users (
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
CREATE TABLE IF NOT EXISTS role (
  id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key   text NOT NULL UNIQUE,   -- 'owner' | 'mechanic'
  name  text NOT NULL
);

-- ---- permission (global catalog) ----
CREATE TABLE IF NOT EXISTS permission (
  id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key   text NOT NULL UNIQUE,   -- e.g. 'os.write'
  name  text NOT NULL
);

-- ---- role_permission ----
CREATE TABLE IF NOT EXISTS role_permission (
  role_id        uuid NOT NULL REFERENCES role(id) ON DELETE CASCADE,
  permission_id  uuid NOT NULL REFERENCES permission(id) ON DELETE CASCADE,
  PRIMARY KEY (role_id, permission_id)
);

-- ---- refresh_token (opaque, hashed, rotating) ----
CREATE TABLE IF NOT EXISTS refresh_token (
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
CREATE INDEX IF NOT EXISTS idx_refresh_token_family ON refresh_token(family_id);
CREATE INDEX IF NOT EXISTS idx_refresh_token_user ON refresh_token(user_id);

-- ---- one_time_token (email verify / password reset / invite accept) ----
CREATE TABLE IF NOT EXISTS one_time_token (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES users(id) ON DELETE CASCADE,
  purpose     text NOT NULL,                -- 'email_verify' | 'password_reset'
  token_hash  text NOT NULL UNIQUE,
  consumed_at timestamptz,
  expires_at  timestamptz NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ott_user_purpose ON one_time_token(user_id, purpose);

-- ---- login_attempt (audit/forensics for lockout) ----
CREATE TABLE IF NOT EXISTS login_attempt (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email_normalized text NOT NULL,
  user_id      uuid REFERENCES users(id) ON DELETE SET NULL,
  ip           inet,
  success      boolean NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_login_attempt_email_time ON login_attempt(email_normalized, created_at);

-- ---- billing catalog (global) ----
CREATE TABLE IF NOT EXISTS module (
  id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key   text NOT NULL UNIQUE,   -- 'os' | 'inventory' | ...
  name  text NOT NULL
);
CREATE TABLE IF NOT EXISTS plan (
  id     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key    text NOT NULL UNIQUE,  -- 'trial' | 'pro' | ...
  name   text NOT NULL,
  price_cents int NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS plan_module (
  plan_id   uuid NOT NULL REFERENCES plan(id) ON DELETE CASCADE,
  module_id uuid NOT NULL REFERENCES module(id) ON DELETE CASCADE,
  PRIMARY KEY (plan_id, module_id)
);

-- ============================================================
-- Tenant-scoped tables (RLS + FORCE)
-- ============================================================

-- ---- membership (user <-> tenant <-> role) ----
CREATE TABLE IF NOT EXISTS membership (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id  uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role_id    uuid NOT NULL REFERENCES role(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_membership_user ON membership(user_id);

-- ---- invite ----
CREATE TABLE IF NOT EXISTS invite (
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
CREATE INDEX IF NOT EXISTS idx_invite_tenant ON invite(tenant_id);

-- ---- subscription (one per tenant) ----
CREATE TABLE IF NOT EXISTS subscription (
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
CREATE TABLE IF NOT EXISTS tenant_module (
  tenant_id  uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  module_id  uuid NOT NULL REFERENCES module(id) ON DELETE CASCADE,
  enabled    boolean NOT NULL DEFAULT true,
  PRIMARY KEY (tenant_id, module_id)
);

-- ---- audit_log ----
CREATE TABLE IF NOT EXISTS audit_log (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  action      text NOT NULL,    -- 'login'|'password_change'|'invite'|'subscription_change'
  target      text,
  metadata    jsonb,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_audit_tenant_time ON audit_log(tenant_id, created_at);

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
    -- Guarda de reaplicação: CREATE POLICY não aceita IF NOT EXISTS. Mesmo
    -- padrão usado pelas seções seguintes do arquivo.
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = t AND policyname = 'tenant_isolation') THEN
      EXECUTE format($f$
        CREATE POLICY tenant_isolation ON %I
        USING (tenant_id = current_tenant_id())
        WITH CHECK (tenant_id = current_tenant_id());
      $f$, t);
    END IF;
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
--
-- DROP antes do CREATE porque a seção 0004 REDEFINE esta função com outra
-- assinatura (acrescenta `canceled_at` ao RETURNS TABLE). Numa reaplicação o
-- banco já tem a versão do 0004, e `CREATE OR REPLACE` não muda tipo de retorno
-- ("cannot change return type of existing function"). Dropando aqui, a ordem
-- natural do arquivo se repete: cria esta, o 0004 dropa e recria a final.
DROP FUNCTION IF EXISTS auth_find_invite_by_hash(text);
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
  ('cashier.manage','Gerenciar caixa'),
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
CREATE OR REPLACE FUNCTION auth_find_invite_by_hash(p_hash text)
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
  -- 0044: observação livre do produto/serviço. Coluna do núcleo (conceito
  -- universal), não `attributes` (campo específico de vertical).
  description       text,
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

-- 0044 — descrição opcional (pega banco já existente; o CREATE TABLE acima já
-- nasce com ela em banco novo).
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS description text;

-- 0013 — tipo produto|serviço (+ duração p/ serviço). Aditivo. Idempotente p/ DBs já criados.
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS kind text NOT NULL DEFAULT 'product';
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS duration_minutes integer;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_item_kind_chk') THEN
    ALTER TABLE inventory_item ADD CONSTRAINT inventory_item_kind_chk CHECK (kind IN ('product','service'));
  END IF;
END $$;

-- Classificação fiscal (produto: ncm/cfop/origem/gtin; serviço: codigo_servico/aliquota_iss)
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS ncm            text;
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS cfop           text;
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS origem         text;
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS gtin           text;
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS codigo_servico text;
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS aliquota_iss   numeric(7,2);

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
-- 0024 — Stock movement (diário de estoque) — aditivo, idempotente
-- ============================================================
-- Diário de movimentos do estoque. current_stock continua como SALDO
-- materializado; cada movimento o ajusta. Substitui a semântica do booleano
-- service_order.stock_applied (mantido por ora, deprecado). Genérico via
-- ref_type/ref_id/ref_item_id. RLS + FORCE como toda tabela tenant-scoped.

CREATE TABLE IF NOT EXISTS stock_movement (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  inventory_item_id uuid NOT NULL REFERENCES inventory_item(id) ON DELETE CASCADE,
  stock_delta       numeric(14,3) NOT NULL,        -- negativo = saída; positivo = entrada
  reason            text NOT NULL,                 -- 'os_consumption' | 'os_reversal'
  ref_type          text NOT NULL,                 -- 'service_order'
  ref_id            uuid NOT NULL,                 -- id da OS
  ref_item_id       uuid,                          -- id da service_order_item (chave da reconciliação)
  created_by        uuid,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_stock_movement_tenant
  ON stock_movement(tenant_id);
CREATE INDEX IF NOT EXISTS idx_stock_movement_item
  ON stock_movement(inventory_item_id);
CREATE INDEX IF NOT EXISTS idx_stock_movement_ref_item
  ON stock_movement(ref_item_id);
CREATE INDEX IF NOT EXISTS idx_stock_movement_ref
  ON stock_movement(ref_type, ref_id);

-- RLS + FORCE + policy (idempotente).
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['stock_movement']
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

GRANT SELECT, INSERT, UPDATE, DELETE ON stock_movement TO app_user;

-- NOTE: o backfill de stock_movement a partir de service_order_item foi movido
-- para DEPOIS da criação de service_order_item (logo após a seção 0014) — num
-- apply fresh este bloco rodava antes da tabela existir e quebrava com
-- relation "service_order_item" does not exist.

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

-- Backfill (movido da seção 0024 stock_movement): para OS já aplicadas
-- (stock_applied) e ainda consumindo, insere um movimento-espelho por
-- linha-produto para que o consumo DERIVADO bata com o saldo histórico. NÃO
-- ajusta current_stock (o saldo já reflete a baixa). Guardado por NOT EXISTS →
-- idempotente. Precisa de service_order_item já criada, por isso roda aqui.
INSERT INTO stock_movement
  (tenant_id, inventory_item_id, stock_delta, reason, ref_type, ref_id, ref_item_id)
SELECT i.tenant_id, i.inventory_item_id, -i.quantity, 'os_consumption',
       'service_order', i.order_id, i.id
FROM service_order_item i
JOIN service_order o ON o.id = i.order_id
WHERE o.stock_applied = true
  AND o.status IN ('em_execucao','concluida','entregue')
  AND i.kind = 'product'
  AND i.inventory_item_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM stock_movement sm WHERE sm.ref_item_id = i.id
  );

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

-- ============================================================
-- 0022 — Índices p/ a camada de métricas da OS (Fase 1 dashboard) — aditivo
-- Agregações do dashboard/relatório filtram/agrupam por técnico (assigned_to)
-- e por período de abertura (opened_at). `(tenant_id, status)` já existe.
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_service_order_tenant_assigned
  ON service_order(tenant_id, assigned_to);
CREATE INDEX IF NOT EXISTS idx_service_order_tenant_opened
  ON service_order(tenant_id, opened_at);

-- ============================================================
-- 0023 — Módulo `report` (Fase 2 dashboard/relatórios) — aditivo
-- Relatórios = módulo contratável, mas habilitado em TODOS os planos hoje
-- (trial + pro) → grátis agora; paywall futuro = remover de um plano. is_core=false.
-- `report.read` (permissão) já está semeada acima. Backfill dos tenants existentes
-- para que /me.modules já liste `report` (mesma lógica do reconcile: enabled,
-- source 'plan'). Idempotente.
-- ============================================================
INSERT INTO module (key, name, is_core) VALUES
  ('report','Relatórios', false)
ON CONFLICT (key) DO NOTHING;

INSERT INTO plan_module (plan_id, module_id)
SELECT pl.id, m.id FROM plan pl JOIN module m ON m.key = 'report'
WHERE pl.key IN ('trial','pro')
ON CONFLICT DO NOTHING;

-- Backfill: todo tenant existente ganha o módulo `report` habilitado (source 'plan').
INSERT INTO tenant_module (tenant_id, module_id, enabled, source)
SELECT t.id, m.id, true, 'plan'
FROM tenant t CROSS JOIN module m
WHERE m.key = 'report'
ON CONFLICT (tenant_id, module_id) DO NOTHING;

-- ============================================================
-- 0025 — Módulo `invoice` (Nota Fiscal) — aditivo, idempotente
-- Emissão de nota a partir da OS (ONLINE-ONLY). Documento agnóstico
-- (nfse|nfce|nfe; MVP = nfse). Snapshot das linhas da OS (serviço E produto).
-- "Aponta não invade": só guarda id da OS/cliente. RLS + FORCE. Gateway fiscal
-- abstrato (Noop dev / GovBrNfseGateway real); status por webhook idempotente
-- (invoice_webhook_event global) + tenant resolvido por SECURITY DEFINER.
-- ============================================================
CREATE TABLE IF NOT EXISTS invoice (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  document_type     text NOT NULL DEFAULT 'nfse',
  status            text NOT NULL DEFAULT 'draft',
  environment       text NOT NULL DEFAULT 'homologacao',
  order_id          uuid,
  sale_id           uuid,
  order_number      text,
  customer_id       uuid,
  customer_name     text,
  customer_document text,
  series            text,
  number            text,
  access_key        text,
  service_amount    numeric(14,2) NOT NULL DEFAULT 0,
  product_amount    numeric(14,2) NOT NULL DEFAULT 0,
  total_amount      numeric(14,2) NOT NULL DEFAULT 0,
  external_id       text,
  pdf_url           text,
  xml_url           text,
  rejection_reason  text,
  issued_by         uuid,
  canceled_at       timestamptz,
  authorized_at     timestamptz,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'invoice_document_type_chk') THEN
    ALTER TABLE invoice ADD CONSTRAINT invoice_document_type_chk
      CHECK (document_type IN ('nfse','nfce','nfe'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'invoice_status_chk') THEN
    ALTER TABLE invoice ADD CONSTRAINT invoice_status_chk
      CHECK (status IN ('draft','processing','authorized','rejected','canceled','error'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'invoice_environment_chk') THEN
    ALTER TABLE invoice ADD CONSTRAINT invoice_environment_chk
      CHECK (environment IN ('homologacao','producao'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_invoice_tenant_status ON invoice(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_invoice_tenant_order ON invoice(tenant_id, order_id);
CREATE INDEX IF NOT EXISTS idx_invoice_tenant_sale ON invoice(tenant_id, sale_id) WHERE sale_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_invoice_tenant_created ON invoice(tenant_id, created_at);
CREATE UNIQUE INDEX IF NOT EXISTS uq_invoice_external_id ON invoice(external_id) WHERE external_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS invoice_line (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  invoice_id   uuid NOT NULL REFERENCES invoice(id) ON DELETE CASCADE,
  kind         text NOT NULL,
  name         text NOT NULL,
  quantity     numeric(14,3) NOT NULL DEFAULT 1,
  unit_price   numeric(14,2) NOT NULL DEFAULT 0,
  total        numeric(14,2) NOT NULL DEFAULT 0,
  created_at   timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE invoice_line ADD COLUMN IF NOT EXISTS ncm            text;
ALTER TABLE invoice_line ADD COLUMN IF NOT EXISTS cfop           text;
ALTER TABLE invoice_line ADD COLUMN IF NOT EXISTS unidade        text;
ALTER TABLE invoice_line ADD COLUMN IF NOT EXISTS gtin           text;
ALTER TABLE invoice_line ADD COLUMN IF NOT EXISTS codigo_servico text;
ALTER TABLE invoice_line ADD COLUMN IF NOT EXISTS origem         text;
ALTER TABLE invoice_line ADD COLUMN IF NOT EXISTS aliquota_iss   numeric(7,2);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'invoice_line_kind_chk') THEN
    ALTER TABLE invoice_line ADD CONSTRAINT invoice_line_kind_chk
      CHECK (kind IN ('product','service'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_invoice_line_tenant_invoice ON invoice_line(tenant_id, invoice_id);

CREATE TABLE IF NOT EXISTS invoice_event (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  invoice_id   uuid NOT NULL REFERENCES invoice(id) ON DELETE CASCADE,
  kind         text NOT NULL,
  message      text,
  status_snapshot text,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_invoice_event_tenant_invoice ON invoice_event(tenant_id, invoice_id);

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['invoice','invoice_line','invoice_event']
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

GRANT SELECT, INSERT, UPDATE, DELETE ON invoice TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON invoice_line TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON invoice_event TO app_user;

CREATE TABLE IF NOT EXISTS invoice_webhook_event (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  external_event_id text NOT NULL UNIQUE,
  type              text NOT NULL,
  payload           jsonb NOT NULL,
  received_at       timestamptz NOT NULL DEFAULT now(),
  processed_at      timestamptz
);
GRANT SELECT, INSERT, UPDATE ON invoice_webhook_event TO app_user;

CREATE OR REPLACE FUNCTION invoice_resolve_by_external_id(p_external_id text)
RETURNS TABLE (tenant_id uuid, invoice_id uuid)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT tenant_id, id FROM invoice WHERE external_id = p_external_id
$$;
REVOKE ALL ON FUNCTION invoice_resolve_by_external_id(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION invoice_resolve_by_external_id(text) TO app_user;

INSERT INTO permission (key, name) VALUES
  ('invoice.read','Ver notas fiscais')
ON CONFLICT (key) DO NOTHING;

INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON p.key = 'invoice.read'
WHERE r.key IN ('owner','gerente','caixa','mechanic')
ON CONFLICT DO NOTHING;

-- invoice.config — configuração fiscal sensível (owner-only)
INSERT INTO permission (key, name) VALUES
  ('invoice.config','Configurar nota fiscal')
ON CONFLICT (key) DO NOTHING;

INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON p.key = 'invoice.config'
WHERE r.key IN ('owner')
ON CONFLICT DO NOTHING;

INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON p.key = 'invoice.issue'
WHERE r.key IN ('owner','gerente','caixa')
ON CONFLICT DO NOTHING;

INSERT INTO module (key, name, is_core) VALUES
  ('invoice','Nota Fiscal', false)
ON CONFLICT (key) DO NOTHING;

INSERT INTO plan_module (plan_id, module_id)
SELECT pl.id, m.id FROM plan pl JOIN module m ON m.key = 'invoice'
WHERE pl.key IN ('trial','pro')
ON CONFLICT DO NOTHING;

INSERT INTO tenant_module (tenant_id, module_id, enabled, source)
SELECT t.id, m.id, true, 'plan'
FROM tenant t CROSS JOIN module m
WHERE m.key = 'invoice'
ON CONFLICT (tenant_id, module_id) DO NOTHING;

-- ============================================================
-- 0025b — Horário de funcionamento por tenant (agenda)
-- 7 linhas por tenant (0=Dom … 6=Sáb), única por (tenant_id, day_of_week).
-- ============================================================
CREATE TABLE IF NOT EXISTS business_hours (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid        NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  day_of_week  smallint    NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  is_open      boolean     NOT NULL DEFAULT true,
  open_time    varchar(5)  NOT NULL DEFAULT '08:00',
  close_time   varchar(5)  NOT NULL DEFAULT '18:00',
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT business_hours_tenant_day_uq UNIQUE (tenant_id, day_of_week)
);

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relname = 'business_hours' AND c.relkind = 'r'
      AND EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'business_hours' AND policyname = 'tenant_isolation')
  ) THEN
    ALTER TABLE business_hours ENABLE ROW LEVEL SECURITY;
    ALTER TABLE business_hours FORCE ROW LEVEL SECURITY;
    CREATE POLICY tenant_isolation ON business_hours
      USING (tenant_id = current_tenant_id());
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_business_hours_tenant ON business_hours (tenant_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON business_hours TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON business_hours TO app_migrator;

-- ============================================================
-- 0026 — Agendamento por item de OS
-- ============================================================
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_name = 'service_order_item' AND column_name = 'assigned_to') THEN
    ALTER TABLE service_order_item
      ADD COLUMN assigned_to        uuid        REFERENCES users(id) ON DELETE SET NULL,
      ADD COLUMN scheduled_start    timestamptz,
      ADD COLUMN estimated_duration integer     CHECK (estimated_duration > 0 AND estimated_duration % 30 = 0),
      ADD COLUMN scheduled_end      timestamptz;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_soi_assigned_schedule
  ON service_order_item (tenant_id, assigned_to, scheduled_start, scheduled_end)
  WHERE assigned_to IS NOT NULL AND scheduled_start IS NOT NULL AND scheduled_end IS NOT NULL;

-- ============================================================
-- 0027 — Comentários em fotos da OS (thread) + citação/resposta no chat.
-- Aditivo, idempotente. "Aponta não invade": message.photo_id é ponteiro puro
-- (sem FK) + snapshot da url; a thread de comentários referencia a foto por id.
-- ============================================================
CREATE TABLE IF NOT EXISTS service_order_photo_comment (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      uuid        NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  photo_id       uuid        NOT NULL REFERENCES service_order_photo(id) ON DELETE CASCADE,
  author_kind    text        NOT NULL CHECK (author_kind IN ('staff','customer')),
  author_user_id uuid        REFERENCES users(id) ON DELETE SET NULL,
  author_name    text,
  body           text        NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'service_order_photo_comment' AND policyname = 'tenant_isolation'
  ) THEN
    ALTER TABLE service_order_photo_comment ENABLE ROW LEVEL SECURITY;
    ALTER TABLE service_order_photo_comment FORCE ROW LEVEL SECURITY;
    CREATE POLICY tenant_isolation ON service_order_photo_comment
      USING (tenant_id = current_tenant_id());
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_sopc_tenant_photo
  ON service_order_photo_comment (tenant_id, photo_id, created_at);

GRANT SELECT, INSERT, UPDATE, DELETE ON service_order_photo_comment TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON service_order_photo_comment TO app_migrator;

ALTER TABLE message
  ADD COLUMN IF NOT EXISTS reply_to_id uuid REFERENCES message(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS photo_id    uuid,
  ADD COLUMN IF NOT EXISTS photo_url   text;

-- ============================================================
-- 0028 — Foto do objeto/veículo (subject) — aditivo, idempotente.
-- Uma foto por subject (avatar do veículo), no storage (S3/local): url pública
-- + chave do storage (p/ remover o binário depois).
-- ============================================================
ALTER TABLE subject
  ADD COLUMN IF NOT EXISTS photo_url         text,
  ADD COLUMN IF NOT EXISTS photo_storage_key text;

-- ============================================================
-- 0029 — (removido) módulo `sales` duplicado — substituído pelo módulo `sale`
-- (seção 0032). Se uma instalação anterior criou a tabela `sale` no formato
-- antigo (coluna payment_method, sem fiscal_status) e ela está VAZIA, derruba
-- para o CREATE do 0032 recriar no formato atual. Com dados, exige migração manual.
-- ============================================================
DO $$
DECLARE n bigint;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='sale' AND column_name='payment_method')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='sale' AND column_name='fiscal_status') THEN
    EXECUTE 'SELECT count(*) FROM sale' INTO n;
    IF n = 0 THEN
      DROP TABLE IF EXISTS sale_item;
      DROP TABLE IF EXISTS sale;
    ELSE
      RAISE EXCEPTION 'Tabela sale no formato antigo (módulo sales) contém dados — migre manualmente antes de aplicar o schema.';
    END IF;
  END IF;
END $$;

-- Desabilita o módulo `sales` legado onde tiver sido semeado (o módulo atual é `sale`).
UPDATE tenant_module tm SET enabled = false
FROM module m WHERE m.id = tm.module_id AND m.key = 'sales' AND tm.enabled;

-- ============================================================
-- 0030 — Módulo `cashier` (Caixa) — aditivo, idempotente
-- ============================================================
-- Registrador de dinheiro + livro caixa. `cash_session` = sessão do dia (abre/fecha
-- com expected×counted×difference; 1 aberta por tenant via índice parcial). `cash_entry`
-- = lançamentos (entradas/saídas). Um recebimento APONTA para a venda via
-- (sale_kind, sale_id) e lê o total pelo service da venda — "aponta, não invade"
-- (nunca toca service_order). Estorno é LÓGICO (reversed_at), nunca hard delete.
-- RLS + FORCE como toda tabela tenant-scoped. Permissões cashier.read/cashier.write
-- já semeadas e mapeadas (owner/gerente/caixa) acima.

CREATE TABLE IF NOT EXISTS cash_session (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id               uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  opened_by               uuid NOT NULL,
  opened_at               timestamptz NOT NULL DEFAULT now(),
  opening_amount          numeric(14,2) NOT NULL DEFAULT 0,
  closed_by               uuid,
  closed_at               timestamptz,
  closing_amount_counted  numeric(14,2),
  closing_amount_expected numeric(14,2),
  difference              numeric(14,2),
  status                  text NOT NULL DEFAULT 'open',
  device_id               uuid,                          -- dispositivo dono da sessão (0031); NULL = ponto legado/único
  notes                   text,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT cash_session_status_chk CHECK (status IN ('open','closed'))
);
-- Idempotente p/ DBs já criados antes da coluna acima existir (0031_offline_sync).
ALTER TABLE cash_session ADD COLUMN IF NOT EXISTS device_id uuid;

CREATE INDEX IF NOT EXISTS idx_cash_session_tenant ON cash_session(tenant_id);
-- 1 sessão aberta por (tenant, ponto de caixa/dispositivo); NULL = ponto legado/único (0031_offline_sync).
DROP INDEX IF EXISTS uq_cash_session_one_open;
CREATE UNIQUE INDEX IF NOT EXISTS uq_cash_session_open_device
  ON cash_session (tenant_id, COALESCE(device_id, '00000000-0000-0000-0000-000000000000'::uuid))
  WHERE status = 'open';

CREATE TABLE IF NOT EXISTS cash_entry (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  cash_session_id uuid NOT NULL REFERENCES cash_session(id) ON DELETE CASCADE,
  direction       text NOT NULL,                  -- 'in' (entrada) | 'out' (saída)
  amount          numeric(14,2) NOT NULL,
  method          text NOT NULL,                  -- pix|dinheiro|cartao_credito|cartao_debito|outro
  category        text NOT NULL,                  -- os_payment|venda_avulsa|despesa|sangria|suprimento
  sale_kind       text,                           -- 'os' | 'sale' (nullable) — venda recebida
  sale_id         uuid,                           -- id da venda apontada (nullable)
  description     text,
  reversed_at     timestamptz,                    -- estorno lógico (fora dos somatórios)
  reversed_by     uuid,
  reversal_reason text,
  created_by      uuid NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT cash_entry_direction_chk CHECK (direction IN ('in','out')),
  CONSTRAINT cash_entry_amount_chk    CHECK (amount > 0),
  CONSTRAINT cash_entry_method_chk    CHECK (method IN ('pix','dinheiro','cartao_credito','cartao_debito','outro')),
  CONSTRAINT cash_entry_category_chk  CHECK (category IN ('os_payment','venda_avulsa','despesa','sangria','suprimento')),
  -- 'expense' entra na 0040: a baixa de uma conta a pagar marca a origem para o
  -- clique no lançamento abrir a despesa. É TAG de origem (como 'os', que também
  -- é de outro módulo) — o caixa nunca lê a tabela alheia.
  CONSTRAINT cash_entry_sale_kind_chk CHECK (sale_kind IS NULL OR sale_kind IN ('os','sale','expense'))
);

CREATE INDEX IF NOT EXISTS idx_cash_entry_tenant_session  ON cash_entry(tenant_id, cash_session_id);
CREATE INDEX IF NOT EXISTS idx_cash_entry_tenant_sale     ON cash_entry(tenant_id, sale_kind, sale_id);
CREATE INDEX IF NOT EXISTS idx_cash_entry_tenant_created  ON cash_entry(tenant_id, created_at);
CREATE INDEX IF NOT EXISTS idx_cash_entry_tenant_category ON cash_entry(tenant_id, category);
CREATE INDEX IF NOT EXISTS idx_cash_entry_tenant_method   ON cash_entry(tenant_id, method);

-- RLS + FORCE + policy (idempotente).
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['cash_session','cash_entry']
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

GRANT SELECT, INSERT, UPDATE, DELETE ON cash_session TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON cash_entry   TO app_user;

-- Despesas fixas: modelo (nome + valor) para lançar despesa/sangria em um toque.
-- É PRESET, não agendador — nada entra no livro caixa sem alguém confirmar.
-- Tabela própria (não array em settings) porque jsonb sincronizaria como um blob
-- só e o offline perderia modelos criados em paralelo. `amount = 0` = valor varia.
CREATE TABLE IF NOT EXISTS cash_expense_template (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  name        text NOT NULL,
  amount      numeric(14,2) NOT NULL DEFAULT 0,
  category    text NOT NULL DEFAULT 'despesa',
  method      text,
  status      text NOT NULL DEFAULT 'active',
  created_by  uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT cash_expense_template_name_chk     CHECK (length(btrim(name)) > 0),
  CONSTRAINT cash_expense_template_amount_chk   CHECK (amount >= 0),
  CONSTRAINT cash_expense_template_category_chk CHECK (category IN ('despesa','sangria')),
  CONSTRAINT cash_expense_template_method_chk   CHECK (method IS NULL OR method IN ('pix','dinheiro','cartao_credito','cartao_debito','outro')),
  CONSTRAINT cash_expense_template_status_chk   CHECK (status IN ('active','disabled'))
);

-- Unique só entre ativos: "Aluguel" pode ser recriado depois de desativado.
CREATE UNIQUE INDEX IF NOT EXISTS uq_cash_expense_template_name
  ON cash_expense_template (tenant_id, lower(btrim(name)))
  WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_cash_expense_template_tenant_status
  ON cash_expense_template(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_cash_expense_template_tenant_updated
  ON cash_expense_template(tenant_id, updated_at);

DO $$
BEGIN
  ALTER TABLE cash_expense_template ENABLE ROW LEVEL SECURITY;
  ALTER TABLE cash_expense_template FORCE ROW LEVEL SECURITY;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'cash_expense_template' AND policyname = 'tenant_isolation'
  ) THEN
    CREATE POLICY tenant_isolation ON cash_expense_template
      USING (tenant_id = current_tenant_id())
      WITH CHECK (tenant_id = current_tenant_id());
  END IF;
END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON cash_expense_template TO app_user;

-- Módulo contratado `cashier` — habilitado em trial + pro (como report). is_core=false.
INSERT INTO module (key, name, is_core) VALUES
  ('cashier','Caixa', false)
ON CONFLICT (key) DO NOTHING;

INSERT INTO plan_module (plan_id, module_id)
SELECT pl.id, m.id FROM plan pl JOIN module m ON m.key = 'cashier'
WHERE pl.key IN ('trial','pro')
ON CONFLICT DO NOTHING;

-- Backfill: todo tenant existente ganha o módulo `cashier` habilitado (source 'plan').
INSERT INTO tenant_module (tenant_id, module_id, enabled, source)
SELECT t.id, m.id, true, 'plan'
FROM tenant t CROSS JOIN module m
WHERE m.key = 'cashier'
ON CONFLICT (tenant_id, module_id) DO NOTHING;

-- ============================================================
-- 0031 — Status fiscal (snapshot) na OS/venda — aditivo, idempotente
-- ============================================================
-- A OS dispara a emissão de nota via o módulo Fiscal (service público) e guarda
-- um SNAPSHOT do status fiscal devolvido — só para exibir. O Fiscal continua
-- DONO do dado (autoridade). Pagamento NÃO tem coluna: é derivado do Caixa em
-- runtime. Colunas nullable; RLS/FORCE herdadas da tabela service_order.
ALTER TABLE service_order ADD COLUMN IF NOT EXISTS fiscal_status text;
ALTER TABLE service_order ADD COLUMN IF NOT EXISTS fiscal_external_id text;
ALTER TABLE service_order ADD COLUMN IF NOT EXISTS fiscal_emitted_at timestamptz;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'service_order_fiscal_status_chk') THEN
    ALTER TABLE service_order ADD CONSTRAINT service_order_fiscal_status_chk
      CHECK (fiscal_status IS NULL OR fiscal_status IN ('nao_emitida','processando','emitida','rejeitada'));
  END IF;
END $$;

-- ============================================================
-- 0032 — Módulo `sale` (Venda avulsa / Balcão) — aditivo, idempotente
-- ============================================================
-- Venda de balcão como entidade PRÓPRIA (não é OS). `sale` = cabeçalho (cliente
-- OPCIONAL — balcão pode ser sem cadastro; total; fiscal_status snapshot). `sale_item`
-- = linhas (snapshot do item de estoque). A baixa de estoque é via InventoryService
-- ("aponta, não invade"); o pagamento é DERIVADO do Caixa (a venda não guarda valor
-- pago); a nota é disparada via InvoiceService (Fiscal é dono do status). Cancelamento
-- é LÓGICO (status='canceled'), nunca hard delete. RLS + FORCE. Permissões
-- sale.read/sale.write semeadas e mapeadas (owner/gerente/caixa).

CREATE TABLE IF NOT EXISTS sale (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  number             text NOT NULL,                  -- ex.: 'VND-0001' (único por tenant)
  customer_id        uuid,                            -- ponteiro (customers) — NULLABLE (balcão s/ cadastro)
  customer_name      text,                            -- snapshot (nullable)
  status             text NOT NULL DEFAULT 'active',  -- 'active' | 'canceled'
  total              numeric(14,2) NOT NULL DEFAULT 0,
  fiscal_status      text,                            -- snapshot do status fiscal (Fiscal é dono)
  fiscal_external_id text,
  fiscal_emitted_at  timestamptz,
  created_by         uuid,
  canceled_by        uuid,
  canceled_at        timestamptz,                     -- estorno lógico (nunca hard delete)
  canceled_reason    text,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT sale_status_chk CHECK (status IN ('active','canceled')),
  CONSTRAINT sale_fiscal_status_chk
    CHECK (fiscal_status IS NULL OR fiscal_status IN ('nao_emitida','processando','emitida','rejeitada'))
);

CREATE INDEX IF NOT EXISTS idx_sale_tenant_status   ON sale(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_sale_tenant_customer ON sale(tenant_id, customer_id);
CREATE INDEX IF NOT EXISTS idx_sale_tenant_created  ON sale(tenant_id, created_at);
CREATE UNIQUE INDEX IF NOT EXISTS uq_sale_tenant_number ON sale(tenant_id, number);

CREATE TABLE IF NOT EXISTS sale_item (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  sale_id           uuid NOT NULL REFERENCES sale(id) ON DELETE CASCADE,
  kind              text NOT NULL,                 -- 'product' | 'service'
  inventory_item_id uuid,                           -- ponteiro (inventory) — null = avulso
  name              text NOT NULL,                  -- snapshot
  quantity          numeric(14,3) NOT NULL DEFAULT 1,
  unit_price        numeric(14,2) NOT NULL DEFAULT 0,
  subtotal          numeric(14,2) NOT NULL DEFAULT 0,
  created_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT sale_item_kind_chk CHECK (kind IN ('product','service'))
);

CREATE INDEX IF NOT EXISTS idx_sale_item_tenant_sale ON sale_item(tenant_id, sale_id);

-- RLS + FORCE + policy (idempotente).
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['sale','sale_item']
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

GRANT SELECT, INSERT, UPDATE, DELETE ON sale      TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON sale_item TO app_user;

-- Permissões do módulo (catálogo global) + mapeamento nos cargos.
INSERT INTO permission (key, name) VALUES
  ('sale.read','Ver vendas'), ('sale.write','Registrar vendas')
ON CONFLICT (key) DO NOTHING;

-- owner: re-grant garante que ganhe as permissões novas também.
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r, permission p WHERE r.key = 'owner'
ON CONFLICT DO NOTHING;

-- gerente: todas, exceto billing.manage.
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r, permission p
WHERE r.key = 'gerente' AND p.key <> 'billing.manage'
ON CONFLICT DO NOTHING;

-- caixa: vendas (operador do balcão).
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON p.key IN ('sale.read','sale.write')
WHERE r.key = 'caixa'
ON CONFLICT DO NOTHING;

-- Módulo contratado `sale` — habilitado em trial + pro (como cashier/report). is_core=false.
INSERT INTO module (key, name, is_core) VALUES
  ('sale','Vendas', false)
ON CONFLICT (key) DO NOTHING;

INSERT INTO plan_module (plan_id, module_id)
SELECT pl.id, m.id FROM plan pl JOIN module m ON m.key = 'sale'
WHERE pl.key IN ('trial','pro')
ON CONFLICT DO NOTHING;

-- Backfill: todo tenant existente ganha o módulo `sale` habilitado (source 'plan').
INSERT INTO tenant_module (tenant_id, module_id, enabled, source)
SELECT t.id, m.id, true, 'plan'
FROM tenant t CROSS JOIN module m
WHERE m.key = 'sale'
ON CONFLICT (tenant_id, module_id) DO NOTHING;

-- ============================================================
-- 0031_offline_sync — Sincronização offline-first — aditivo, idempotente
-- ============================================================
-- Caixa por dispositivo (device_id + índice único já refletidos acima, junto da
-- criação de cash_session). `updated_at` em service_order_item/cash_entry (faltava
-- nessas duas) + trigger genérico `orbix_set_updated_at()` aplicado nas 7 tabelas
-- que o front offline sincroniza (versão p/ resolução de conflito/replay). `sync_mutation`
-- é a tabela de idempotência do push: cada mutação do cliente (client_mutation_id) só
-- é aplicada uma vez por (tenant, autor); guarda o resultado (applied|discarded|error)
-- p/ o cliente saber o que aconteceu num retry. RLS + FORCE como toda tabela tenant-scoped.

ALTER TABLE service_order_item ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE cash_entry        ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE OR REPLACE FUNCTION orbix_set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END $$;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['customer','subject','inventory_item','service_order',
                           'service_order_item','cash_session','cash_entry'] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%s_updated_at ON %I', t, t);
    EXECUTE format('CREATE TRIGGER trg_%s_updated_at BEFORE UPDATE ON %I
                    FOR EACH ROW EXECUTE FUNCTION orbix_set_updated_at()', t, t);
  END LOOP;
END $$;

CREATE TABLE IF NOT EXISTS sync_mutation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  author_user_id uuid NOT NULL,
  client_mutation_id uuid NOT NULL,
  entity text NOT NULL,
  op text NOT NULL,
  result text NOT NULL,               -- applied | discarded | error
  error_message text,
  entity_id uuid,
  applied_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_sync_mutation UNIQUE (tenant_id, author_user_id, client_mutation_id)
);
CREATE INDEX IF NOT EXISTS idx_sync_mutation_tenant ON sync_mutation(tenant_id);
ALTER TABLE sync_mutation ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_mutation FORCE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='sync_mutation') THEN
    CREATE POLICY tenant_isolation ON sync_mutation
      USING (tenant_id = current_tenant_id())
      WITH CHECK (tenant_id = current_tenant_id());
  END IF;
END $$;
GRANT SELECT, INSERT, UPDATE, DELETE ON sync_mutation TO app_user;

-- ============================================================
-- 0034 — consulta de placas (API Placas): cache global + cota mensal (sem RLS)
-- ============================================================
-- Dado público de referência (placa→veículo) compartilhado entre todos os
-- tenants + contador da cota mensal da plataforma no provedor. Padrão
-- catalog_product: globais, sem tenant_id, sem RLS — só GRANT ao app_user.
CREATE TABLE IF NOT EXISTS plate_cache (
  plate      text PRIMARY KEY,              -- normalizada: ABC1234 / ABC1D23
  payload    jsonb NOT NULL,                -- PlateHit normalizado (não o raw)
  source     text NOT NULL DEFAULT 'apiplacas',
  fetched_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON plate_cache TO app_user;

CREATE TABLE IF NOT EXISTS plate_lookup_usage (
  period     text PRIMARY KEY,              -- 'YYYY-MM' (UTC)
  count      integer NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON plate_lookup_usage TO app_user;

-- ============================================================
-- 0035 — dados da consulta por placa no veículo (subject)
-- ============================================================
-- Colunas EXCLUSIVAS da consulta externa: guardam o retorno completo do
-- provedor (bloco técnico, FIPE, equivalente) sem misturar com `attributes`,
-- que é o que o usuário digita/edita no cadastro. Nullable de propósito: o
-- veículo cadastrado à mão simplesmente não tem estes dados.
ALTER TABLE subject ADD COLUMN IF NOT EXISTS plate_data    jsonb;
ALTER TABLE subject ADD COLUMN IF NOT EXISTS plate_data_at timestamptz;

-- ============================================================
-- 0036 — Desconto na venda de balcão — aditivo, idempotente
-- ============================================================
-- `total` continua sendo o valor A PAGAR (já com o desconto aplicado), porque é
-- ele que o caixa recebe e o Fiscal emite. `discount` fica ao lado como registro
-- do que foi concedido — sem isso não há como saber que houve desconto, nem
-- quanto se deu ao longo do mês.
ALTER TABLE sale
  ADD COLUMN IF NOT EXISTS discount numeric(14,2) NOT NULL DEFAULT 0;

ALTER TABLE sale DROP CONSTRAINT IF EXISTS sale_discount_chk;
ALTER TABLE sale ADD CONSTRAINT sale_discount_chk CHECK (discount >= 0);

-- ============================================================
-- 0037 — Caixa sem exigir sessão, para todos os tenants — DADOS, idempotente
-- ============================================================
-- O default do código já é `false` (`DEFAULT_CASHIER_CONFIG`), mas o valor
-- SALVO em `tenant_module.settings` vence o default: tenants criados antes da
-- mudança continuariam presos na cerimônia de abrir/fechar. Este backfill os
-- alinha. Sobrescreve quem tinha `true` de propósito — é decisão de produto; a
-- conferência de gaveta se reativa em Configurações › Caixa.
-- ATENÇÃO ao `jsonb_set`: ele NÃO cria níveis intermediários (só a última chave),
-- então em `settings` vazio/nulo o caminho `{cashier,requireOpenSession}` era
-- ignorado e o UPDATE não surtia efeito — além de reescrever a linha toda rodada.
-- Daí o merge de objeto (`||`), que constrói o nível `cashier` quando falta.
UPDATE tenant_module AS tm
SET settings = COALESCE(tm.settings, '{}'::jsonb)
               || jsonb_build_object(
                    'cashier',
                    COALESCE(tm.settings -> 'cashier', '{}'::jsonb)
                      || jsonb_build_object('requireOpenSession', false)
                  )
FROM module AS m
WHERE m.id = tm.module_id
  AND m.key = 'cashier'
  -- Só o que ainda não está `false`: mantém o UPDATE idempotente (2ª rodada = 0
  -- linhas) e evita reescrever WAL sem motivo.
  AND COALESCE(tm.settings #> '{cashier,requireOpenSession}', 'null'::jsonb)
      IS DISTINCT FROM 'false'::jsonb;

-- ============================================================
-- 0039 — Módulo `expenses` (Despesas / lembrete de pagamento) — aditivo, idempotente
-- ============================================================
-- Onde a cliente registra O QUE tem que pagar, QUANDO, QUANTO, se REPETE todo mês
-- e se já FOI PAGO. Espelha `prisma/migrations/0039_despesas/migration.sql`.
--
--   expense_category   — o rótulo (nome + ícone + cor), editável pelo tenant.
--   expense_recurrence — a REGRA ("todo dia 10, Aluguel, R$ 2.500").
--   expense            — a CONTA de um vencimento (venceu em 10/09, foi paga tal dia).
--
-- A regra não é a conta: separadas, dá para mudar o valor de UM mês (a luz veio
-- mais cara) sem reescrever o histórico, e parar a regra sem apagar o que já foi
-- pago. Mesma lógica do snapshot histórico da OS (regra 2).
CREATE TABLE IF NOT EXISTS expense_category (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id  uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  name       text NOT NULL,
  -- Chave SIMBÓLICA ('aluguel', 'energia'…), não codepoint: o Flutter faz
  -- tree-shake dos ícones e um IconData montado em runtime a partir de número
  -- vindo do banco vira quadrado vazio no release. O front mapeia chave→const.
  icon       text NOT NULL DEFAULT 'outros',
  -- Hex #RRGGBB. Cor da CATEGORIA (identidade); não é a cor de STATUS
  -- (pago/a pagar/vencido), que é derivada e vive no tema.
  color      text NOT NULL DEFAULT '#6B7280',
  -- 0041: esta categoria tem FORNECEDOR do outro lado? Peças e manutenção sim;
  -- aluguel, imposto e salário não. É o que decide se o cadastro de despesa
  -- oferece o campo — a cliente cria categorias próprias, então whitelist no app
  -- erraria todas elas.
  tracks_supplier boolean NOT NULL DEFAULT false,
  status     text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT expense_category_name_chk   CHECK (length(btrim(name)) > 0),
  CONSTRAINT expense_category_color_chk  CHECK (color ~ '^#[0-9A-Fa-f]{6}$'),
  CONSTRAINT expense_category_status_chk CHECK (status IN ('active','disabled'))
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_expense_category_name
  ON expense_category (tenant_id, lower(btrim(name)))
  WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_expense_category_tenant_updated
  ON expense_category(tenant_id, updated_at);

CREATE TABLE IF NOT EXISTS expense_recurrence (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  description   text NOT NULL,
  -- 0 = "o valor varia" (conta de luz). Herdado do `cash_expense_template`:
  -- evita um segundo conceito de "sem valor" (NULL) para a mesma ideia.
  amount        numeric(14,2) NOT NULL DEFAULT 0,
  category_id   uuid REFERENCES expense_category(id) ON DELETE SET NULL,
  frequency     text NOT NULL DEFAULT 'monthly',
  -- 1..31. Mês curto encurta o dia (31 em fevereiro → 28/29); quem resolve é o
  -- gerador — o dia pedido continua gravado como pedido.
  day_of_month  smallint NOT NULL DEFAULT 1,
  month_of_year smallint,
  method        text,
  notes         text,
  starts_on     date NOT NULL DEFAULT CURRENT_DATE,
  ends_on       date,
  -- Até onde a esteira já materializou contas. NULL = nada gerado ainda.
  generated_through date,
  status        text NOT NULL DEFAULT 'active',
  created_by    uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT expense_recurrence_desc_chk   CHECK (length(btrim(description)) > 0),
  CONSTRAINT expense_recurrence_amount_chk CHECK (amount >= 0),
  CONSTRAINT expense_recurrence_freq_chk   CHECK (frequency IN ('monthly','yearly')),
  CONSTRAINT expense_recurrence_dom_chk    CHECK (day_of_month BETWEEN 1 AND 31),
  CONSTRAINT expense_recurrence_moy_chk    CHECK (month_of_year IS NULL OR month_of_year BETWEEN 1 AND 12),
  CONSTRAINT expense_recurrence_yearly_chk CHECK (frequency <> 'yearly' OR month_of_year IS NOT NULL),
  CONSTRAINT expense_recurrence_method_chk CHECK (method IS NULL OR method IN ('pix','dinheiro','cartao_credito','cartao_debito','outro')),
  CONSTRAINT expense_recurrence_ends_chk   CHECK (ends_on IS NULL OR ends_on >= starts_on),
  CONSTRAINT expense_recurrence_status_chk CHECK (status IN ('active','disabled'))
);

CREATE INDEX IF NOT EXISTS idx_expense_recurrence_tenant_status
  ON expense_recurrence(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_expense_recurrence_tenant_updated
  ON expense_recurrence(tenant_id, updated_at);

CREATE TABLE IF NOT EXISTS expense (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  description   text NOT NULL,
  -- 0 = "valor a confirmar": a conta existe e cobra atenção antes de o boleto
  -- chegar. O app pergunta o valor na hora de marcar como paga.
  amount        numeric(14,2) NOT NULL DEFAULT 0,
  -- `date` e não `timestamptz`: vencimento é dia civil. Instante faria a conta
  -- "mudar de dia" conforme o fuso de quem lê.
  due_date      date NOT NULL,
  category_id   uuid REFERENCES expense_category(id) ON DELETE SET NULL,
  -- Regra que gerou esta conta (NULL = avulsa). SET NULL para que desistir da
  -- regra não apague o que já foi pago.
  recurrence_id uuid REFERENCES expense_recurrence(id) ON DELETE SET NULL,
  -- Ocorrência que esta linha representa: chave da idempotência da esteira —
  -- rodar o gerador duas vezes não duplica o aluguel de setembro.
  occurrence_on date,
  -- ÚNICO fato gravado sobre pagamento. "pago / a pagar / vence em breve /
  -- vencido" é DERIVADO daqui + due_date + hoje. Status materializado exigiria
  -- job diário só para envelhecer linha, e ficaria errado entre execuções.
  paid_at       timestamptz,
  -- Pode divergir de `amount` (juros, desconto): o que saiu é o que saiu.
  paid_amount   numeric(14,2),
  paid_method   text,
  -- Ponte com o Caixa: só o ID (regra 1 — "aponta, não invade"). Este módulo
  -- NUNCA lê/escreve `cash_entry`; quem lança é o service público do caixa.
  cash_entry_id uuid,
  notes         text,
  -- Parcelamento (0040): uma dívida, N vencimentos. NÃO é recorrência — a regra é
  -- aberta e repete a MESMA conta; a parcela é uma FATIA de um total conhecido.
  installment_no       smallint,
  installment_total    smallint,
  installment_group_id uuid,
  -- Fornecedor (0040): SNAPSHOT de quem cobrou, não FK para cadastro (que é
  -- módulo próprio, no backlog). Mesmo padrão da OS (regra 2). Só dígitos:
  -- 14 = CNPJ, 11 = CPF do autônomo.
  supplier_name text,
  supplier_doc  text,
  status        text NOT NULL DEFAULT 'active',
  created_by    uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT expense_desc_chk        CHECK (length(btrim(description)) > 0),
  CONSTRAINT expense_amount_chk      CHECK (amount >= 0),
  CONSTRAINT expense_paid_amount_chk CHECK (paid_amount IS NULL OR paid_amount >= 0),
  CONSTRAINT expense_method_chk      CHECK (paid_method IS NULL OR paid_method IN ('pix','dinheiro','cartao_credito','cartao_debito','outro')),
  CONSTRAINT expense_status_chk      CHECK (status IN ('active','canceled')),
  CONSTRAINT expense_occurrence_chk  CHECK (recurrence_id IS NULL OR occurrence_on IS NOT NULL)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_expense_recurrence_occurrence
  ON expense (tenant_id, recurrence_id, occurrence_on)
  WHERE recurrence_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_expense_tenant_due
  ON expense(tenant_id, due_date);
CREATE INDEX IF NOT EXISTS idx_expense_tenant_open
  ON expense(tenant_id, due_date)
  WHERE paid_at IS NULL AND status = 'active';
CREATE INDEX IF NOT EXISTS idx_expense_tenant_category
  ON expense(tenant_id, category_id);
CREATE INDEX IF NOT EXISTS idx_expense_tenant_updated
  ON expense(tenant_id, updated_at);

-- 0041 — a categoria diz se tem fornecedor (pega banco já existente).
ALTER TABLE expense_category
  ADD COLUMN IF NOT EXISTS tracks_supplier boolean NOT NULL DEFAULT false;
-- Backfill pela CHAVE DE ÍCONE (o nome é editável pela cliente; a chave não).
UPDATE expense_category SET tracks_supplier = true
 WHERE icon IN ('fornecedor','manutencao') AND tracks_supplier = false;

-- 0040 — parcelas + fornecedor. Os ALTER pegam o banco JÁ EXISTENTE (o
-- CREATE TABLE acima só vale para banco novo, e `IF NOT EXISTS` não adiciona
-- coluna a tabela que já está lá).
ALTER TABLE expense ADD COLUMN IF NOT EXISTS installment_no       smallint;
ALTER TABLE expense ADD COLUMN IF NOT EXISTS installment_total    smallint;
ALTER TABLE expense ADD COLUMN IF NOT EXISTS installment_group_id uuid;
ALTER TABLE expense ADD COLUMN IF NOT EXISTS supplier_name        text;
ALTER TABLE expense ADD COLUMN IF NOT EXISTS supplier_doc         text;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'expense_installment_chk') THEN
    ALTER TABLE expense ADD CONSTRAINT expense_installment_chk CHECK (
      (installment_no IS NULL AND installment_total IS NULL AND installment_group_id IS NULL)
      OR (
        installment_no IS NOT NULL AND installment_total IS NOT NULL
        AND installment_group_id IS NOT NULL
        AND installment_total BETWEEN 2 AND 48
        AND installment_no BETWEEN 1 AND installment_total
      )
    );
  END IF;
  -- Avulsa XOR fixa XOR parcelada: deixar a exclusão só na UI permitiria criar
  -- pelo replay do sync uma conta que é as duas coisas.
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'expense_kind_chk') THEN
    ALTER TABLE expense ADD CONSTRAINT expense_kind_chk
      CHECK (recurrence_id IS NULL OR installment_group_id IS NULL);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'expense_supplier_doc_chk') THEN
    ALTER TABLE expense ADD CONSTRAINT expense_supplier_doc_chk
      CHECK (supplier_doc IS NULL OR supplier_doc ~ '^[0-9]{11}$|^[0-9]{14}$');
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_expense_tenant_installment_group
  ON expense(tenant_id, installment_group_id)
  WHERE installment_group_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_expense_tenant_supplier
  ON expense(tenant_id, supplier_doc)
  WHERE supplier_doc IS NOT NULL;

-- Alarga o CHECK do caixa para aceitar a origem 'expense' em banco já existente
-- (o CREATE TABLE do cash_entry acima já nasce com ela). Relaxar constraint não
-- invalida linha nenhuma.
ALTER TABLE cash_entry DROP CONSTRAINT IF EXISTS cash_entry_sale_kind_chk;
ALTER TABLE cash_entry ADD CONSTRAINT cash_entry_sale_kind_chk
  CHECK (sale_kind IS NULL OR sale_kind IN ('os','sale','expense'));

-- 0043 — categoria padrão "Produto" (compra de mercadoria: peça, óleo, material
-- de consumo). Separada de "Fornecedor", que é sobre QUEM cobra e não sobre o que
-- foi comprado. `tracks_supplier` ligado: compra de produto sempre tem alguém do
-- outro lado, e é o caso em que a consulta de CNPJ serve.
--
-- Só para tenant que JÁ abriu o módulo (já tem categorias): quem nunca abriu
-- recebe a lista completa, com Produto, na primeira listagem. O NOT EXISTS por
-- nome respeita quem já criou a sua à mão.
INSERT INTO expense_category (tenant_id, name, icon, color, tracks_supplier)
SELECT t.id, 'Produto', 'produto', '#0EA5E9', true
  FROM tenant t
 WHERE NOT EXISTS (
   SELECT 1 FROM expense_category c
    WHERE c.tenant_id = t.id
      AND lower(btrim(c.name)) = 'produto'
      AND c.status = 'active'
 )
   AND EXISTS (SELECT 1 FROM expense_category c2 WHERE c2.tenant_id = t.id);

-- 0042 — backfill da ORIGEM nos lançamentos de despesa antigos. O vínculo já
-- existia em `expense.cash_entry_id`, só no sentido oposto; sem isto metade do
-- extrato seria clicável e a outra não. Só onde a origem está NULA (nunca
-- sobrescreve 'os'/'sale') e com o tenant conferido.
UPDATE cash_entry ce
   SET sale_kind = 'expense', sale_id = e.id
  FROM expense e
 WHERE e.cash_entry_id = ce.id
   AND ce.sale_kind IS NULL
   AND ce.tenant_id = e.tenant_id;


DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['expense_category','expense_recurrence','expense'] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', t);
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies WHERE tablename = t AND policyname = 'tenant_isolation'
    ) THEN
      EXECUTE format(
        'CREATE POLICY tenant_isolation ON %I USING (tenant_id = current_tenant_id()) WITH CHECK (tenant_id = current_tenant_id())',
        t
      );
    END IF;
  END LOOP;
END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON expense_category   TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON expense_recurrence TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON expense            TO app_user;

INSERT INTO module (key, name, is_core) VALUES
  ('expenses','Despesas', false)
ON CONFLICT (key) DO NOTHING;

INSERT INTO plan_module (plan_id, module_id)
SELECT pl.id, m.id FROM plan pl JOIN module m ON m.key = 'expenses'
WHERE pl.key IN ('trial','pro')
ON CONFLICT DO NOTHING;

INSERT INTO tenant_module (tenant_id, module_id, enabled, source)
SELECT t.id, m.id, true, 'plan'
FROM tenant t CROSS JOIN module m
WHERE m.key = 'expenses'
ON CONFLICT (tenant_id, module_id) DO NOTHING;

-- Reaproveita `finance.read`/`finance.write` (semeadas na 0004, sem consumidor):
-- pagar contas É "financeiro"; criar `expense.*` seria um segundo vocabulário
-- para o mesmo conceito. `caixa` vê mas não mexe — quem opera a gaveta não
-- decide contas.
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON p.key IN ('finance.read','finance.write')
WHERE r.key IN ('owner','gerente')
ON CONFLICT DO NOTHING;

INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON p.key = 'finance.read'
WHERE r.key = 'caixa'
ON CONFLICT DO NOTHING;

-- Categorias padrão por tenant. Tenant novo recebe as mesmas no primeiro acesso
-- ao módulo (o service semeia, idempotente) — assim o registro de tenant não
-- precisa conhecer `expenses`.
INSERT INTO expense_category (tenant_id, name, icon, color)
SELECT t.id, c.name, c.icon, c.color
FROM tenant t
CROSS JOIN (VALUES
  ('Aluguel',     'aluguel',     '#F97316'),
  ('Energia',     'energia',     '#EAB308'),
  ('Água',        'agua',        '#38BDF8'),
  ('Internet',    'internet',    '#8B5CF6'),
  ('Telefone',    'telefone',    '#06B6D4'),
  ('Impostos',    'impostos',    '#EF4444'),
  ('Fornecedor',  'fornecedor',  '#10B981'),
  ('Salários',    'salarios',    '#3B82F6'),
  ('Manutenção',  'manutencao',  '#A16207'),
  ('Outros',      'outros',      '#6B7280')
) AS c(name, icon, color)
ON CONFLICT DO NOTHING;

-- Modelos de despesa fixa do Caixa (0038) → regra de recorrência. Só
-- `category='despesa'`: modelo de SANGRIA fica onde está — sangria é retirada da
-- gaveta, não conta a pagar (não tem vencimento nem "foi pago").
-- `day_of_month = 1` porque o modelo antigo não guardava vencimento: é o palpite
-- honesto, e a cliente ajusta.
INSERT INTO expense_recurrence
  (tenant_id, description, amount, category_id, frequency, day_of_month, method,
   starts_on, status, created_by, created_at)
SELECT
  tpl.tenant_id,
  tpl.name,
  tpl.amount,
  (SELECT c.id FROM expense_category c
    WHERE c.tenant_id = tpl.tenant_id AND c.icon = 'outros' AND c.status = 'active'
    LIMIT 1),
  'monthly',
  1,
  tpl.method,
  CURRENT_DATE,
  tpl.status,
  tpl.created_by,
  tpl.created_at
FROM cash_expense_template tpl
WHERE tpl.category = 'despesa'
  AND NOT EXISTS (
    SELECT 1 FROM expense_recurrence r
    WHERE r.tenant_id = tpl.tenant_id
      AND lower(btrim(r.description)) = lower(btrim(tpl.name))
  );

-- expenses_find_recurrences_to_extend (SECURITY DEFINER)
-- O job diário da esteira varre TODOS os tenants — exatamente o que a RLS
-- impede para o `app_user`. Mesmo desenho de `billing_find_expired_trials`:
-- roda como o dono e devolve só PONTEIROS (tenant_id + id da regra); o job entra
-- em cada tenant com `runWithTenant` e as escritas voltam a passar pela RLS.
-- Ponteiro em vez da linha inteira para a função não virar porta lateral de
-- leitura entre tenants.
CREATE OR REPLACE FUNCTION expenses_find_recurrences_to_extend(p_ate date)
RETURNS TABLE (tenant_id uuid, recurrence_id uuid)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT r.tenant_id, r.id
  FROM expense_recurrence r
  WHERE r.status = 'active'
    AND (r.generated_through IS NULL OR r.generated_through < p_ate)
    AND (r.ends_on IS NULL OR r.ends_on >= CURRENT_DATE)
  ORDER BY r.tenant_id, r.id
$$;

REVOKE ALL ON FUNCTION expenses_find_recurrences_to_extend(date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION expenses_find_recurrences_to_extend(date) TO app_user;

-- ============================================================
-- 0045 — Parcelamento de fiado (receivable_installment) — aditivo
-- ============================================================
CREATE TABLE IF NOT EXISTS receivable_installment (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  sale_kind   text NOT NULL,
  sale_id     uuid NOT NULL,
  amount      numeric(14,2) NOT NULL CHECK (amount > 0),
  due_date    date NOT NULL,
  paid_at     timestamptz,
  entry_id    uuid REFERENCES cash_entry(id) ON DELETE SET NULL,
  notes       text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ri_sale_kind_chk CHECK (sale_kind IN ('os','sale'))
);

CREATE INDEX IF NOT EXISTS idx_ri_tenant_sale   ON receivable_installment(tenant_id, sale_kind, sale_id);
CREATE INDEX IF NOT EXISTS idx_ri_tenant_due    ON receivable_installment(tenant_id, due_date) WHERE paid_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_ri_tenant_status ON receivable_installment(tenant_id, paid_at);

ALTER TABLE receivable_installment ENABLE ROW LEVEL SECURITY;
ALTER TABLE receivable_installment FORCE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'receivable_installment' AND policyname = 'tenant_isolation'
  ) THEN
    CREATE POLICY tenant_isolation ON receivable_installment
    USING (tenant_id = current_tenant_id())
    WITH CHECK (tenant_id = current_tenant_id());
  END IF;
END $$;

GRANT SELECT, INSERT, UPDATE ON receivable_installment TO app_user;

-- ============================================================
-- 0046 — aposenta o módulo legado `sales`
-- ============================================================
-- O módulo de venda avulsa em uso é `sale` (guard @RequiresModule('sale'));
-- `sales`, semeado pela 0029, ficou órfão. Desligar só o tenant_module (feito
-- mais acima) não bastava: a ligação em plan_module fazia o reconcile religar
-- o módulo a cada assinatura, e ele reaparecia em /me e na sidebar do cliente.
-- A linha em `module` permanece (sem hard delete) — tenant_module aponta nela.
DELETE FROM plan_module pm
USING module m
WHERE m.id = pm.module_id AND m.key = 'sales';

UPDATE tenant_module tm
SET enabled = false
FROM module m
WHERE m.id = tm.module_id AND m.key = 'sales' AND tm.enabled;

-- ============================================================
-- 0048 — Descrição livre da venda de balcão — aditivo, idempotente
-- ============================================================
-- A tela de venda já pedia uma "descrição da venda", mas o texto morria no
-- extrato do caixa: a venda em si não guardava nada, então o comprovante saía
-- sem ele. Quem vende no balcão usa esse campo para escrever a quem entregou
-- ("bateria para o rapaz da Hilux", placa do veículo, número do trator) — é
-- justamente o que se procura meses depois, quando alguém volta reclamando.
--
-- Coluna do núcleo (não `attributes`): descrição livre é conceito universal —
-- qualquer vertical tem venda com observação — e o mesmo raciocínio de 0044
-- (`inventory_item.description`) se aplica aqui.
ALTER TABLE sale ADD COLUMN IF NOT EXISTS description text;

-- ============================================================
-- 0049 — Fiado declarado: título só vira dívida após passar pelo caixa
-- ============================================================
-- Até aqui "fiado" era DERIVADO: `receivables.openTitles` considerava devedora
-- toda OS não cancelada com pago < total. Como a OS nasce `aberta` já com os
-- itens lançados e zero recebido, ela entrava na carteira de cobrança no ato da
-- criação — trabalho em andamento poluindo o que deveria ser só dívida.
--
-- Agora o título aparece no Fiado quando tem saldo E passou pelo caixa. Passar
-- pelo caixa já tem uma prova no banco (lançamento ligado ao título, que faz
-- `pago > 0`); falta a prova do caso "recebeu ZERO e o operador declarou" — que
-- não deixa lançamento nenhum. É esta coluna.
--
-- `timestamptz` e não boolean: quando foi fiado importa para auditoria e para o
-- futuro aging, e null/não-null já responde o booleano.
ALTER TABLE service_order ADD COLUMN IF NOT EXISTS fiado_at timestamptz;
ALTER TABLE sale          ADD COLUMN IF NOT EXISTS fiado_at timestamptz;

-- ------------------------------------------------------------
-- Backfill — SEM ELE dívida real some da tela no dia do deploy
-- ------------------------------------------------------------
-- Todo título hoje visível no Fiado que nunca recebeu um centavo ficaria sem
-- prova de passagem e sumiria. Em produção isso é dinheiro que alguém precisa
-- cobrar. Marcamos como fiado o que hoje é dívida legítima:
--
--   * OS FINALIZADA (`concluida`/`entregue`) com saldo — serviço entregue e não
--     pago é dívida, independentemente de terem passado pelo caixa;
--   * venda de balcão ativa com saldo — venda entregue é sempre dívida;
--   * qualquer título com PLANO DE PARCELAS — parcelar já é declarar fiado, e
--     esse é o único lugar onde essa prova é considerada (em runtime ela é
--     redundante: quem parcela hoje ou lançou no caixa, ou terá `fiado_at`).
--
-- OS `aberta` com saldo fica DE FORA de propósito: é exatamente o caso que o
-- usuário reportou como bug — OS em andamento aparecendo como fiado.
--
-- O saldo é calculado EXATAMENTE como o runtime (`sumPaidForSale`): entradas
-- (`direction='in'`) não estornadas, casadas por `sale_id` (uuid é único, por
-- isso o caixa não filtra `sale_kind`). Divergir aqui trataria o mesmo título
-- de um jeito na migration e de outro na tela.
--
-- `WHERE fiado_at IS NULL` em tudo: idempotente, seguro no baseline canônico e
-- nunca sobrescreve uma declaração real feita depois.

-- OS finalizadas com saldo em aberto.
UPDATE service_order o
   SET fiado_at = o.created_at
 WHERE o.fiado_at IS NULL
   AND o.deleted_at IS NULL
   AND o.status IN ('concluida', 'entregue')
   AND COALESCE(o.total, 0) > COALESCE((
         SELECT SUM(e.amount)
           FROM cash_entry e
          WHERE e.tenant_id   = o.tenant_id
            AND e.sale_id     = o.id
            AND e.direction   = 'in'
            AND e.reversed_at IS NULL
       ), 0);

-- Vendas de balcão ativas com saldo em aberto.
UPDATE sale s
   SET fiado_at = s.created_at
 WHERE s.fiado_at IS NULL
   AND s.status = 'active'
   AND COALESCE(s.total, 0) > COALESCE((
         SELECT SUM(e.amount)
           FROM cash_entry e
          WHERE e.tenant_id   = s.tenant_id
            AND e.sale_id     = s.id
            AND e.direction   = 'in'
            AND e.reversed_at IS NULL
       ), 0);

-- Títulos com plano de parcelas: parcelar é declarar fiado.
UPDATE service_order o
   SET fiado_at = o.created_at
 WHERE o.fiado_at IS NULL
   AND EXISTS (
         SELECT 1 FROM receivable_installment i
          WHERE i.tenant_id = o.tenant_id
            AND i.sale_kind = 'os'
            AND i.sale_id   = o.id
       );

UPDATE sale s
   SET fiado_at = s.created_at
 WHERE s.fiado_at IS NULL
   AND EXISTS (
         SELECT 1 FROM receivable_installment i
          WHERE i.tenant_id = s.tenant_id
            AND i.sale_kind = 'sale'
            AND i.sale_id   = s.id
       );
