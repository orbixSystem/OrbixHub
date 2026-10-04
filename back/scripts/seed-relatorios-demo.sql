-- back/scripts/seed-relatorios-demo.sql
-- ============================================================
-- Três meses de movimento para olhar o relatório completo
-- ============================================================
-- Agosto, setembro e outubro de 2026 na oficina-demo. Os números não são
-- aleatórios: foram escolhidos para a leitura do mês ter o que dizer.
--
--   agosto    faturou ~R$ 43.000, gastou ~R$ 24.000, fiou pouco
--   setembro  faturou ~R$ 48.200 (+12%), gastou ~R$ 31.300 (+30%) e fiou muito
--   outubro   os primeiros dias, para o "mês atual" não abrir vazio
--
-- Com isso os sinais aparecem de verdade: o fiado cresce acima do faturamento,
-- a despesa sobe mais que a receita, o ticket médio cai e há item abaixo do
-- mínimo. Um seed de números bonitos e crescentes não testaria nada — a tela
-- com três setas verdes não prova que os alertas funcionam.
--
-- Rodar:
--   psql "postgresql://app_owner:owner_pw@localhost:5432/orbixhub" \
--        -f back/scripts/seed-relatorios-demo.sql
--
-- É REPETÍVEL: apaga o que ele mesmo criou (marcado com '[demo]' ou prefixo
-- 'DEMO-') antes de inserir de novo. Nada que você tenha criado à mão é tocado.

\set ON_ERROR_STOP on
\set tenant '''0c672d3b-abec-4b11-8dae-50507cfab2cb'''

-- As tabelas têm RLS + FORCE, que vale até para o dono. Sem o tenant no
-- contexto, todo INSERT seria recusado pela policy.
SELECT set_config('app.current_tenant_id', :tenant, false);

BEGIN;

-- Qual sessão demo cobre esta data.
CREATE OR REPLACE FUNCTION pg_temp.sessao_do_mes(p_tenant uuid, p_quando timestamptz)
RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT id FROM cash_session
  WHERE tenant_id = p_tenant AND notes = '[demo]'
    AND date_trunc('month', opened_at) = date_trunc('month', p_quando)
  LIMIT 1
$$;

-- ---------------------------------------------------------------
-- Limpeza do que este script criou antes
-- ---------------------------------------------------------------
DELETE FROM cash_entry       WHERE tenant_id = :tenant::uuid AND description LIKE '[demo]%';
DELETE FROM expense          WHERE tenant_id = :tenant::uuid AND description LIKE '[demo]%';
DELETE FROM sale_item        WHERE tenant_id = :tenant::uuid AND sale_id IN (
  SELECT id FROM sale WHERE tenant_id = :tenant::uuid AND number LIKE 'DEMO-%');
DELETE FROM sale             WHERE tenant_id = :tenant::uuid AND number LIKE 'DEMO-%';
DELETE FROM service_order_item WHERE tenant_id = :tenant::uuid AND order_id IN (
  SELECT id FROM service_order WHERE tenant_id = :tenant::uuid AND number LIKE 'DEMO-%');
DELETE FROM service_order    WHERE tenant_id = :tenant::uuid AND number LIKE 'DEMO-%';
DELETE FROM customer         WHERE tenant_id = :tenant::uuid AND notes = '[demo]';
DELETE FROM cash_session     WHERE tenant_id = :tenant::uuid AND notes = '[demo]';

-- ---------------------------------------------------------------
-- Clientes — chegando ao longo dos três meses
-- ---------------------------------------------------------------
-- O "clientes novos" do relatório conta por `created_at`, então a distribuição
-- aqui é o que faz esse número variar de um mês para o outro.
INSERT INTO customer (id, tenant_id, name, type, phone, status, notes, created_at, updated_at)
SELECT
  gen_random_uuid(),
  :tenant::uuid,
  (ARRAY['Ana Clara Dias','Bruno Tavares','Carla Menezes','Diego Prado','Elaine Souza',
         'Fábio Rocha','Gisele Amorim','Heitor Nunes','Isabel Castro','João Pedro Lima',
         'Karina Belo','Lucas Ferraz','Marina Quadros','Nelson Bastos','Olívia Freire',
         'Paulo Rangel','Queila Martins','Rafael Pontes','Sônia Vieira','Tiago Mendes',
         'Úrsula Lacerda','Vitor Hugo Sá','Wanda Correia','Xavier Pires','Yara Moraes',
         'Zeca do Posto'])[i],
  -- 'PF'/'PJ' são os únicos valores aceitos pelo CHECK da tabela.
  CASE WHEN i % 5 = 0 THEN 'PJ' ELSE 'PF' END,
  '119' || lpad((10000000 + i * 137)::text, 8, '0'),
  'active',
  '[demo]',
  -- 10 em agosto, 11 em setembro, 5 em outubro
  CASE
    WHEN i <= 10 THEN timestamptz '2026-08-02 09:00-03' + (i * interval '2 days')
    WHEN i <= 21 THEN timestamptz '2026-09-01 09:00-03' + ((i - 10) * interval '2 days')
    ELSE               timestamptz '2026-10-01 09:00-03' + ((i - 21) * interval '14 hours')
  END,
  now()
FROM generate_series(1, 26) AS i;

-- ---------------------------------------------------------------
-- Ordens de serviço
-- ---------------------------------------------------------------
-- O faturamento de OS é contado por `COALESCE(finished_at, closed_at)` e só
-- para os status faturáveis — por isso cada OS entregue recebe `finished_at`
-- dentro do mês a que deve pertencer.
--
-- O ticket médio de setembro é menor de propósito (mais ordens, serviço mais
-- barato): é o que faz o sinal de "ticket caindo" ter o que dizer.
WITH membros AS (
  SELECT array_agg(user_id ORDER BY user_id) AS ids
  FROM membership WHERE tenant_id = :tenant::uuid
),
clientes AS (
  SELECT array_agg(id ORDER BY created_at) AS ids, array_agg(name ORDER BY created_at) AS nomes
  FROM customer WHERE tenant_id = :tenant::uuid AND notes = '[demo]'
),
plano AS (
  -- (mês, quantidade, valor base, variação do valor)
  SELECT * FROM (VALUES
    ('2026-08-01'::date, 26, 1150, 320),
    ('2026-09-01'::date, 31,  980, 260),
    ('2026-10-01'::date,  5, 1050, 180)
  ) AS p(mes, qtd, base, amplitude)
),
linhas AS (
  SELECT
    p.mes,
    i,
    -- Espalha pelos dias úteis do mês, com mais movimento no meio.
    (p.mes + ((i * 29 / p.qtd))::int * interval '1 day'
           + ((i % 7) + 8) * interval '1 hour') AS quando,
    round((p.base + ((i * 37) % p.amplitude))::numeric, 2) AS total
  FROM plano p, generate_series(1, p.qtd) AS i
)
INSERT INTO service_order (
  id, tenant_id, number, customer_id, customer_name, status, assigned_to, opened_by,
  complaint, total, discount, opened_at, finished_at, closed_at, created_at, updated_at
)
SELECT
  gen_random_uuid(),
  :tenant::uuid,
  'DEMO-' || to_char(l.mes, 'MM') || '-' || lpad(l.i::text, 3, '0'),
  c.ids[1 + (l.i % array_length(c.ids, 1))],
  c.nomes[1 + (l.i % array_length(c.nomes, 1))],
  -- A maioria entregue; algumas canceladas e algumas em andamento, que é como
  -- uma oficina de verdade termina o mês.
  CASE
    WHEN l.i % 13 = 0 THEN 'cancelada'
    WHEN l.i % 11 = 0 THEN 'em_execucao'
    WHEN l.i % 5  = 0 THEN 'concluida'
    ELSE 'entregue'
  END,
  m.ids[1 + (l.i % array_length(m.ids, 1))],
  m.ids[1],
  (ARRAY['Barulho na suspensão','Troca de óleo e filtros','Revisão de 20 mil km',
         'Freio raspando','Ar-condicionado sem gelar','Luz de injeção acesa',
         'Alinhamento e balanceamento','Correia dentada','Bateria arriando',
         'Embreagem patinando'])[1 + (l.i % 10)],
  l.total,
  0,
  l.quando - interval '2 days',
  -- Só as faturáveis têm data de conclusão: é ela que leva a OS para o mês.
  CASE WHEN l.i % 13 = 0 OR l.i % 11 = 0 THEN NULL ELSE l.quando END,
  CASE WHEN l.i % 13 = 0 THEN l.quando ELSE NULL END,
  l.quando - interval '2 days',
  now()
FROM linhas l, membros m, clientes c;

-- Um item por OS, para o detalhamento não vir vazio.
INSERT INTO service_order_item (
  id, tenant_id, order_id, kind, name, quantity, unit_price, discount, total, created_at
)
SELECT
  gen_random_uuid(), :tenant::uuid, o.id, 'service',
  coalesce(o.complaint, 'Serviço'), 1, o.total, 0, o.total, o.created_at
FROM service_order o
WHERE o.tenant_id = :tenant::uuid AND o.number LIKE 'DEMO-%';

-- ---------------------------------------------------------------
-- Vendas de balcão
-- ---------------------------------------------------------------
-- As marcadas com `fiado_at` e sem lançamento no caixa são as que viram
-- "a receber". Setembro fia MUITO mais que agosto — é o alerta principal do
-- relatório, e sem esse contraste ele não teria como aparecer.
WITH plano AS (
  SELECT * FROM (VALUES
    ('2026-08-01'::date, 16, 760, 240,  2),  -- 2 fiadas
    ('2026-09-01'::date, 18, 720, 260,  9),  -- 9 fiadas
    ('2026-10-01'::date,  4, 700, 150,  1)
  ) AS p(mes, qtd, base, amplitude, fiadas)
),
linhas AS (
  SELECT
    p.mes, i, p.fiadas,
    (p.mes + ((i * 29 / p.qtd))::int * interval '1 day' + ((i % 9) + 9) * interval '1 hour') AS quando,
    round((p.base + ((i * 53) % p.amplitude))::numeric, 2) AS total
  FROM plano p, generate_series(1, p.qtd) AS i
),
clientes AS (
  SELECT array_agg(id ORDER BY created_at) AS ids, array_agg(name ORDER BY created_at) AS nomes
  FROM customer WHERE tenant_id = :tenant::uuid AND notes = '[demo]'
)
INSERT INTO sale (
  id, tenant_id, number, customer_id, customer_name, status, total, discount,
  description, fiado_at, created_at, updated_at
)
SELECT
  gen_random_uuid(), :tenant::uuid,
  'DEMO-V' || to_char(l.mes, 'MM') || '-' || lpad(l.i::text, 3, '0'),
  c.ids[1 + ((l.i * 3) % array_length(c.ids, 1))],
  c.nomes[1 + ((l.i * 3) % array_length(c.nomes, 1))],
  'active', l.total, 0,
  (ARRAY['Óleo 5W30 + filtro','Pastilha de freio','Palheta do limpador',
         'Aditivo do radiador','Lâmpada do farol','Filtro de ar',
         'Vela de ignição','Correia do alternador'])[1 + (l.i % 8)],
  CASE WHEN l.i <= l.fiadas THEN l.quando ELSE NULL END,
  l.quando, now()
FROM linhas l, clientes c;

INSERT INTO sale_item (id, tenant_id, sale_id, kind, name, quantity, unit_price, subtotal, created_at)
SELECT gen_random_uuid(), :tenant::uuid, s.id, 'product',
       coalesce(s.description, 'Peça'), 1, s.total, s.total, s.created_at
FROM sale s
WHERE s.tenant_id = :tenant::uuid AND s.number LIKE 'DEMO-%';

-- ---------------------------------------------------------------
-- Caixa — o dinheiro que realmente entrou e saiu
-- ---------------------------------------------------------------
-- Todo lançamento pertence a uma sessão (a coluna é obrigatória). A cerimônia
-- de abrir e fechar caixa saiu do produto, mas a sessão continua existindo
-- como balde interno — então aqui vai uma por mês, só para os lançamentos
-- terem onde morar.
INSERT INTO cash_session (id, tenant_id, opened_by, opened_at, opening_amount, status, notes, created_at, updated_at)
SELECT
  gen_random_uuid(), :tenant::uuid,
  (SELECT user_id FROM membership WHERE tenant_id = :tenant::uuid LIMIT 1),
  mes, 0, 'closed', '[demo]', mes, now()
FROM (VALUES
  (timestamptz '2026-08-01 08:00-03'),
  (timestamptz '2026-09-01 08:00-03'),
  (timestamptz '2026-10-01 08:00-03')
) AS m(mes);

-- Entrada por OS entregue e por venda à vista. O que foi fiado NÃO entra: é
-- exatamente essa diferença entre faturar e receber que o relatório mostra.
INSERT INTO cash_entry (
  id, tenant_id, cash_session_id, direction, amount, method, category,
  sale_kind, sale_id, description, created_by, created_at, updated_at
)
SELECT
  gen_random_uuid(), :tenant::uuid, pg_temp.sessao_do_mes(:tenant::uuid, o.finished_at), 'in', o.total,
  (ARRAY['pix','dinheiro','cartao_credito','cartao_debito'])[1 + (abs(hashtext(o.number)) % 4)],
  'os_payment', 'os', o.id,
  '[demo] Recebimento ' || o.number,
  (SELECT user_id FROM membership WHERE tenant_id = :tenant::uuid LIMIT 1),
  o.finished_at, now()
FROM service_order o
WHERE o.tenant_id = :tenant::uuid AND o.number LIKE 'DEMO-%'
  AND o.finished_at IS NOT NULL;

INSERT INTO cash_entry (
  id, tenant_id, cash_session_id, direction, amount, method, category,
  sale_kind, sale_id, description, created_by, created_at, updated_at
)
SELECT
  gen_random_uuid(), :tenant::uuid, pg_temp.sessao_do_mes(:tenant::uuid, s.created_at), 'in', s.total,
  (ARRAY['pix','dinheiro','cartao_debito'])[1 + (abs(hashtext(s.number)) % 3)],
  'venda_avulsa', 'sale', s.id,
  '[demo] Venda ' || s.number,
  (SELECT user_id FROM membership WHERE tenant_id = :tenant::uuid LIMIT 1),
  s.created_at, now()
FROM sale s
WHERE s.tenant_id = :tenant::uuid AND s.number LIKE 'DEMO-%'
  AND s.fiado_at IS NULL;

-- ---------------------------------------------------------------
-- Despesas — e a saída correspondente no caixa
-- ---------------------------------------------------------------
-- O relatório recorta despesa pelo VENCIMENTO. Setembro sobe ~30% contra ~12%
-- do faturamento: é o segundo alerta do mês.
WITH cat AS (
  SELECT name, id FROM expense_category WHERE tenant_id = :tenant::uuid
),
plano AS (
  SELECT * FROM (VALUES
    ('2026-08-01'::date, 'Fornecedor', 11800), ('2026-08-05'::date, 'Aluguel', 4200),
    ('2026-08-07'::date, 'Energia', 1450),     ('2026-08-10'::date, 'Impostos', 2600),
    ('2026-08-12'::date, 'Internet', 320),     ('2026-08-15'::date, 'Produto', 3630),
    ('2026-09-01'::date, 'Fornecedor', 16900), ('2026-09-05'::date, 'Aluguel', 4200),
    ('2026-09-07'::date, 'Energia', 1980),     ('2026-09-10'::date, 'Impostos', 3150),
    ('2026-09-12'::date, 'Internet', 320),     ('2026-09-15'::date, 'Produto', 4750),
    ('2026-10-01'::date, 'Fornecedor', 2600),  ('2026-10-03'::date, 'Energia', 1400)
  ) AS p(venc, categoria, valor)
)
INSERT INTO expense (
  id, tenant_id, description, amount, due_date, category_id, occurrence_on,
  paid_at, paid_amount, paid_method, status, created_by, created_at, updated_at
)
SELECT
  gen_random_uuid(), :tenant::uuid,
  '[demo] ' || p.categoria || ' ' || to_char(p.venc, 'MM/YYYY'),
  p.valor, p.venc, c.id, p.venc,
  -- Outubro ainda em aberto: a tela precisa saber mostrar os dois estados.
  CASE WHEN p.venc < date '2026-10-01' THEN p.venc + interval '9 hours' ELSE NULL END,
  CASE WHEN p.venc < date '2026-10-01' THEN p.valor ELSE NULL END,
  CASE WHEN p.venc < date '2026-10-01' THEN 'pix' ELSE NULL END,
  -- `status` é o ciclo de vida da despesa ('active'/'canceled'), não o
  -- pagamento: quem diz se foi paga é `paid_at`.
  'active',
  (SELECT user_id FROM membership WHERE tenant_id = :tenant::uuid LIMIT 1),
  p.venc, now()
FROM plano p JOIN cat c ON c.name = p.categoria;

INSERT INTO cash_entry (
  id, tenant_id, cash_session_id, direction, amount, method, category,
  description, created_by, created_at, updated_at
)
SELECT
  gen_random_uuid(), :tenant::uuid, pg_temp.sessao_do_mes(:tenant::uuid, e.paid_at), 'out', e.amount, 'pix', 'despesa',
  e.description, e.created_by, e.paid_at, now()
FROM expense e
WHERE e.tenant_id = :tenant::uuid AND e.description LIKE '[demo]%' AND e.paid_at IS NOT NULL;

-- ---------------------------------------------------------------
-- Estoque — alguns itens abaixo do mínimo
-- ---------------------------------------------------------------
-- Vira o terceiro sinal, e é o único acionável sem cobrar ninguém.
UPDATE inventory_item
SET current_stock = 1, min_stock = 6, updated_at = now()
WHERE tenant_id = :tenant::uuid
  AND id IN (
    SELECT id FROM inventory_item
    WHERE tenant_id = :tenant::uuid AND kind = 'product'
    ORDER BY name LIMIT 4
  );

COMMIT;

-- ---------------------------------------------------------------
-- Conferência
-- ---------------------------------------------------------------
SELECT 'OS faturadas por mês' AS o_que, to_char(finished_at, 'YYYY-MM') AS mes,
       count(*) AS qtd, to_char(sum(total), 'FM999G999D00') AS total
FROM service_order
WHERE tenant_id = :tenant::uuid AND number LIKE 'DEMO-%' AND finished_at IS NOT NULL
  AND status IN ('concluida','a_receber','entregue')
GROUP BY 2 ORDER BY 2;

SELECT 'Vendas por mês' AS o_que, to_char(created_at, 'YYYY-MM') AS mes,
       count(*) AS qtd, to_char(sum(total), 'FM999G999D00') AS total,
       to_char(sum(total) FILTER (WHERE fiado_at IS NOT NULL), 'FM999G999D00') AS fiado
FROM sale
WHERE tenant_id = :tenant::uuid AND number LIKE 'DEMO-%'
GROUP BY 2 ORDER BY 2;

SELECT 'Caixa por mês' AS o_que, to_char(created_at, 'YYYY-MM') AS mes,
       to_char(sum(amount) FILTER (WHERE direction = 'in'), 'FM999G999D00') AS entrou,
       to_char(sum(amount) FILTER (WHERE direction = 'out'), 'FM999G999D00') AS saiu
FROM cash_entry
WHERE tenant_id = :tenant::uuid AND description LIKE '[demo]%'
GROUP BY 2 ORDER BY 2;

SELECT 'Despesas por mês' AS o_que, to_char(due_date, 'YYYY-MM') AS mes,
       to_char(sum(amount), 'FM999G999D00') AS total
FROM expense
WHERE tenant_id = :tenant::uuid AND description LIKE '[demo]%'
GROUP BY 2 ORDER BY 2;
