-- ============================================================
-- Seed de carga (teste de capacidade de tela) — NÃO é migration.
-- Tenant: 48.516.852 ANA CASSIA (FAKE) — :tid passado via psql -v.
-- Rodar como app_migrator (BYPASSRLS). Idempotente o suficiente p/ teste:
-- usa prefixos distintos ('LT') p/ não colidir com dados reais e pode rodar 1x.
-- ============================================================
\set ON_ERROR_STOP on
\timing on

BEGIN;

-- ---------- 10.000 clientes ----------
INSERT INTO customer (tenant_id, name, type, document, phone, email, status)
SELECT
  :'tid',
  'Cliente Teste ' || g,
  CASE WHEN g % 5 = 0 THEN 'PJ' ELSE 'PF' END,
  'LT' || lpad(g::text, 12, '0'),                       -- document único por tenant
  '11' || lpad((900000000 + g)::text, 9, '0'),
  'cliente' || g || '@teste.com',
  'active'
FROM generate_series(1, 10000) AS g;

-- ---------- 9.000 produtos (inventory) ----------
INSERT INTO inventory_item
  (tenant_id, name, sku, category, brand, unit,
   sale_price, cost_price, current_stock, min_stock, is_active)
SELECT
  :'tid',
  'Produto Teste ' || g,
  'LT-SKU-' || lpad(g::text, 6, '0'),                   -- sku único por tenant
  'Categoria ' || (g % 20),
  'Marca ' || (g % 10),
  'un',
  round((10 + (g % 500) * 1.37)::numeric, 2),
  round((5 + (g % 500) * 0.91)::numeric, 2),
  CASE WHEN g % 11 = 0 THEN 0 ELSE (g % 250) END,       -- alguns zerados
  CASE WHEN g % 7 = 0 THEN 5 ELSE NULL END,
  true
FROM generate_series(1, 9000) AS g;

-- ---------- 10.000 ordens de serviço ----------
-- Cada OS aponta p/ um cliente real recém-criado (snapshot do nome).
WITH cust AS (
  SELECT id, name,
         row_number() OVER (ORDER BY created_at, id) AS rn
  FROM customer
  WHERE tenant_id = :'tid' AND name LIKE 'Cliente Teste %'
),
gen AS (SELECT generate_series(1, 10000) AS g)
INSERT INTO service_order
  (tenant_id, number, customer_id, customer_name, status,
   complaint, total, opened_at, created_at)
SELECT
  :'tid',
  'OS-LT' || lpad(gen.g::text, 6, '0'),                 -- number único por tenant
  cust.id,
  cust.name,
  (ARRAY['aberta','aguardando_aprovacao','aprovada',
         'em_execucao','concluida','entregue'])[1 + (gen.g % 6)],
  'Serviço de teste #' || gen.g,
  round(((gen.g % 800) * 12.5)::numeric, 2),
  now() - (gen.g || ' minutes')::interval,
  now() - (gen.g || ' minutes')::interval
FROM gen
JOIN cust ON cust.rn = ((gen.g - 1) % 10000) + 1;

-- ---------- 1.000 conversas (chats) + mensagens ----------
-- Cada conversa aponta p/ uma OS (ref_type='os', ref_id único por tenant).
WITH os AS (
  SELECT id, customer_name,
         row_number() OVER (ORDER BY opened_at DESC, id) AS rn
  FROM service_order
  WHERE tenant_id = :'tid' AND number LIKE 'OS-LT%'
  LIMIT 1000
)
INSERT INTO conversation
  (tenant_id, ref_type, ref_id, title, channel, staff_unread, last_message_at)
SELECT
  :'tid', 'os', os.id, os.customer_name, 'public_link',
  1 + (os.rn % 3),                                      -- 1..3 não-lidas
  now() - (os.rn || ' minutes')::interval
FROM os;

-- 2 mensagens por conversa recém-criada (cliente + staff)
INSERT INTO message (tenant_id, conversation_id, sender, author_name, body, created_at)
SELECT c.tenant_id, c.id, 'customer', c.title,
       'Olá, tem novidade sobre o meu serviço?', c.last_message_at - interval '5 minutes'
FROM conversation c
WHERE c.tenant_id = :'tid' AND c.ref_type = 'os' AND c.title LIKE 'Cliente Teste %';

INSERT INTO message (tenant_id, conversation_id, sender, author_name, body, created_at)
SELECT c.tenant_id, c.id, 'staff', 'Atendente',
       'Oi! Seu serviço está em andamento, em breve atualizamos.', c.last_message_at
FROM conversation c
WHERE c.tenant_id = :'tid' AND c.ref_type = 'os' AND c.title LIKE 'Cliente Teste %';

COMMIT;

-- ---------- conferência ----------
SELECT 'customers'     AS tabela, count(*) FROM customer       WHERE tenant_id = :'tid'
UNION ALL SELECT 'inventory', count(*) FROM inventory_item     WHERE tenant_id = :'tid'
UNION ALL SELECT 'service_order', count(*) FROM service_order  WHERE tenant_id = :'tid'
UNION ALL SELECT 'conversation', count(*) FROM conversation    WHERE tenant_id = :'tid'
UNION ALL SELECT 'message', count(*) FROM message              WHERE tenant_id = :'tid';
