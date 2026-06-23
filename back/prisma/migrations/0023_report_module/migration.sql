-- Módulo `report` (Fase 2 dashboard/relatórios). Aditivo, idempotente.
-- Relatórios = módulo contratável, mas habilitado em TODOS os planos hoje
-- (trial + pro) → grátis agora; paywall futuro = remover de um plano.
-- A permissão `report.read` já existe no catálogo global. Sem tabela nova:
-- o módulo `report` compõe relatórios chamando os services públicos dos outros.
INSERT INTO module (key, name, is_core) VALUES
  ('report','Relatórios', false)
ON CONFLICT (key) DO NOTHING;

INSERT INTO plan_module (plan_id, module_id)
SELECT pl.id, m.id FROM plan pl JOIN module m ON m.key = 'report'
WHERE pl.key IN ('trial','pro')
ON CONFLICT DO NOTHING;

-- Backfill dos tenants existentes: habilita `report` (source 'plan') para que
-- /me.modules já o liste sem precisar trocar de plano. Idempotente.
INSERT INTO tenant_module (tenant_id, module_id, enabled, source)
SELECT t.id, m.id, true, 'plan'
FROM tenant t CROSS JOIN module m
WHERE m.key = 'report'
ON CONFLICT (tenant_id, module_id) DO NOTHING;
