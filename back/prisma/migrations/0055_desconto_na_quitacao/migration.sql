-- ============================================================
-- 0055 — Desconto na quitação — aditiva, idempotente
-- ============================================================
-- Desconto concedido no momento de RECEBER, distinto do desconto de documento
-- que já existe (`sale.discount` / `service_order.discount` abatem o total na
-- criação). Aqui a dívida já existe e o que se perdoa é o SALDO: o documento
-- fica intacto, e o abatimento é atributo do recebimento.
--
-- Fica em `cash_entry` porque ele já é o ponto único por onde todo dinheiro
-- entra — tem sale_id/sale_kind (venda e OS) e relação com
-- receivable_installment (fiado) — e já tem estorno, que passa a reverter o
-- desconto junto, de graça.

ALTER TABLE cash_entry ADD COLUMN IF NOT EXISTS discount        numeric(14,2) NOT NULL DEFAULT 0;
ALTER TABLE cash_entry ADD COLUMN IF NOT EXISTS discount_reason text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'cash_entry_discount_nonneg'
  ) THEN
    ALTER TABLE cash_entry ADD CONSTRAINT cash_entry_discount_nonneg
      CHECK (discount >= 0);
  END IF;
END $$;

-- A constraint antiga `amount > 0` impediria o desconto TOTAL: perdoar a dívida
-- inteira produz amount = 0 e o insert falharia — justamente o caso em que mais
-- se quer o registro. A nova é mais permissiva (toda linha que passava na velha
-- passa nela), e segue barrando o lançamento vazio, que é erro de operação.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'cash_entry_amount_chk') THEN
    ALTER TABLE cash_entry DROP CONSTRAINT cash_entry_amount_chk;
  END IF;
  ALTER TABLE cash_entry ADD CONSTRAINT cash_entry_amount_chk
    CHECK (amount >= 0 AND (amount > 0 OR discount > 0));
END $$;

-- Permissão própria: conceder desconto não é o mesmo que registrar recebimento.
INSERT INTO permission (key, name)
VALUES ('cashier.discount', 'Conceder desconto na quitação')
ON CONFLICT (key) DO NOTHING;

-- Semeada em owner e gerente. `caixa` recebe dinheiro, mas não perdoa dívida.
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id
  FROM role r, permission p
 WHERE r.key IN ('owner', 'gerente') AND p.key = 'cashier.discount'
ON CONFLICT DO NOTHING;
