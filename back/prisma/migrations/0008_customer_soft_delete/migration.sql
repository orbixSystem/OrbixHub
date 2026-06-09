-- ============================================================
-- 0008 — Customer soft delete (aditivo, idempotente)
-- ============================================================
-- "Excluir" cliente = soft delete (status 'deleted'), distinto de 'archived'.
-- Nunca hard delete (regra de ouro #6). Estende o CHECK de status.
ALTER TABLE customer DROP CONSTRAINT IF EXISTS customer_status_chk;
ALTER TABLE customer ADD CONSTRAINT customer_status_chk
  CHECK (status IN ('active','archived','deleted'));
