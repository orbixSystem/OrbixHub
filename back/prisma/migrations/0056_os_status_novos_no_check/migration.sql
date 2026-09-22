-- Os 4 status novos da OS nunca chegaram à CHECK do banco.
--
-- O commit que expandiu o workflow (aguardando_pecas, pendente, sem_conserto,
-- a_receber) mexeu na FSM, no DTO e no front — mas não na migration. Resultado
-- em produção: a interface oferece o status, o DTO aceita, o service valida a
-- transição… e o UPDATE bate na constraint. O usuário recebe HTTP 500 e a OS
-- fica exatamente onde estava.
--
-- É a causa das duas reclamações: "muitas requisições dando erro" e "fica
-- sempre como em execucao" — em_execucao é o último status ANTIGO do fluxo, e
-- todo caminho para frente a partir dele passa por um status novo.

-- ---------------------------------------------------------------------------
-- PASSO 1 — normalizar status desconhecidos ANTES de recriar a constraint.
--
-- `ADD CONSTRAINT ... CHECK` VALIDA as linhas existentes: uma única OS com
-- status fora da lista derruba a migration e trava toda a fila de deploy
-- (P3009). Este passo existe para que isso não possa acontecer.
--
-- O alvo declarado é o "em andamento" fantasma (a FSM nunca teve esse valor —
-- 'Em andamento' é só o RÓTULO do grupo simplificado na interface), mas a
-- clausula final cobre qualquer valor inesperado: uma OS parada num status que
-- o app não sabe desenhar já está quebrada para o usuário, e em_execucao é o
-- estado vivo mais próximo — reversível pelo fluxo normal, sem consumir nem
-- devolver estoque por conta própria.
--
-- Nada é reescrito em silêncio: cada linha ajustada ganha um evento na timeline
-- da OS, com o valor ANTIGO preservado na mensagem.
INSERT INTO service_order_event
  (tenant_id, order_id, kind, message, status_snapshot, visible_public)
SELECT
  o.tenant_id,
  o.id,
  'status_change',
  'Status "' || o.status || '" não existe no fluxo e foi corrigido para '
    || '"em_execucao" (migration 0056).',
  'em_execucao',
  false
FROM service_order o
WHERE o.status NOT IN (
  'aberta','aguardando_aprovacao','aprovada','em_execucao','aguardando_pecas',
  'pendente','sem_conserto','concluida','a_receber','entregue','cancelada'
);

UPDATE service_order
SET status = 'em_execucao'
WHERE status NOT IN (
  'aberta','aguardando_aprovacao','aprovada','em_execucao','aguardando_pecas',
  'pendente','sem_conserto','concluida','a_receber','entregue','cancelada'
);

-- ---------------------------------------------------------------------------
-- PASSO 2 — a constraint passa a conhecer os 11 status.
--
-- Aditiva e segura: o conjunto novo é superset do antigo, então nenhuma linha
-- que já era válida vira inválida — e o passo 1 garantiu que não sobrou nenhuma
-- inválida de antes.
ALTER TABLE service_order DROP CONSTRAINT IF EXISTS service_order_status_chk;
ALTER TABLE service_order ADD CONSTRAINT service_order_status_chk
  CHECK (status IN (
    'aberta',
    'aguardando_aprovacao',
    'aprovada',
    'em_execucao',
    'aguardando_pecas',
    'pendente',
    'sem_conserto',
    'concluida',
    'a_receber',
    'entregue',
    'cancelada'
  ));
