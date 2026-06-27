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
