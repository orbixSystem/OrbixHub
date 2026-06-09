-- ============================================================
-- 0009 — Subject soft delete (aditivo, idempotente)
-- ============================================================
-- "Excluir" subject (veículo/pet/...) = soft delete (status 'deleted'),
-- distinto de 'archived'. Nunca hard delete (regra de ouro #6).
ALTER TABLE subject DROP CONSTRAINT IF EXISTS subject_status_chk;
ALTER TABLE subject ADD CONSTRAINT subject_status_chk
  CHECK (status IN ('active','archived','deleted'));
