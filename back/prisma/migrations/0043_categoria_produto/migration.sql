-- ============================================================
-- 0043 — Categoria padrão "Produto" — aditivo, idempotente
-- ============================================================
-- Falta uma categoria para a compra de PRODUTO/mercadoria: hoje isso cai em
-- "Fornecedor" (que é sobre quem cobra, não sobre o que foi comprado) ou em
-- "Outros". Oficina compra peça, óleo e material de consumo toda semana — é uma
-- das despesas mais frequentes e a que mais interessa ver separada no relatório.
--
-- `tracks_supplier = true`: compra de produto SEMPRE tem alguém do outro lado, e é
-- justamente o caso em que a consulta de CNPJ serve.
--
-- Semeada para os tenants que JÁ existem. O `NOT EXISTS` por nome (case- e
-- espaço-insensível, igual ao unique parcial da 0039) evita duplicar para quem já
-- criou a sua "Produto" à mão — nesse caso a dela prevalece, com o ícone e a cor
-- que escolheu.
INSERT INTO expense_category (tenant_id, name, icon, color, tracks_supplier)
SELECT t.id, 'Produto', 'produto', '#0EA5E9', true
  FROM tenant t
 WHERE NOT EXISTS (
   SELECT 1 FROM expense_category c
    WHERE c.tenant_id = t.id
      AND lower(btrim(c.name)) = 'produto'
      AND c.status = 'active'
 )
 -- Só onde o módulo já foi aberto alguma vez (já há categorias semeadas). Tenant
 -- que nunca abriu Despesas recebe a lista completa, já com "Produto", na
 -- primeira listagem — inserir aqui criaria uma categoria solta antes das outras.
   AND EXISTS (SELECT 1 FROM expense_category c2 WHERE c2.tenant_id = t.id);
