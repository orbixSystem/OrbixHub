-- 0032 — classificação fiscal em inventory_item (aditivo)
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS ncm            text;
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS cfop           text;
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS origem         text;
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS gtin           text;
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS codigo_servico text;
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS aliquota_iss   numeric(7,2);
