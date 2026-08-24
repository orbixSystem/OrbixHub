-- ============================================================
-- 0053 — Pedido de reabertura de chamado — aditivo, idempotente
-- ============================================================
-- Antes, uma mensagem do cliente num chamado resolvido o reabria sozinha. Quem
-- fechou perdia o controle do que estava fechado — e fechar é decisão de quem
-- atende. Agora o cliente PEDE, o pedido vira uma situação própria e visível na
-- fila, e reabrir continua sendo um ato da Orbix.
--
-- Só amplia o CHECK: nenhuma linha existente muda de valor.

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'support_ticket_status_chk') THEN
    ALTER TABLE support_ticket DROP CONSTRAINT support_ticket_status_chk;
  END IF;

  ALTER TABLE support_ticket ADD CONSTRAINT support_ticket_status_chk
    CHECK (status IN ('aberto','resolvido','reabertura_solicitada'));
END $$;
