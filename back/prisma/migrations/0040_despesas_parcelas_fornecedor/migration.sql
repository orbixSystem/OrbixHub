-- ============================================================
-- 0040 — Despesas: parcelas, fornecedor e origem no caixa — aditivo, idempotente
-- ============================================================
-- Três coisas, todas pedidas pela cliente sobre contas a pagar de oficina:
--
--   1. PARCELAS  — "comprei o compressor em 6x". Uma dívida, seis vencimentos.
--   2. FORNECEDOR — de quem é a conta, identificado por CNPJ (autopreenchido).
--   3. ORIGEM no caixa — poder clicar no lançamento e chegar na despesa.
--
-- ------------------------------------------------------------
-- 1. Parcelas: TRÊS COLUNAS em `expense`, não tabela nova
-- ------------------------------------------------------------
-- Uma tabela "plano de parcelamento" não teria dado próprio: o total é a soma das
-- irmãs e descrição/fornecedor se repetem. Custaria RLS, entidade de sync e rota
-- de pull novas — sem nada em troca. Como `expense` já é entidade replicada, as
-- parcelas viajam para o offline de graça.
--
-- E parcelamento NÃO é recorrência, apesar de os dois gerarem várias contas:
-- a regra é ABERTA ("todo dia 10, sem fim previsto") e cada ocorrência é a MESMA
-- conta de novo; o parcelamento é FINITO e cada linha é uma FATIA de uma dívida
-- única. Modelar 6x como recorrência com `ends_on` esconderia o total devido e
-- tornaria impossível o rótulo "parcela 2 de 6".
ALTER TABLE expense ADD COLUMN IF NOT EXISTS installment_no       smallint;
ALTER TABLE expense ADD COLUMN IF NOT EXISTS installment_total    smallint;
ALTER TABLE expense ADD COLUMN IF NOT EXISTS installment_group_id uuid;

-- ------------------------------------------------------------
-- 2. Fornecedor: SNAPSHOT na conta, não cadastro de fornecedores
-- ------------------------------------------------------------
-- Cadastro de fornecedores é módulo próprio (backlog do estoque). O que a conta
-- precisa é o RETRATO de quem cobrou — mesmo padrão da OS, que guarda o nome do
-- cliente e a placa de então (regra 2). Se o fornecedor mudar de razão social, a
-- conta de março continua dizendo quem cobrou em março.
--
-- `supplier_doc` guarda só DÍGITOS: 14 = CNPJ, 11 = CPF (autônomo, o eletricista
-- que passou nota). Máscara é assunto da UI, que já tem o formatter.
ALTER TABLE expense ADD COLUMN IF NOT EXISTS supplier_name text;
ALTER TABLE expense ADD COLUMN IF NOT EXISTS supplier_doc  text;

-- CHECKs em bloco guardado: `ADD CONSTRAINT` não aceita IF NOT EXISTS, e repetir
-- a migration não pode falhar. Todos aceitam a linha ANTIGA (colunas nulas), que
-- é o que existe em banco já povoado — senão o ALTER não passaria na validação.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'expense_installment_chk') THEN
    ALTER TABLE expense ADD CONSTRAINT expense_installment_chk CHECK (
      -- Ou não é parcelada (as três nulas), ou é completa: sem meia-parcela.
      (installment_no IS NULL AND installment_total IS NULL AND installment_group_id IS NULL)
      OR (
        installment_no IS NOT NULL AND installment_total IS NOT NULL
        AND installment_group_id IS NOT NULL
        -- 2 é o mínimo que merece o nome (1x é conta avulsa); 48 = 4 anos, teto
        -- generoso para financiamento de equipamento.
        AND installment_total BETWEEN 2 AND 48
        AND installment_no BETWEEN 1 AND installment_total
      )
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'expense_kind_chk') THEN
    -- Avulsa XOR fixa XOR parcelada. É a distinção que o cadastro mostra ao
    -- usuário; deixá-la só na UI permitiria criar pelo replay do sync uma conta
    -- que é as duas coisas, e nem a tela nem o relatório saberiam lê-la.
    ALTER TABLE expense ADD CONSTRAINT expense_kind_chk
      CHECK (recurrence_id IS NULL OR installment_group_id IS NULL);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'expense_supplier_doc_chk') THEN
    ALTER TABLE expense ADD CONSTRAINT expense_supplier_doc_chk
      CHECK (supplier_doc IS NULL OR supplier_doc ~ '^[0-9]{11}$|^[0-9]{14}$');
  END IF;
END $$;

-- As irmãs de um parcelamento são lidas juntas (detalhe mostra "2 de 6" e o
-- total da dívida). Parcial: a esmagadora maioria das contas não é parcelada.
CREATE INDEX IF NOT EXISTS idx_expense_tenant_installment_group
  ON expense(tenant_id, installment_group_id)
  WHERE installment_group_id IS NOT NULL;

-- Fornecedor é filtro e agrupamento de relatório ("quanto paguei à Distribuidora
-- X"), sempre por documento — nome tem grafia variável.
CREATE INDEX IF NOT EXISTS idx_expense_tenant_supplier
  ON expense(tenant_id, supplier_doc)
  WHERE supplier_doc IS NOT NULL;

-- ------------------------------------------------------------
-- 3. Caixa: `sale_kind` passa a aceitar 'expense'
-- ------------------------------------------------------------
-- A baixa de uma despesa gravava `sale_kind = NULL` de propósito, para "o caixa
-- não precisar conhecer o módulo de despesas". Isso é REVERTIDO aqui, de caso
-- pensado:
--
--   * `sale_kind` já carrega 'os', que é de outro módulo — o caixa sempre guardou
--     TAG de origem alheia, e guardar uma tag nunca foi ler tabela alheia. A
--     regra 1 continua intacta: o caixa não sabe o que uma despesa É;
--   * o índice (tenant_id, sale_kind, sale_id) já existe;
--   * e o que decide: com a tag, clicar no lançamento e abrir a despesa funciona
--     OFFLINE, porque o espelho local do `cash_entry` traz `sale_kind`. Buscar a
--     despesa por `cash_entry_id` exigiria rede no exato momento do clique.
--
-- Relaxar um CHECK não invalida linha existente, então isto é aditivo de fato.
ALTER TABLE cash_entry DROP CONSTRAINT IF EXISTS cash_entry_sale_kind_chk;
ALTER TABLE cash_entry ADD CONSTRAINT cash_entry_sale_kind_chk
  CHECK (sale_kind IS NULL OR sale_kind IN ('os','sale','expense'));
