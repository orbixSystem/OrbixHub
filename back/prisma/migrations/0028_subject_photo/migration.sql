-- 0028 — Foto do objeto/veículo (subject). Aditivo.
-- Uma foto por subject (avatar do veículo) — armazenada no storage (S3/local);
-- guardamos a url pública + a chave do storage (para remover o binário depois).

ALTER TABLE subject
  ADD COLUMN IF NOT EXISTS photo_url         text,
  ADD COLUMN IF NOT EXISTS photo_storage_key text;
