-- Horário de funcionamento por tenant (agenda).
-- 7 linhas por tenant (0=Dom … 6=Sáb), única por (tenant_id, day_of_week).
-- Seed padrão criado em auth.service ao registrar um novo tenant.

CREATE TABLE business_hours (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid        NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  day_of_week  smallint    NOT NULL CHECK (day_of_week BETWEEN 0 AND 6), -- 0=Dom,1=Seg…6=Sáb
  is_open      boolean     NOT NULL DEFAULT true,
  open_time    varchar(5)  NOT NULL DEFAULT '08:00', -- "HH:MM"
  close_time   varchar(5)  NOT NULL DEFAULT '18:00', -- "HH:MM"
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, day_of_week)
);

ALTER TABLE business_hours ENABLE ROW LEVEL SECURITY;
ALTER TABLE business_hours FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON business_hours
  USING (tenant_id = current_tenant_id());

CREATE INDEX idx_business_hours_tenant ON business_hours (tenant_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON business_hours TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON business_hours TO app_migrator;
