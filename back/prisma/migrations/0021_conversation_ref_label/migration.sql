-- Conversa: rótulo legível da origem (snapshot genérico). Para conversas de OS
-- guarda o número da OS (ex.: 'OS-0001'), permitindo distinguir, no inbox, dois
-- clientes de mesmo nome. Genérico: qualquer módulo pode preencher ao criar a
-- conversa ("aponta, não invade"; o dono da origem é quem conhece o rótulo).
ALTER TABLE conversation ADD COLUMN IF NOT EXISTS ref_label text;

-- Backfill das conversas de OS já existentes a partir do número da OS.
UPDATE conversation c
   SET ref_label = o.number
  FROM service_order o
 WHERE c.ref_type = 'os'
   AND c.ref_id = o.id
   AND c.ref_label IS NULL;
