-- 0033 — snapshot fiscal em invoice_line (aditivo, nullable; preenchido no Plano 3)
ALTER TABLE invoice_line ADD COLUMN IF NOT EXISTS ncm            text;
ALTER TABLE invoice_line ADD COLUMN IF NOT EXISTS cfop           text;
ALTER TABLE invoice_line ADD COLUMN IF NOT EXISTS unidade        text;
ALTER TABLE invoice_line ADD COLUMN IF NOT EXISTS gtin           text;
ALTER TABLE invoice_line ADD COLUMN IF NOT EXISTS codigo_servico text;
