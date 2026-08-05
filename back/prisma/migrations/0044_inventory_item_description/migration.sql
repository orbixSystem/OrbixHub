-- ============================================================
-- 0044 — Descrição opcional do item de estoque — aditivo, idempotente
-- ============================================================
-- Falta um campo genérico para "o que é isto" além do nome — o cadastro
-- SIMPLIFICADO de produto (nome, descrição, preço, quantidade, custo) precisa
-- de um lugar para uma observação livre sem forçar o uso de `attributes`
-- (que é para campo ESPECÍFICO da vertical, configurável por tenant). Descrição
-- é conceito universal — qualquer vertical tem produto com descrição opcional —
-- então é coluna do núcleo, não chave dentro do jsonb.
ALTER TABLE inventory_item ADD COLUMN IF NOT EXISTS description text;
