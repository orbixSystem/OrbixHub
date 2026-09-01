-- 0055 — planos comerciais: Essencial e Profissional (aditivo, idempotente)
--
-- Antes existiam `trial` e `pro`, e os dois liberavam os MESMOS 8 módulos — o
-- plano era etiqueta, não régua: ninguém tinha motivo para subir. Agora a
-- diferença é o que o cliente pode fazer:
--
--   Essencial    — a operação inteira: OS, clientes, estoque, caixa, despesas,
--                  venda avulsa. Oficina pequena roda completa aqui.
--   Profissional — acrescenta relatórios e nota fiscal, que é o que aparece
--                  quando o negócio cresce (gestão e obrigação fiscal).
--
-- `trial` continua liberando tudo de propósito: o teste tem que mostrar o
-- produto inteiro, senão o cliente decide sem ter visto o que está comprando.

INSERT INTO plan (key, name, price_cents, billing_period)
VALUES ('essencial', 'Essencial', 9900, 'monthly')
ON CONFLICT (key) DO UPDATE
  SET name = EXCLUDED.name,
      price_cents = EXCLUDED.price_cents,
      billing_period = EXCLUDED.billing_period;

INSERT INTO plan (key, name, price_cents, billing_period)
VALUES ('profissional', 'Profissional', 21900, 'monthly')
ON CONFLICT (key) DO UPDATE
  SET name = EXCLUDED.name,
      price_cents = EXCLUDED.price_cents,
      billing_period = EXCLUDED.billing_period;

-- Módulos do Essencial.
INSERT INTO plan_module (plan_id, module_id)
SELECT p.id, m.id
FROM plan p, module m
WHERE p.key = 'essencial'
  AND m.key IN ('os', 'customers', 'inventory', 'cashier', 'expenses', 'sale')
ON CONFLICT (plan_id, module_id) DO NOTHING;

-- Módulos do Profissional: os do Essencial + relatórios + nota fiscal.
INSERT INTO plan_module (plan_id, module_id)
SELECT p.id, m.id
FROM plan p, module m
WHERE p.key = 'profissional'
  AND m.key IN ('os', 'customers', 'inventory', 'cashier', 'expenses', 'sale',
                'report', 'invoice')
ON CONFLICT (plan_id, module_id) DO NOTHING;

-- Aposenta o `pro`. Só sai se NINGUÉM o assina — a condição existe para o
-- baseline continuar seguro de rodar em qualquer banco, inclusive um onde
-- alguém tenha assinado o `pro` depois desta migration nascer.
DELETE FROM plan_module
WHERE plan_id IN (
  SELECT p.id FROM plan p
  WHERE p.key = 'pro'
    AND NOT EXISTS (SELECT 1 FROM subscription s WHERE s.plan_id = p.id)
);
DELETE FROM plan p
WHERE p.key = 'pro'
  AND NOT EXISTS (SELECT 1 FROM subscription s WHERE s.plan_id = p.id);
