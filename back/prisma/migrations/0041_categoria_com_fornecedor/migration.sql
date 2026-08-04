-- ============================================================
-- 0041 — Categoria de despesa diz se tem FORNECEDOR — aditivo, idempotente
-- ============================================================
-- "Adicionar fornecedor" aparecia em toda despesa, inclusive em Aluguel e
-- Energia, onde a pergunta não faz sentido. Quem sabe se existe um fornecedor do
-- outro lado é a CATEGORIA: peças e manutenção têm; imposto e salário não.
--
-- Por que uma coluna e não uma lista fixa no app: a cliente cria as próprias
-- categorias. Uma whitelist no Flutter só acertaria as dez que semeamos e erraria
-- todas as dela — e ainda exigiria publicar versão nova para consertar. Com a
-- coluna, o switch do cadastro de categoria resolve na hora.
ALTER TABLE expense_category
  ADD COLUMN IF NOT EXISTS tracks_supplier boolean NOT NULL DEFAULT false;

-- Backfill pelas categorias SEMEADAS que realmente têm fornecedor. Casa pela
-- chave de ícone, não pelo nome: o nome é editável pela cliente ("Fornecedor" pode
-- ter virado "Peças"), a chave não muda.
--
-- `false` como default é o certo para o resto: mostrar o campo onde ele não serve
-- é justamente o que estamos removendo, e o switch liga quando for o caso.
UPDATE expense_category
   SET tracks_supplier = true
 WHERE icon IN ('fornecedor', 'manutencao')
   AND tracks_supplier = false;
