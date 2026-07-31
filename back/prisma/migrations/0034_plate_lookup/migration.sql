-- 0034 — consulta de placas (API Placas): cache global por placa + contador de
-- cota mensal da plataforma. Aditivo, idempotente. Ambas GLOBAIS, sem RLS
-- (dado público de referência / cota da plataforma — padrão catalog_product).

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
