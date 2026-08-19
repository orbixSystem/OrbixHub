-- ============================================================
-- 0049 — Fiado declarado: título só vira dívida após passar pelo caixa
-- ============================================================
-- Até aqui "fiado" era DERIVADO: `receivables.openTitles` considerava devedora
-- toda OS não cancelada com pago < total. Como a OS nasce `aberta` já com os
-- itens lançados e zero recebido, ela entrava na carteira de cobrança no ato da
-- criação — trabalho em andamento poluindo o que deveria ser só dívida.
--
-- Agora o título aparece no Fiado quando tem saldo E passou pelo caixa. Passar
-- pelo caixa já tem uma prova no banco (lançamento ligado ao título, que faz
-- `pago > 0`); falta a prova do caso "recebeu ZERO e o operador declarou" — que
-- não deixa lançamento nenhum. É esta coluna.
--
-- `timestamptz` e não boolean: quando foi fiado importa para auditoria e para o
-- futuro aging, e null/não-null já responde o booleano.
ALTER TABLE service_order ADD COLUMN IF NOT EXISTS fiado_at timestamptz;
ALTER TABLE sale          ADD COLUMN IF NOT EXISTS fiado_at timestamptz;

-- ------------------------------------------------------------
-- Backfill — SEM ELE dívida real some da tela no dia do deploy
-- ------------------------------------------------------------
-- Todo título hoje visível no Fiado que nunca recebeu um centavo ficaria sem
-- prova de passagem e sumiria. Em produção isso é dinheiro que alguém precisa
-- cobrar. Marcamos como fiado o que hoje é dívida legítima:
--
--   * OS FINALIZADA (`concluida`/`entregue`) com saldo — serviço entregue e não
--     pago é dívida, independentemente de terem passado pelo caixa;
--   * venda de balcão ativa com saldo — venda entregue é sempre dívida;
--   * qualquer título com PLANO DE PARCELAS — parcelar já é declarar fiado, e
--     esse é o único lugar onde essa prova é considerada (em runtime ela é
--     redundante: quem parcela hoje ou lançou no caixa, ou terá `fiado_at`).
--
-- OS `aberta` com saldo fica DE FORA de propósito: é exatamente o caso que o
-- usuário reportou como bug — OS em andamento aparecendo como fiado.
--
-- O saldo é calculado EXATAMENTE como o runtime (`sumPaidForSale`): entradas
-- (`direction='in'`) não estornadas, casadas por `sale_id` (uuid é único, por
-- isso o caixa não filtra `sale_kind`). Divergir aqui trataria o mesmo título
-- de um jeito na migration e de outro na tela.
--
-- `WHERE fiado_at IS NULL` em tudo: idempotente, seguro no baseline canônico e
-- nunca sobrescreve uma declaração real feita depois.

-- OS finalizadas com saldo em aberto.
UPDATE service_order o
   SET fiado_at = o.created_at
 WHERE o.fiado_at IS NULL
   AND o.deleted_at IS NULL
   AND o.status IN ('concluida', 'entregue')
   AND COALESCE(o.total, 0) > COALESCE((
         SELECT SUM(e.amount)
           FROM cash_entry e
          WHERE e.tenant_id   = o.tenant_id
            AND e.sale_id     = o.id
            AND e.direction   = 'in'
            AND e.reversed_at IS NULL
       ), 0);

-- Vendas de balcão ativas com saldo em aberto.
UPDATE sale s
   SET fiado_at = s.created_at
 WHERE s.fiado_at IS NULL
   AND s.status = 'active'
   AND COALESCE(s.total, 0) > COALESCE((
         SELECT SUM(e.amount)
           FROM cash_entry e
          WHERE e.tenant_id   = s.tenant_id
            AND e.sale_id     = s.id
            AND e.direction   = 'in'
            AND e.reversed_at IS NULL
       ), 0);

-- Títulos com plano de parcelas: parcelar é declarar fiado.
UPDATE service_order o
   SET fiado_at = o.created_at
 WHERE o.fiado_at IS NULL
   AND EXISTS (
         SELECT 1 FROM receivable_installment i
          WHERE i.tenant_id = o.tenant_id
            AND i.sale_kind = 'os'
            AND i.sale_id   = o.id
       );

UPDATE sale s
   SET fiado_at = s.created_at
 WHERE s.fiado_at IS NULL
   AND EXISTS (
         SELECT 1 FROM receivable_installment i
          WHERE i.tenant_id = s.tenant_id
            AND i.sale_kind = 'sale'
            AND i.sale_id   = s.id
       );
