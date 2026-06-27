-- ============================================================
-- 0003 — Employees & Settings (aditivo, idempotente)
-- ============================================================

-- membership.status (active|disabled) — nunca apagamos membros, só desativamos
ALTER TABLE membership ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active';
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'membership_status_chk') THEN
    ALTER TABLE membership ADD CONSTRAINT membership_status_chk CHECK (status IN ('active','disabled'));
  END IF;
END $$;

-- tenant.settings (jsonb) — preferências de empresa/branding
ALTER TABLE tenant ADD COLUMN IF NOT EXISTS settings jsonb NOT NULL DEFAULT '{}'::jsonb;

-- Permissões novas (catálogo global). subject.* = objeto de serviço (genérico).
INSERT INTO permission (key, name) VALUES
  ('customer.read','Ver clientes'), ('customer.write','Editar clientes'),
  ('subject.read','Ver objetos'), ('subject.write','Editar objetos'),
  ('os.approve','Aprovar OS'),
  ('tracking.manage','Gerenciar acompanhamento'),
  ('cashier.read','Ver caixa'), ('cashier.write','Operar caixa'),
  ('invoice.issue','Emitir nota'),
  ('finance.read','Ver financeiro'), ('finance.write','Editar financeiro'),
  ('report.read','Ver relatórios'),
  ('settings.manage','Gerenciar configurações')
ON CONFLICT (key) DO NOTHING;

-- Cargos novos (roles globais; decisão "role mínima")
INSERT INTO role (key, name) VALUES
  ('gerente','Gerente'), ('caixa','Caixa / Atendente')
ON CONFLICT (key) DO NOTHING;

-- owner: re-grant garante que ganhe as permissões novas também
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r, permission p WHERE r.key = 'owner'
ON CONFLICT DO NOTHING;

-- gerente: todas, exceto billing.manage
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r, permission p
WHERE r.key = 'gerente' AND p.key <> 'billing.manage'
ON CONFLICT DO NOTHING;

-- mechanic: operacional (inclui as novas customer.*/subject.*/tracking.manage)
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON p.key IN
  ('customer.read','customer.write','subject.read','subject.write',
   'os.read','os.write','inventory.read','tracking.manage')
WHERE r.key = 'mechanic'
ON CONFLICT DO NOTHING;

-- caixa: atendimento + caixa + nota
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON p.key IN
  ('customer.read','customer.write','subject.read','subject.write',
   'os.read','os.write','inventory.read',
   'cashier.read','cashier.write','invoice.issue')
WHERE r.key = 'caixa'
ON CONFLICT DO NOTHING;
