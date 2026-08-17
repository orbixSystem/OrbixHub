-- ============================================================
-- 0045 â€” Aposenta o mÃ³dulo legado `sales` â€” aditivo, idempotente
-- ============================================================
-- A 0029 semeou o mÃ³dulo `sales` e o ligou aos planos trial/pro. O mÃ³dulo de
-- venda avulsa que existe hoje Ã© `sale` (0030+), com tabelas e guard prÃ³prios
-- (@RequiresModule('sale')); `sales` ficou Ã³rfÃ£o â€” sem rota, sem tela, sem uso.
--
-- O baseline jÃ¡ desligava o tenant_module de `sales`, mas como a ligaÃ§Ã£o em
-- plan_module continuava de pÃ©, o reconcileTenantModules religava o mÃ³dulo a
-- cada assinatura/troca de plano. Resultado: `sales` voltava para /me e vazava
-- na sidebar do cliente como um item cru ("sales", Ã­cone de quebra-cabeÃ§a).
--
-- Corta a causa: tira `sales` dos planos e desliga onde estiver ligado. A linha
-- em `module` PERMANECE (sem hard delete) â€” Ã© histÃ³rico, e tenant_module aponta
-- para ela.

-- 1) Desfaz a entitlement por plano â€” sem isto o reconcile religa tudo.
DELETE FROM plan_module pm
USING module m
WHERE m.id = pm.module_id AND m.key = 'sales';

-- 2) Desliga onde jÃ¡ estava ligado (idempotente: sÃ³ toca o que estÃ¡ enabled).
UPDATE tenant_module tm
SET enabled = false
FROM module m
WHERE m.id = tm.module_id AND m.key = 'sales' AND tm.enabled;
