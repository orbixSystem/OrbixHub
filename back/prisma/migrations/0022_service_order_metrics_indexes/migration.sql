-- Índices p/ a camada de métricas da OS (Fase 1 dashboard). Aditivo, idempotente.
-- As agregações do dashboard/relatório agrupam por técnico (assigned_to) e
-- filtram por período de abertura (opened_at). `(tenant_id, status)` já existe
-- (idx_service_order_tenant_status), então só faltam estes dois.
CREATE INDEX IF NOT EXISTS idx_service_order_tenant_assigned
  ON service_order(tenant_id, assigned_to);
CREATE INDEX IF NOT EXISTS idx_service_order_tenant_opened
  ON service_order(tenant_id, opened_at);
