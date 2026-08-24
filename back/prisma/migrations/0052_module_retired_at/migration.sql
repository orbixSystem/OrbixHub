-- ============================================================
-- 0052 — Módulo aposentado sai do catálogo — aditivo, idempotente
-- ============================================================
-- A 0046 tirou o módulo legado `sales` dos planos e o desligou nos tenants,
-- mas a linha continuou no catálogo `module`. Como `listTenantModules` lista o
-- catálogo inteiro, `sales` seguiu aparecendo como um toggle morto — na tela de
-- Configurações do próprio cliente e, agora, no painel administrativo. Pior:
-- quem clicasse nele reintroduziria exatamente o bug que a 0046 corrigiu.
--
-- `retired_at` diz "isto existiu": a linha PERMANECE (tenant_module aponta para
-- ela e o histórico importa), mas some das listas e não pode ser religada.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'module' AND column_name = 'retired_at'
  ) THEN
    ALTER TABLE module ADD COLUMN retired_at timestamptz;
  END IF;
END $$;

UPDATE module SET retired_at = now() WHERE key = 'sales' AND retired_at IS NULL;
