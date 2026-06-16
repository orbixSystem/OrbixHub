-- 0013 — inventory volta a ter tipo produto|serviço (+ duração p/ serviço). Aditivo.
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS kind text NOT NULL DEFAULT 'product';
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS duration_minutes integer;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='inventory_item_kind_chk') THEN
    ALTER TABLE inventory_item ADD CONSTRAINT inventory_item_kind_chk CHECK (kind IN ('product','service'));
  END IF;
END $$;
