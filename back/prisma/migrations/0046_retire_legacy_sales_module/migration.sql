-- ============================================================
-- 0046 — Aposenta o módulo legado `sales` — aditivo, idempotente
-- ============================================================
-- A 0029 semeou o módulo `sales` e o ligou aos planos trial/pro. O módulo de
-- venda avulsa que existe hoje é `sale` (0030+), com tabelas e guard próprios
-- (@RequiresModule('sale')); `sales` ficou órfão — sem rota, sem tela, sem uso.
--
-- O baseline já desligava o tenant_module de `sales`, mas como a ligação em
-- plan_module continuava de pé, o reconcileTenantModules religava o módulo a
-- cada assinatura/troca de plano. Resultado: `sales` voltava para /me e vazava
-- na sidebar do cliente como um item cru ("sales", ícone de quebra-cabeça).
--
-- Corta a causa: tira `sales` dos planos e desliga onde estiver ligado. A linha
-- em `module` PERMANECE (sem hard delete) — é histórico, e tenant_module aponta
-- para ela.

-- 1) Desfaz a entitlement por plano — sem isto o reconcile religa tudo.
DELETE FROM plan_module pm
USING module m
WHERE m.id = pm.module_id AND m.key = 'sales';

-- 2) Desliga onde já estava ligado (idempotente: só toca o que está enabled).
UPDATE tenant_module tm
SET enabled = false
FROM module m
WHERE m.id = tm.module_id AND m.key = 'sales' AND tm.enabled;
