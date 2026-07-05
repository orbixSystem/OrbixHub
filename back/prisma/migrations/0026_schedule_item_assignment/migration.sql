-- Agendamento por item de OS.
-- Cada item pode ter técnico, horário de início, duração estimada (múltiplos de 30min)
-- e horário de fim calculado (start + duration). O conflito é checado pelo service.

ALTER TABLE service_order_item
  ADD COLUMN assigned_to          uuid        REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN scheduled_start      timestamptz,
  ADD COLUMN estimated_duration   integer     CHECK (estimated_duration > 0 AND estimated_duration % 30 = 0), -- minutos
  ADD COLUMN scheduled_end        timestamptz; -- preenchido pelo backend: start + estimated_duration

-- Índice para detecção eficiente de conflito por técnico + sobreposição de horário.
CREATE INDEX idx_soi_assigned_schedule
  ON service_order_item (tenant_id, assigned_to, scheduled_start, scheduled_end)
  WHERE assigned_to IS NOT NULL AND scheduled_start IS NOT NULL AND scheduled_end IS NOT NULL;
