-- Adiciona campos genéricos de equipamento na tabela subject.
-- Aditiva e idempotente: ADD COLUMN IF NOT EXISTS.
ALTER TABLE subject
  ADD COLUMN IF NOT EXISTS tipo         text,
  ADD COLUMN IF NOT EXISTS marca        text,
  ADD COLUMN IF NOT EXISTS modelo       text,
  ADD COLUMN IF NOT EXISTS numero_serie text;
