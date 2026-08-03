-- 0037 — Caixa: todos os tenants passam a NÃO exigir caixa aberto.
--
-- A cerimônia de abrir/fechar existe para CONFERIR GAVETA de dinheiro. A maioria
-- das oficinas recebe por Pix/cartão, ou opera com o próprio dono no caixa — para
-- elas o ritual é atrito sem contrapartida, e o default do código já é `false`
-- (`DEFAULT_CASHIER_CONFIG`). Tenants criados ANTES dessa mudança podem ter
-- `requireOpenSession: true` gravado em `tenant_module.settings`, e o valor
-- salvo vence o default — então continuariam presos na cerimônia.
--
-- Esta migration alinha os existentes ao novo padrão. É DATA, não schema (nenhuma
-- coluna muda), e sobrescreve deliberadamente quem tinha `true`: é a decisão de
-- produto. Quem quiser a conferência de gaveta de volta reativa em
-- Configurações › Caixa (`PATCH /settings/section/cashier`).
--
-- Idempotente: rodar de novo apenas reescreve `false` onde já está `false`.
-- ATENÇÃO ao `jsonb_set`: ele NÃO cria níveis intermediários (só a última chave),
-- então em `settings` vazio/nulo o caminho `{cashier,requireOpenSession}` era
-- ignorado e o UPDATE não surtia efeito — além de reescrever a linha toda rodada.
-- Daí o merge de objeto (`||`), que constrói o nível `cashier` quando falta.
UPDATE tenant_module AS tm
SET settings = COALESCE(tm.settings, '{}'::jsonb)
               || jsonb_build_object(
                    'cashier',
                    COALESCE(tm.settings -> 'cashier', '{}'::jsonb)
                      || jsonb_build_object('requireOpenSession', false)
                  )
FROM module AS m
WHERE m.id = tm.module_id
  AND m.key = 'cashier'
  -- Só o que ainda não está `false`: mantém o UPDATE idempotente (2ª rodada = 0
  -- linhas) e evita reescrever WAL sem motivo.
  AND COALESCE(tm.settings #> '{cashier,requireOpenSession}', 'null'::jsonb)
      IS DISTINCT FROM 'false'::jsonb;
