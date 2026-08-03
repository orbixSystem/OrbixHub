-- ============================================================
-- 0036 — Desconto na venda de balcão — aditivo, idempotente
-- ============================================================
-- `total` continua sendo o valor A PAGAR (já com o desconto aplicado), porque é
-- ele que o caixa recebe e o Fiscal emite. `discount` fica ao lado como registro
-- do que foi concedido — sem isso não há como saber que houve desconto, nem
-- quanto se deu ao longo do mês.
ALTER TABLE sale
  ADD COLUMN IF NOT EXISTS discount numeric(14,2) NOT NULL DEFAULT 0;

-- Desconto negativo seria aumento disfarçado; zero é o caso normal.
ALTER TABLE sale DROP CONSTRAINT IF EXISTS sale_discount_chk;
ALTER TABLE sale ADD CONSTRAINT sale_discount_chk CHECK (discount >= 0);
