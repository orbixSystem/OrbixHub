-- 0035 — dados da consulta por placa no veículo (aditivo, nullable).
-- Colunas EXCLUSIVAS da consulta externa: guardam o retorno completo do
-- provedor (bloco técnico, FIPE, equivalente) sem misturar com `attributes`,
-- que é o que o usuário digita/edita no cadastro. Nullable de propósito: o
-- veículo cadastrado à mão simplesmente não tem estes dados.
ALTER TABLE subject ADD COLUMN IF NOT EXISTS plate_data    jsonb;
ALTER TABLE subject ADD COLUMN IF NOT EXISTS plate_data_at timestamptz;
