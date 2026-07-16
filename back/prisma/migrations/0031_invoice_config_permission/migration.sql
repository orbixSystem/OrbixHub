-- 0031 — permissão invoice.config (configuração fiscal sensível, owner-only).
-- invoice.config — configuração fiscal sensível (owner-only)
INSERT INTO permission (key, name) VALUES
  ('invoice.config','Configurar nota fiscal')
ON CONFLICT (key) DO NOTHING;

INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON p.key = 'invoice.config'
WHERE r.key IN ('owner')
ON CONFLICT DO NOTHING;
