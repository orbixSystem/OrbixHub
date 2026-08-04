-- ============================================================
-- 0039 — Módulo `expenses` (Despesas / lembrete de pagamento) — aditivo, idempotente
-- ============================================================
-- O que a cliente pediu: um lugar para dizer O QUE tem que pagar, QUANDO, QUANTO,
-- se REPETE todo mês e se já FOI PAGO — com categoria para bater o olho.
--
-- Três tabelas, e a divisão entre elas é a decisão de projeto central:
--
--   expense_category   — o rótulo (nome + ícone + cor). Editável pelo tenant.
--   expense_recurrence — a REGRA ("todo dia 10, Aluguel, R$ 2.500").
--   expense            — a CONTA de um mês específico (vence em 10/09, foi paga tal dia).
--
-- A regra não é a conta. Separar permite mudar o valor de UM mês (a luz veio mais
-- cara) sem reescrever o histórico nem a regra, e permite parar a regra sem apagar
-- o que já foi pago. É a mesma lógica do snapshot histórico da OS (regra 2).
--
-- Esta migration NÃO derruba `cash_expense_template` (migrations são aditivas —
-- regra 9): ela COPIA os modelos de despesa de lá para cá. A tabela antiga fica
-- órfã de código quando o caixa parar de usá-la.
CREATE TABLE IF NOT EXISTS expense_category (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id  uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  name       text NOT NULL,
  -- Chave SIMBÓLICA ('aluguel', 'energia'…), não codepoint de ícone: o Flutter
  -- faz tree-shake dos ícones e um IconData montado em runtime a partir de um
  -- número vindo do banco vira quadrado vazio no build de release. O front mapeia
  -- a chave para um IconData const.
  icon       text NOT NULL DEFAULT 'outros',
  -- Hex #RRGGBB. Cor da CATEGORIA (identidade visual); não confundir com a cor de
  -- STATUS (pago/a pagar/vencido), que é derivada e vive no tema.
  color      text NOT NULL DEFAULT '#6B7280',
  status     text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT expense_category_name_chk   CHECK (length(btrim(name)) > 0),
  CONSTRAINT expense_category_color_chk  CHECK (color ~ '^#[0-9A-Fa-f]{6}$'),
  CONSTRAINT expense_category_status_chk CHECK (status IN ('active','disabled'))
);

-- Unique só entre as ativas: "Energia" pode ser recriada depois de desativada.
CREATE UNIQUE INDEX IF NOT EXISTS uq_expense_category_name
  ON expense_category (tenant_id, lower(btrim(name)))
  WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_expense_category_tenant_updated
  ON expense_category(tenant_id, updated_at);

-- ------------------------------------------------------------
-- expense_recurrence — a regra que gera as contas
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS expense_recurrence (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  description   text NOT NULL,
  -- 0 = "o valor varia" (conta de luz). Herdado do `cash_expense_template`: evita
  -- inventar um segundo conceito de "sem valor" (NULL) para a mesma ideia.
  amount        numeric(14,2) NOT NULL DEFAULT 0,
  category_id   uuid REFERENCES expense_category(id) ON DELETE SET NULL,
  frequency     text NOT NULL DEFAULT 'monthly',
  -- 1..31. Mês curto encurta o dia (31 em fevereiro → 28/29); quem resolve é o
  -- gerador, não um CHECK — o dia pedido continua gravado como pedido.
  day_of_month  smallint NOT NULL DEFAULT 1,
  -- Só para frequency='yearly' (IPVA, licença, alvará).
  month_of_year smallint,
  method        text,
  notes         text,
  starts_on     date NOT NULL DEFAULT CURRENT_DATE,
  -- NULL = sem fim previsto.
  ends_on       date,
  -- Até onde a esteira já materializou contas. NULL = nada gerado ainda.
  generated_through date,
  status        text NOT NULL DEFAULT 'active',
  created_by    uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT expense_recurrence_desc_chk   CHECK (length(btrim(description)) > 0),
  CONSTRAINT expense_recurrence_amount_chk CHECK (amount >= 0),
  CONSTRAINT expense_recurrence_freq_chk   CHECK (frequency IN ('monthly','yearly')),
  CONSTRAINT expense_recurrence_dom_chk    CHECK (day_of_month BETWEEN 1 AND 31),
  CONSTRAINT expense_recurrence_moy_chk    CHECK (month_of_year IS NULL OR month_of_year BETWEEN 1 AND 12),
  -- Anual sem mês não sabe quando vencer.
  CONSTRAINT expense_recurrence_yearly_chk CHECK (frequency <> 'yearly' OR month_of_year IS NOT NULL),
  CONSTRAINT expense_recurrence_method_chk CHECK (method IS NULL OR method IN ('pix','dinheiro','cartao_credito','cartao_debito','outro')),
  CONSTRAINT expense_recurrence_ends_chk   CHECK (ends_on IS NULL OR ends_on >= starts_on),
  CONSTRAINT expense_recurrence_status_chk CHECK (status IN ('active','disabled'))
);

CREATE INDEX IF NOT EXISTS idx_expense_recurrence_tenant_status
  ON expense_recurrence(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_expense_recurrence_tenant_updated
  ON expense_recurrence(tenant_id, updated_at);

-- ------------------------------------------------------------
-- expense — a conta a pagar de um vencimento específico
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS expense (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  description   text NOT NULL,
  -- 0 = "valor a confirmar": a conta existe e cobra atenção mesmo antes de o
  -- boleto chegar. O app pergunta o valor na hora de marcar como paga.
  amount        numeric(14,2) NOT NULL DEFAULT 0,
  -- `date` e não `timestamptz`: vencimento é dia civil. Guardar instante faria a
  -- conta "mudar de dia" conforme o fuso de quem lê.
  due_date      date NOT NULL,
  category_id   uuid REFERENCES expense_category(id) ON DELETE SET NULL,
  -- Regra que gerou esta conta (NULL = avulsa). ON DELETE SET NULL para que
  -- desistir da regra não apague o que já foi pago.
  recurrence_id uuid REFERENCES expense_recurrence(id) ON DELETE SET NULL,
  -- Qual ocorrência da regra esta linha representa. É a chave da idempotência da
  -- esteira: rodar o gerador duas vezes não duplica o aluguel de setembro.
  occurrence_on date,
  -- ÚNICO fato gravado sobre pagamento. "pago / a pagar / vence em breve /
  -- vencido" é DERIVADO daqui + due_date + hoje. Status materializado precisaria
  -- de um job diário só para envelhecer linha, e ficaria errado entre execuções.
  paid_at       timestamptz,
  -- Pode divergir de `amount` (juros, desconto) — o que saiu é o que saiu.
  paid_amount   numeric(14,2),
  paid_method   text,
  -- Ponte com o Caixa: guarda só o ID (regra 1 — "aponta, não invade"). Este
  -- módulo NUNCA lê nem escreve `cash_entry`; quem cria o lançamento é o service
  -- público do caixa, e o id volta para cá.
  cash_entry_id uuid,
  notes         text,
  -- Sem hard delete (regra 6): cancelar preserva o histórico.
  status        text NOT NULL DEFAULT 'active',
  created_by    uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT expense_desc_chk        CHECK (length(btrim(description)) > 0),
  CONSTRAINT expense_amount_chk      CHECK (amount >= 0),
  CONSTRAINT expense_paid_amount_chk CHECK (paid_amount IS NULL OR paid_amount >= 0),
  CONSTRAINT expense_method_chk      CHECK (paid_method IS NULL OR paid_method IN ('pix','dinheiro','cartao_credito','cartao_debito','outro')),
  CONSTRAINT expense_status_chk      CHECK (status IN ('active','canceled')),
  -- Conta gerada por regra sabe de qual ocorrência veio; avulsa não tem regra.
  CONSTRAINT expense_occurrence_chk  CHECK (recurrence_id IS NULL OR occurrence_on IS NOT NULL)
);

-- Idempotência da esteira: uma conta por ocorrência da regra.
CREATE UNIQUE INDEX IF NOT EXISTS uq_expense_recurrence_occurrence
  ON expense (tenant_id, recurrence_id, occurrence_on)
  WHERE recurrence_id IS NOT NULL;

-- A tela abre no mês e ordena por vencimento — este é o índice que ela usa.
CREATE INDEX IF NOT EXISTS idx_expense_tenant_due
  ON expense(tenant_id, due_date);
-- "O que está em aberto/vencido": varre só as não pagas.
CREATE INDEX IF NOT EXISTS idx_expense_tenant_open
  ON expense(tenant_id, due_date)
  WHERE paid_at IS NULL AND status = 'active';
CREATE INDEX IF NOT EXISTS idx_expense_tenant_category
  ON expense(tenant_id, category_id);
-- Pull incremental do sync offline.
CREATE INDEX IF NOT EXISTS idx_expense_tenant_updated
  ON expense(tenant_id, updated_at);

-- ------------------------------------------------------------
-- RLS + FORCE + policy nas três (idempotente)
-- ------------------------------------------------------------
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['expense_category','expense_recurrence','expense'] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', t);
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies WHERE tablename = t AND policyname = 'tenant_isolation'
    ) THEN
      EXECUTE format(
        'CREATE POLICY tenant_isolation ON %I USING (tenant_id = current_tenant_id()) WITH CHECK (tenant_id = current_tenant_id())',
        t
      );
    END IF;
  END LOOP;
END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON expense_category   TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON expense_recurrence TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON expense            TO app_user;

-- ------------------------------------------------------------
-- Módulo contratável + planos + backfill dos tenants existentes
-- ------------------------------------------------------------
INSERT INTO module (key, name, is_core) VALUES
  ('expenses','Despesas', false)
ON CONFLICT (key) DO NOTHING;

INSERT INTO plan_module (plan_id, module_id)
SELECT pl.id, m.id FROM plan pl JOIN module m ON m.key = 'expenses'
WHERE pl.key IN ('trial','pro')
ON CONFLICT DO NOTHING;

INSERT INTO tenant_module (tenant_id, module_id, enabled, source)
SELECT t.id, m.id, true, 'plan'
FROM tenant t CROSS JOIN module m
WHERE m.key = 'expenses'
ON CONFLICT (tenant_id, module_id) DO NOTHING;

-- ------------------------------------------------------------
-- Permissões — reaproveita `finance.read`/`finance.write`
-- ------------------------------------------------------------
-- Já existem semeadas desde a 0004 e nenhum módulo as consumia. Pagar contas é
-- exatamente "financeiro"; criar `expense.*` seria um segundo vocabulário para o
-- mesmo conceito. `caixa` vê mas não mexe: quem opera a gaveta não decide contas.
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON p.key IN ('finance.read','finance.write')
WHERE r.key IN ('owner','gerente')
ON CONFLICT DO NOTHING;

INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON p.key = 'finance.read'
WHERE r.key = 'caixa'
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- Categorias padrão por tenant (backfill dos existentes)
-- ------------------------------------------------------------
-- Tenant novo recebe as mesmas no primeiro acesso ao módulo (o service semeia,
-- idempotente) — assim o registro de tenant não precisa conhecer `expenses`.
INSERT INTO expense_category (tenant_id, name, icon, color)
SELECT t.id, c.name, c.icon, c.color
FROM tenant t
CROSS JOIN (VALUES
  ('Aluguel',     'aluguel',     '#F97316'),
  ('Energia',     'energia',     '#EAB308'),
  ('Água',        'agua',        '#38BDF8'),
  ('Internet',    'internet',    '#8B5CF6'),
  ('Telefone',    'telefone',    '#06B6D4'),
  ('Impostos',    'impostos',    '#EF4444'),
  ('Fornecedor',  'fornecedor',  '#10B981'),
  ('Salários',    'salarios',    '#3B82F6'),
  ('Manutenção',  'manutencao',  '#A16207'),
  ('Outros',      'outros',      '#6B7280')
) AS c(name, icon, color)
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- Migração dos modelos de despesa fixa do Caixa (0038) → regra de recorrência
-- ------------------------------------------------------------
-- Só `category='despesa'`: os modelos de SANGRIA ficam onde estão. Sangria é
-- retirada da gaveta, não conta a pagar — não tem vencimento nem "foi pago".
--
-- `day_of_month = 1` porque o modelo antigo não guardava vencimento: é o palpite
-- honesto, e a cliente ajusta. `generated_through = NULL` deixa a esteira gerar
-- as contas na primeira execução.
INSERT INTO expense_recurrence
  (tenant_id, description, amount, category_id, frequency, day_of_month, method,
   starts_on, status, created_by, created_at)
SELECT
  tpl.tenant_id,
  tpl.name,
  tpl.amount,
  (SELECT c.id FROM expense_category c
    WHERE c.tenant_id = tpl.tenant_id AND c.icon = 'outros' AND c.status = 'active'
    LIMIT 1),
  'monthly',
  1,
  tpl.method,
  CURRENT_DATE,
  tpl.status,
  tpl.created_by,
  tpl.created_at
FROM cash_expense_template tpl
WHERE tpl.category = 'despesa'
  AND NOT EXISTS (
    SELECT 1 FROM expense_recurrence r
    WHERE r.tenant_id = tpl.tenant_id
      AND lower(btrim(r.description)) = lower(btrim(tpl.name))
  );

-- ------------------------------------------------------------
-- expenses_find_recurrences_to_extend (SECURITY DEFINER)
-- ------------------------------------------------------------
-- O job diário da esteira precisa varrer TODOS os tenants, e é justamente isso
-- que a RLS impede para o `app_user` — sem tenant no CLS a policy não deixa ler
-- nada. Mesmo desenho de `billing_find_expired_trials`: a função roda como o
-- dono (app_owner) e devolve só os PONTEIROS (tenant_id + id da regra); o job
-- então entra em cada tenant com `runWithTenant`, e a partir daí toda escrita
-- volta a passar pela RLS normalmente.
--
-- Devolve ponteiro e não a linha inteira de propósito: assim a função não vira
-- uma porta lateral para ler dados de outros tenants.
CREATE OR REPLACE FUNCTION expenses_find_recurrences_to_extend(p_ate date)
RETURNS TABLE (tenant_id uuid, recurrence_id uuid)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT r.tenant_id, r.id
  FROM expense_recurrence r
  WHERE r.status = 'active'
    -- Ainda não alcançou o horizonte pedido.
    AND (r.generated_through IS NULL OR r.generated_through < p_ate)
    -- Regra encerrada não gera mais nada.
    AND (r.ends_on IS NULL OR r.ends_on >= CURRENT_DATE)
  ORDER BY r.tenant_id, r.id
$$;

REVOKE ALL ON FUNCTION expenses_find_recurrences_to_extend(date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION expenses_find_recurrences_to_extend(date) TO app_user;
