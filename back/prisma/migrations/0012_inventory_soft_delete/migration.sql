-- 0012 — inventory soft delete (aditivo). deleted_at NULL = ativo; setado = excluído.
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
