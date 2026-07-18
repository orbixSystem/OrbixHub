-- back/prisma/migrations/0028_cashier_manage/migration.sql
-- ============================================================
-- 0028 — Permissão `cashier.manage` (gestão do caixa) — aditivo, idempotente
-- ============================================================
-- Separa o que o ATENDENTE (cargo `caixa`) pode fazer (receber OS / venda avulsa
-- = `cashier.write`) do que é privilégio de DONO/GERENTE: abrir/fechar caixa,
-- despesa/sangria/suprimento, estorno e o Histórico do caixa (`cashier.manage`).
-- owner/gerente ganham; `caixa`/`mechanic` NÃO. Permission é tabela global (sem RLS).

INSERT INTO permission (key, name) VALUES
  ('cashier.manage','Gerenciar caixa')
ON CONFLICT (key) DO NOTHING;

-- owner: re-grant (ganha qualquer permissão nova).
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r, permission p WHERE r.key = 'owner'
ON CONFLICT DO NOTHING;

-- gerente: todas, exceto billing.manage (logo, ganha cashier.manage).
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r, permission p
WHERE r.key = 'gerente' AND p.key <> 'billing.manage'
ON CONFLICT DO NOTHING;

-- `caixa` e `mechanic` NÃO recebem cashier.manage (atendente não gerencia o caixa).
