-- Os 4 status novos da OS nunca chegaram à CHECK do banco.
--
-- O commit que expandiu o workflow (aguardando_pecas, pendente, sem_conserto,
-- a_receber) mexeu na FSM, no DTO e no front — mas não na migration. Resultado
-- em produção: a interface oferece o status, o DTO aceita, o service valida a
-- transição… e o INSERT bate na constraint. O usuário recebe HTTP 500 e a OS
-- fica exatamente onde estava.
--
-- É a causa das duas reclamações: "muitas requisições dando erro" e "fica
-- sempre como em execução" — em_execucao é o último status ANTIGO do fluxo, e
-- todos os caminhos para frente a partir dele passam por um status novo.
--
-- Aditiva e segura: o conjunto novo é superset do antigo, então nenhuma linha
-- existente vira inválida e a revalidação não falha.
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
