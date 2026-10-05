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
-- O seed também existe para ENCHER o painel: cada card de Relatórios tem uma
-- fonte, e um card vazio esconde tanto um bug quanto um gráfico errado mostra.
-- Por isso aqui há equipe com mais de uma pessoa, OS em todos os status, peças
-- dentro das ordens, cinco formas de pagamento, saídas de caixa de categorias
-- diferentes, despesas vencidas, descontos, pagamentos parciais e um estoque
-- com margem, falta e item zerado.
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
DELETE FROM receivable_installment WHERE tenant_id = :tenant::uuid AND notes = '[demo]';
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
DELETE FROM inventory_item   WHERE tenant_id = :tenant::uuid AND sku LIKE 'DEMO-%';
-- A equipe demo sai por último: as OS apontavam para ela.
DELETE FROM membership       WHERE tenant_id = :tenant::uuid AND user_id IN (
  SELECT id FROM users WHERE email_normalized LIKE '%@demo.oficina.local');
DELETE FROM users            WHERE email_normalized LIKE '%@demo.oficina.local';

-- ---------------------------------------------------------------
-- Equipe — quatro mecânicos além do dono
-- ---------------------------------------------------------------
-- Sem isto a aba Equipe tem uma pessoa só, e "quem fez mais receita",
-- "participação" e "tempo médio" viram uma barra sozinha de 100% — um gráfico
-- que não poderia estar errado porque não compara nada.
--
-- A senha é a mesma do dono (copiamos o hash): são contas de banco LOCAL, e
-- poder entrar como mecânico é justamente o que permite conferir o gating de
-- papel sem criar usuário à mão.
INSERT INTO users (id, email_normalized, full_name, password_hash, email_verified_at, created_at, updated_at)
SELECT
  gen_random_uuid(),
  lower(split_part(nome, ' ', 1)) || '@demo.oficina.local',
  nome,
  (SELECT password_hash FROM users WHERE email_normalized = 'dono@oficina-demo.dev'),
  now(), now(), now()
FROM unnest(ARRAY[
  'Rogério Alves', 'Marcos Tenório', 'Juliana Prado', 'Everton Baptista'
]) AS nome;

INSERT INTO membership (id, tenant_id, user_id, role_id, status, created_at)
SELECT gen_random_uuid(), :tenant::uuid, u.id,
       (SELECT id FROM role WHERE name = 'Mecânico'), 'active', now()
FROM users u
WHERE u.email_normalized LIKE '%@demo.oficina.local';

-- ---------------------------------------------------------------
-- Estoque — prateleira de verdade, com margem, falta e item zerado
-- ---------------------------------------------------------------
-- A aba Estoque tem seis cards e todos saem desta tabela: valor parado,
-- o que vai faltar, margem, situação, custo × venda. Com quatro itens — todos
-- abaixo do mínimo, como estava antes — quatro dos seis cards diziam a mesma
-- coisa e a barra de "o que vai faltar" não tinha com que ser comparada.
--
-- A distribuição é proposital: margens de 18% a 140% (há peça que quase não
-- paga o próprio custo), alguns itens zerados, alguns abaixo do mínimo, e três
-- sem mínimo definido — que nunca disparam aviso de falta e por isso merecem
-- aparecer no KPI que os conta.
INSERT INTO inventory_item (
  id, tenant_id, name, sku, category, brand, unit,
  sale_price, cost_price, current_stock, min_stock, kind, is_active,
  created_at, updated_at
)
SELECT
  gen_random_uuid(), :tenant::uuid, p.nome, 'DEMO-' || lpad(p.i::text, 3, '0'),
  p.categoria, p.marca, 'un',
  p.venda, p.custo, p.estoque, p.minimo, 'product', true,
  timestamptz '2026-07-15 10:00-03', now()
FROM (VALUES
  ( 1, 'Óleo Motor 5W30 Sintético 1L',  'Lubrificantes', 'Mobil',     58.00,  32.00,  48,  12),
  ( 2, 'Óleo Motor 15W40 Mineral 1L',   'Lubrificantes', 'Lubrax',    39.00,  24.00,  31,  10),
  ( 3, 'Filtro de Óleo',                'Filtros',       'Tecfil',    34.00,  18.00,   3,   8),
  ( 4, 'Filtro de Ar',                  'Filtros',       'Tecfil',    49.00,  26.00,   2,   8),
  ( 5, 'Filtro de Combustível',         'Filtros',       'Bosch',     62.00,  38.00,  14,   6),
  ( 6, 'Filtro de Cabine',              'Filtros',       'Wega',      71.00,  41.00,   9,   5),
  ( 7, 'Pastilha de Freio Dianteira',   'Freios',        'Cobreq',   189.00, 108.00,   1,   6),
  ( 8, 'Pastilha de Freio Traseira',    'Freios',        'Cobreq',   164.00,  97.00,   7,   4),
  ( 9, 'Disco de Freio Ventilado',      'Freios',        'Fremax',   298.00, 196.00,   4,   2),
  (10, 'Fluido de Freio DOT4 500ml',    'Freios',        'Bosch',     38.00,  19.00,  22,   8),
  (11, 'Bateria 60Ah',                  'Elétrica',      'Moura',    589.00, 442.00,   5,   3),
  (12, 'Vela de Ignição Irídio',        'Elétrica',      'NGK',       89.00,  52.00,  36,  16),
  (13, 'Lâmpada H4 Super Branca',       'Elétrica',      'Philips',   46.00,  22.00,  28,  10),
  (14, 'Cabo de Vela (jogo)',           'Elétrica',      'NGK',      178.00, 118.00,   6,   3),
  (15, 'Correia Dentada',               'Motor',         'Gates',    212.00, 138.00,   8,   4),
  (16, 'Correia do Alternador',         'Motor',         'Gates',     96.00,  58.00,  11,   5),
  (17, 'Bomba d''Água',                 'Motor',         'Urba',     284.00, 198.00,   0,   2),
  (18, 'Junta do Cabeçote',             'Motor',         'Taranto',  156.00, 112.00,   0,   2),
  (19, 'Amortecedor Dianteiro',         'Suspensão',     'Cofap',    389.00, 268.00,   6,   4),
  (20, 'Amortecedor Traseiro',          'Suspensão',     'Cofap',    312.00, 214.00,   5,   4),
  (21, 'Bieleta de Suspensão',          'Suspensão',     'Nakata',    78.00,  44.00,  19,   8),
  (22, 'Palheta do Limpador 22"',       'Acessórios',    'Bosch',     54.00,  27.00,  41, NULL),
  (23, 'Aditivo de Radiador 1L',        'Fluidos',       'Paraflu',   32.00,  14.00,  26, NULL),
  (24, 'Desengripante 300ml',           'Químicos',      'WD-40',     29.00,  12.00,  33, NULL)
) AS p(i, nome, categoria, marca, venda, custo, estoque, minimo);

-- Serviços de catálogo: são o que a OS usa como item de mão de obra, e é deles
-- que sai o ranking de "serviços mais vendidos".
INSERT INTO inventory_item (
  id, tenant_id, name, sku, category, unit, sale_price, cost_price,
  current_stock, kind, duration_minutes, is_active, created_at, updated_at
)
SELECT
  gen_random_uuid(), :tenant::uuid, p.nome, 'DEMO-S' || lpad(p.i::text, 2, '0'),
  'Serviços', 'h', p.preco, 0, 0, 'service', p.minutos, true,
  timestamptz '2026-07-15 10:00-03', now()
FROM (VALUES
  (1, 'Troca de óleo e filtros',        180.00,  45),
  (2, 'Revisão de 20 mil km',           640.00, 180),
  (3, 'Alinhamento e balanceamento',    220.00,  60),
  (4, 'Troca de pastilhas de freio',    260.00,  90),
  (5, 'Troca da correia dentada',       890.00, 240),
  (6, 'Diagnóstico eletrônico',         150.00,  40),
  (7, 'Reparo do ar-condicionado',      480.00, 150),
  (8, 'Troca de amortecedores',         620.00, 180)
) AS p(i, nome, preco, minutos);

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
         'Zeca do Posto','Transportes Aurora LTDA','Padaria Pão Nosso ME','Clínica Vida Plena',
         'Distribuidora K9','Construtora Marco Zero','Hamilton Peixoto','Iracema Vilela',
         'Joana Setúbal','Kleber Andrade','Letícia Varela','Mauro Bitencourt','Natália Rezende',
         'Otávio Camargo','Priscila Dantas'])[i],
  -- 'PF'/'PJ' são os únicos valores aceitos pelo CHECK da tabela.
  CASE WHEN i IN (27,28,29,30,31) OR i % 9 = 0 THEN 'PJ' ELSE 'PF' END,
  '119' || lpad((10000000 + i * 137)::text, 8, '0'),
  'active',
  '[demo]',
  -- 15 em agosto, 17 em setembro, 8 em outubro
  CASE
    WHEN i <= 15 THEN timestamptz '2026-08-02 09:00-03' + (i * interval '45 hours')
    WHEN i <= 32 THEN timestamptz '2026-09-01 09:00-03' + ((i - 15) * interval '40 hours')
    ELSE               timestamptz '2026-10-01 09:00-03' + ((i - 32) * interval '9 hours')
  END,
  now()
FROM generate_series(1, 40) AS i;

-- ---------------------------------------------------------------
-- Ordens de serviço
-- ---------------------------------------------------------------
-- O faturamento de OS é contado por `COALESCE(finished_at, closed_at)` e só
-- para os status faturáveis — por isso cada OS entregue recebe `finished_at`
-- dentro do mês a que deve pertencer.
--
-- O ticket médio de setembro é menor de propósito (mais ordens, serviço mais
-- barato): é o que faz o sinal de "ticket caindo" ter o que dizer.
--
-- Os status cobrem os ONZE do workflow. Antes só quatro apareciam, e a rosca
-- "onde as ordens estão" — que existe para mostrar onde o trabalho empaca —
-- nunca mostrava uma pilha em "aguardando peças", que é o empacamento real de
-- uma oficina.
WITH membros AS (
  SELECT array_agg(user_id ORDER BY user_id) AS ids
  FROM membership WHERE tenant_id = :tenant::uuid AND status = 'active'
),
clientes AS (
  SELECT array_agg(id ORDER BY created_at) AS ids, array_agg(name ORDER BY created_at) AS nomes
  FROM customer WHERE tenant_id = :tenant::uuid AND notes = '[demo]'
),
plano AS (
  -- (mês, quantidade, valor base, variação do valor)
  SELECT * FROM (VALUES
    ('2026-08-01'::date, 36, 1150, 320),
    ('2026-09-01'::date, 44,  980, 260),
    ('2026-10-01'::date, 11, 1050, 180)
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
  -- A maioria entregue; o resto espalhado pelo workflow, que é como uma
  -- oficina de verdade termina o mês.
  CASE
    WHEN l.i % 23 = 0 THEN 'pendente'
    WHEN l.i % 19 = 0 THEN 'sem_conserto'
    WHEN l.i % 17 = 0 THEN 'cancelada'
    WHEN l.i % 16 = 0 THEN 'aguardando_aprovacao'
    WHEN l.i % 15 = 0 THEN 'em_execucao'
    WHEN l.i % 14 = 0 THEN 'aberta'
    WHEN l.i % 13 = 0 THEN 'aguardando_pecas'
    WHEN l.i % 12 = 0 THEN 'aprovada'
    WHEN l.i %  8 = 0 THEN 'a_receber'
    WHEN l.i %  5 = 0 THEN 'concluida'
    ELSE 'entregue'
  END,
  -- Sem responsável em uma a cada doze: a aba Equipe precisa saber mostrar
  -- esse balde, que na vida real é o que denuncia atribuição não usada.
  CASE WHEN l.i % 12 = 0 THEN NULL
       ELSE m.ids[1 + (l.i % array_length(m.ids, 1))] END,
  m.ids[1],
  (ARRAY['Barulho na suspensão','Troca de óleo e filtros','Revisão de 20 mil km',
         'Freio raspando','Ar-condicionado sem gelar','Luz de injeção acesa',
         'Alinhamento e balanceamento','Correia dentada','Bateria arriando',
         'Embreagem patinando'])[1 + (l.i % 10)],
  l.total,
  0,
  -- O tempo de ciclo varia por pessoa: sem isso "tempo médio por ordem" é uma
  -- fileira de barras idênticas, e o card não compara nada.
  l.quando - ((1 + (l.i % 5)) * interval '1 day'),
  -- Todas recebem a data; logo abaixo ela é apagada das que não faturam.
  l.quando,
  CASE WHEN l.i % 17 = 0 THEN l.quando ELSE NULL END,
  l.quando - ((1 + (l.i % 5)) * interval '1 day'),
  now()
FROM linhas l, membros m, clientes c;

-- Só as faturáveis têm data de conclusão: é ela que leva a OS para o mês.
-- Decidido aqui, a partir do STATUS, e não repetindo a lista de status no CASE
-- que os sorteia: foi assim que a primeira versão deixou 'a_receber' e
-- 'concluida' sem data e cortou o faturamento do mês pela metade, em silêncio.
UPDATE service_order
SET finished_at = NULL
WHERE tenant_id = :tenant::uuid AND number LIKE 'DEMO-%'
  AND status NOT IN ('concluida', 'a_receber', 'entregue');

-- ---------------------------------------------------------------
-- Itens da OS — as peças que ela consumiu e a mão de obra que fecha a conta
-- ---------------------------------------------------------------
-- É daqui que saem "serviços mais vendidos" e "peças mais vendidas": o ranking
-- lê `service_order_item`, não a venda de balcão. Com um item genérico por OS
-- (o texto da reclamação), os dois cards mostravam a mesma lista de dez frases
-- e nenhuma peça.
--
-- As peças entram primeiro, com o preço do catálogo. A mão de obra entra
-- depois pelo que FALTA para o total da ordem — e não pelo preço de tabela do
-- serviço. Fosse o contrário, o cabeçalho da OS e a soma dos itens
-- discordariam, ou o faturamento do mês passaria a ser o que o catálogo diz e
-- não o que a oficina cobrou; na primeira versão deste seed foi exatamente o
-- que aconteceu, e agosto despencou de R$ 43 mil para R$ 8,5 mil sem que nada
-- na tela dissesse por quê.
WITH pecas AS (
  SELECT array_agg(id ORDER BY name) AS ids, array_agg(name ORDER BY name) AS nomes,
         array_agg(sale_price ORDER BY name) AS precos
  FROM inventory_item WHERE tenant_id = :tenant::uuid AND kind = 'product' AND sku LIKE 'DEMO-%'
),
ordens AS (
  SELECT o.id, o.created_at, row_number() OVER (ORDER BY o.number) AS n
  FROM service_order o
  WHERE o.tenant_id = :tenant::uuid AND o.number LIKE 'DEMO-%'
)
INSERT INTO service_order_item (
  id, tenant_id, order_id, kind, inventory_item_id, name, quantity, unit_price,
  discount, total, created_at
)
-- A peça principal (toda OS consome alguma)
SELECT gen_random_uuid(), :tenant::uuid, o.id, 'product',
       p.ids[1 + ((o.n * 3) % array_length(p.ids, 1))],
       p.nomes[1 + ((o.n * 3) % array_length(p.nomes, 1))],
       1 + (o.n % 2), p.precos[1 + ((o.n * 3) % array_length(p.precos, 1))], 0,
       (1 + (o.n % 2)) * p.precos[1 + ((o.n * 3) % array_length(p.precos, 1))],
       o.created_at
FROM ordens o, pecas p
UNION ALL
-- Uma segunda peça em metade das ordens
SELECT gen_random_uuid(), :tenant::uuid, o.id, 'product',
       p.ids[1 + ((o.n * 7) % array_length(p.ids, 1))],
       p.nomes[1 + ((o.n * 7) % array_length(p.nomes, 1))],
       1, p.precos[1 + ((o.n * 7) % array_length(p.precos, 1))], 0,
       p.precos[1 + ((o.n * 7) % array_length(p.precos, 1))], o.created_at
FROM ordens o, pecas p
WHERE o.n % 2 = 0;

-- A mão de obra: o que sobra do total da ordem depois das peças, com um piso
-- para nenhuma OS sair com serviço de graça.
WITH servicos AS (
  SELECT array_agg(id ORDER BY name) AS ids, array_agg(name ORDER BY name) AS nomes
  FROM inventory_item WHERE tenant_id = :tenant::uuid AND kind = 'service' AND sku LIKE 'DEMO-%'
),
ordens AS (
  SELECT o.id, o.total, o.created_at, row_number() OVER (ORDER BY o.number) AS n,
         coalesce((
           SELECT sum(i.total) FROM service_order_item i
           WHERE i.tenant_id = :tenant::uuid AND i.order_id = o.id AND i.kind = 'product'
         ), 0) AS pecas
  FROM service_order o
  WHERE o.tenant_id = :tenant::uuid AND o.number LIKE 'DEMO-%'
)
INSERT INTO service_order_item (
  id, tenant_id, order_id, kind, inventory_item_id, name, quantity, unit_price,
  discount, total, created_at
)
SELECT gen_random_uuid(), :tenant::uuid, o.id, 'service',
       s.ids[1 + (o.n % array_length(s.ids, 1))],
       s.nomes[1 + (o.n % array_length(s.nomes, 1))],
       1, GREATEST(o.total - o.pecas, 150), 0,
       GREATEST(o.total - o.pecas, 150), o.created_at
FROM ordens o, servicos s;

-- O total da OS passa a ser a soma dos itens: um cabeçalho que discorda do
-- próprio detalhamento é o tipo de erro que só aparece quando o cliente
-- pergunta por que a conta não fecha. (Na prática só muda as poucas ordens em
-- que as peças já passavam do total e a mão de obra caiu no piso.)
UPDATE service_order o
SET total = sub.soma
FROM (
  SELECT order_id, sum(total) AS soma
  FROM service_order_item
  WHERE tenant_id = :tenant::uuid
  GROUP BY order_id
) sub
WHERE o.id = sub.order_id AND o.tenant_id = :tenant::uuid AND o.number LIKE 'DEMO-%';

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
    ('2026-10-01'::date,  6, 700, 150,  2)
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

-- Entrada por OS entregue. As cinco formas aparecem (inclusive 'outro', que
-- antes ficava de fora e deixava a legenda da rosca com um buraco), e uma a
-- cada nove leva desconto — o número irmão que o fechamento mostra à parte.
INSERT INTO cash_entry (
  id, tenant_id, cash_session_id, direction, amount, method, category,
  sale_kind, sale_id, description, discount, discount_reason,
  created_by, created_at, updated_at
)
SELECT
  gen_random_uuid(), :tenant::uuid, pg_temp.sessao_do_mes(:tenant::uuid, o.finished_at), 'in',
  -- Uma a cada sete recebe PARCIAL: é o terceiro estado de pagamento, e sem
  -- ele o card "quanto já virou dinheiro" só sabia desenhar duas fatias.
  CASE WHEN abs(hashtext(o.number)) % 7 = 0 THEN round(o.total * 0.4, 2)
       WHEN abs(hashtext(o.number)) % 9 = 0 THEN round(o.total * 0.9, 2)
       ELSE o.total END,
  (ARRAY['pix','dinheiro','cartao_credito','cartao_debito','outro'])[1 + (abs(hashtext(o.number)) % 5)],
  'os_payment', 'os', o.id,
  '[demo] Recebimento ' || o.number,
  CASE WHEN abs(hashtext(o.number)) % 9 = 0 THEN round(o.total * 0.1, 2) ELSE 0 END,
  CASE WHEN abs(hashtext(o.number)) % 9 = 0 THEN 'Desconto à vista' ELSE NULL END,
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
  (ARRAY['pix','dinheiro','cartao_debito','cartao_credito'])[1 + (abs(hashtext(s.number)) % 4)],
  'venda_avulsa', 'sale', s.id,
  '[demo] Venda ' || s.number,
  (SELECT user_id FROM membership WHERE tenant_id = :tenant::uuid LIMIT 1),
  s.created_at, now()
FROM sale s
WHERE s.tenant_id = :tenant::uuid AND s.number LIKE 'DEMO-%'
  AND s.fiado_at IS NULL;

-- Sangrias e suprimentos: lançamentos SEM venda vinculada. O card "de onde
-- vieram os recebimentos" tem um balde para eles, e vazio ele parecia defeito.
INSERT INTO cash_entry (
  id, tenant_id, cash_session_id, direction, amount, method, category,
  description, created_by, created_at, updated_at
)
SELECT
  gen_random_uuid(), :tenant::uuid, pg_temp.sessao_do_mes(:tenant::uuid, m.quando),
  m.direcao, m.valor, m.forma, m.categoria, '[demo] ' || m.texto,
  (SELECT user_id FROM membership WHERE tenant_id = :tenant::uuid LIMIT 1),
  m.quando, now()
FROM (VALUES
  (timestamptz '2026-08-06 18:30-03', 'out', 1200.00, 'dinheiro', 'sangria',    'Sangria para o banco'),
  (timestamptz '2026-08-19 18:30-03', 'out',  800.00, 'dinheiro', 'sangria',    'Sangria para o banco'),
  (timestamptz '2026-08-21 09:00-03', 'in',   500.00, 'dinheiro', 'suprimento', 'Troco do caixa'),
  (timestamptz '2026-09-04 18:30-03', 'out', 1500.00, 'dinheiro', 'sangria',    'Sangria para o banco'),
  (timestamptz '2026-09-17 18:30-03', 'out', 2200.00, 'dinheiro', 'sangria',    'Sangria para o banco'),
  (timestamptz '2026-09-09 09:00-03', 'in',   600.00, 'dinheiro', 'suprimento', 'Troco do caixa'),
  (timestamptz '2026-09-26 18:30-03', 'out',  940.00, 'dinheiro', 'sangria',    'Sangria para o banco'),
  (timestamptz '2026-10-02 09:00-03', 'in',   400.00, 'dinheiro', 'suprimento', 'Troco do caixa')
) AS m(quando, direcao, valor, forma, categoria, texto);

-- ---------------------------------------------------------------
-- Despesas — e a saída correspondente no caixa
-- ---------------------------------------------------------------
-- O relatório recorta despesa pelo VENCIMENTO. Setembro sobe ~30% contra ~12%
-- do faturamento: é o segundo alerta do mês.
--
-- Duas contas de setembro ficam VENCIDAS e não pagas de propósito. O card "o
-- que ainda não foi pago" separa em aberto de vencido, e sem uma conta
-- atrasada ele desenhava duas barras iguais.
WITH cat AS (
  SELECT name, id FROM expense_category WHERE tenant_id = :tenant::uuid
),
plano AS (
  SELECT * FROM (VALUES
    ('2026-08-01'::date, 'Fornecedor', 5000, true),  ('2026-08-05'::date, 'Aluguel', 4200, true),
    ('2026-08-07'::date, 'Energia', 1450, true),      ('2026-08-10'::date, 'Impostos', 2600, true),
    ('2026-08-12'::date, 'Internet', 320, true),      ('2026-08-15'::date, 'Produto', 1000, true),
    ('2026-08-05'::date, 'Salários', 8400, true),     ('2026-08-08'::date, 'Água', 180, true),
    ('2026-08-20'::date, 'Manutenção', 760, true),    ('2026-08-22'::date, 'Telefone', 240, true),
    ('2026-09-01'::date, 'Fornecedor', 7000, true),  ('2026-09-05'::date, 'Aluguel', 4200, true),
    ('2026-09-07'::date, 'Energia', 1980, true),      ('2026-09-10'::date, 'Impostos', 3150, false),
    ('2026-09-12'::date, 'Internet', 320, true),      ('2026-09-15'::date, 'Produto', 3520, true),
    ('2026-09-05'::date, 'Salários', 9100, true),     ('2026-09-08'::date, 'Água', 210, true),
    ('2026-09-18'::date, 'Manutenção', 1340, false),  ('2026-09-24'::date, 'Outros', 480, true),
    ('2026-10-01'::date, 'Fornecedor', 2600, false),  ('2026-10-03'::date, 'Energia', 1400, false),
    ('2026-10-05'::date, 'Aluguel', 4200, false),     ('2026-10-02'::date, 'Salários', 9100, false)
  ) AS p(venc, categoria, valor, paga)
)
INSERT INTO expense (
  id, tenant_id, description, amount, due_date, category_id, occurrence_on,
  paid_at, paid_amount, paid_method, status, created_by, created_at, updated_at
)
SELECT
  gen_random_uuid(), :tenant::uuid,
  '[demo] ' || p.categoria || ' ' || to_char(p.venc, 'MM/YYYY'),
  p.valor, p.venc, c.id, p.venc,
  CASE WHEN p.paga THEN p.venc + interval '9 hours' ELSE NULL END,
  CASE WHEN p.paga THEN p.valor ELSE NULL END,
  CASE WHEN p.paga THEN (ARRAY['pix','dinheiro','cartao_credito'])[1 + (abs(hashtext(p.categoria)) % 3)] ELSE NULL END,
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
  gen_random_uuid(), :tenant::uuid, pg_temp.sessao_do_mes(:tenant::uuid, e.paid_at), 'out', e.amount,
  coalesce(e.paid_method, 'pix'), 'despesa',
  e.description, e.created_by, e.paid_at, now()
FROM expense e
WHERE e.tenant_id = :tenant::uuid AND e.description LIKE '[demo]%' AND e.paid_at IS NOT NULL;

-- ---------------------------------------------------------------
-- Parcelas do fiado
-- ---------------------------------------------------------------
-- Toda venda fiada vira três parcelas mensais. É o que enche a tela "A receber"
-- e o que dá ao painel um "a receber vencido" diferente de zero: a primeira
-- parcela das vendas de agosto já passou da data.
INSERT INTO receivable_installment (
  id, tenant_id, sale_kind, sale_id, amount, due_date, paid_at, notes, created_at, updated_at
)
SELECT
  gen_random_uuid(), :tenant::uuid, 'sale', s.id,
  round(s.total / 3, 2),
  (s.fiado_at + (n * interval '30 days'))::date,
  -- A parcela de agosto que já venceu foi paga; a de setembro, não. Sem essa
  -- mistura o alerta de fiado vencido nunca teria o que apontar.
  CASE WHEN s.fiado_at < timestamptz '2026-09-01' AND n = 1
       THEN s.fiado_at + interval '31 days' ELSE NULL END,
  '[demo]',
  s.fiado_at, now()
FROM sale s, generate_series(1, 3) AS n
WHERE s.tenant_id = :tenant::uuid AND s.number LIKE 'DEMO-%' AND s.fiado_at IS NOT NULL;

-- ---------------------------------------------------------------
-- Estoque — o consumo das ordens derruba a prateleira
-- ---------------------------------------------------------------
-- Os itens já nascem com quantidades escolhidas à mão (há zerado, há abaixo do
-- mínimo, há folgado). Esta baixa é só para o número não contradizer as OS que
-- acabaram de consumir peça — sem deixar nenhum estoque negativo.
--
-- Só os itens DESTE seed, e arredondando para unidade. Sem o filtro, cada
-- execução mordia também o estoque que o usuário tinha cadastrado à mão; e
-- como o script é repetível, a mordida era cumulativa — rodando seis vezes,
-- uma peça com 1 unidade virou "0.12 de 6" na tela, um número que não existe
-- em prateleira nenhuma.
UPDATE inventory_item i
SET current_stock = GREATEST(
      round(i.current_stock - LEAST(consumo.qtd, i.current_stock * 0.3)),
      0
    ),
    updated_at = now()
FROM (
  SELECT inventory_item_id, sum(quantity) AS qtd
  FROM service_order_item
  WHERE tenant_id = :tenant::uuid AND kind = 'product' AND inventory_item_id IS NOT NULL
  GROUP BY inventory_item_id
) consumo
WHERE i.id = consumo.inventory_item_id AND i.tenant_id = :tenant::uuid
  AND i.sku LIKE 'DEMO-%';

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

SELECT 'OS por status' AS o_que, status, count(*) AS qtd
FROM service_order
WHERE tenant_id = :tenant::uuid AND number LIKE 'DEMO-%'
GROUP BY 2 ORDER BY 3 DESC;

SELECT 'Equipe' AS o_que, coalesce(u.full_name, 'sem responsável') AS pessoa, count(*) AS ordens
FROM service_order o LEFT JOIN users u ON u.id = o.assigned_to
WHERE o.tenant_id = :tenant::uuid AND o.number LIKE 'DEMO-%'
GROUP BY 2 ORDER BY 3 DESC;

SELECT 'Vendas por mês' AS o_que, to_char(created_at, 'YYYY-MM') AS mes,
       count(*) AS qtd, to_char(sum(total), 'FM999G999D00') AS total,
       to_char(sum(total) FILTER (WHERE fiado_at IS NOT NULL), 'FM999G999D00') AS fiado
FROM sale
WHERE tenant_id = :tenant::uuid AND number LIKE 'DEMO-%'
GROUP BY 2 ORDER BY 2;

SELECT 'Caixa por forma' AS o_que, method,
       to_char(sum(amount) FILTER (WHERE direction = 'in'), 'FM999G999D00') AS entrou,
       to_char(sum(amount) FILTER (WHERE direction = 'out'), 'FM999G999D00') AS saiu
FROM cash_entry
WHERE tenant_id = :tenant::uuid AND description LIKE '[demo]%'
GROUP BY 2 ORDER BY 2;

SELECT 'Caixa por categoria' AS o_que, category, count(*) AS lancamentos,
       to_char(sum(amount), 'FM999G999D00') AS total,
       to_char(sum(discount), 'FM999G999D00') AS desconto
FROM cash_entry
WHERE tenant_id = :tenant::uuid AND description LIKE '[demo]%'
GROUP BY 2 ORDER BY 2;

SELECT 'Despesas por mês' AS o_que, to_char(due_date, 'YYYY-MM') AS mes,
       to_char(sum(amount), 'FM999G999D00') AS total,
       to_char(sum(amount) FILTER (WHERE paid_at IS NULL), 'FM999G999D00') AS em_aberto
FROM expense
WHERE tenant_id = :tenant::uuid AND description LIKE '[demo]%'
GROUP BY 2 ORDER BY 2;

SELECT 'Estoque' AS o_que,
       count(*) AS itens,
       count(*) FILTER (WHERE current_stock <= 0) AS zerados,
       count(*) FILTER (WHERE min_stock IS NOT NULL AND current_stock < min_stock) AS abaixo_do_minimo,
       count(*) FILTER (WHERE min_stock IS NULL) AS sem_minimo,
       to_char(sum(current_stock * coalesce(cost_price, 0)), 'FM999G999D00') AS valor
FROM inventory_item
WHERE tenant_id = :tenant::uuid AND kind = 'product';

SELECT 'Parcelas de fiado' AS o_que,
       count(*) AS parcelas,
       count(*) FILTER (WHERE paid_at IS NULL) AS em_aberto,
       count(*) FILTER (WHERE paid_at IS NULL AND due_date < current_date) AS vencidas
FROM receivable_installment
WHERE tenant_id = :tenant::uuid AND notes = '[demo]';
