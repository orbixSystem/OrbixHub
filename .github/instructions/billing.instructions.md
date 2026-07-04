---
applyTo: "back/src/modules/billing/**"
description: "Billing: planos, trial, assinatura, webhooks idempotentes e acesso a módulos."
---

# Billing & Acesso a Módulos

## Conceitos

- **plan** → conjunto de **module** (via `plan_module`). Cada tenant tem uma **subscription**
  e linhas em **tenant_module** (módulos habilitados). `reconcile(tenantId, planId)` sincroniza
  `tenant_module` a partir do plano.
- **Trial**: `createTrial` é chamado **dentro da tx do register** (via `getClient()`), cria a
  subscription com `status: 'trialing'` e `trial_ends_at = now + TRIAL_DAYS`.
- Plano `TRIAL_PLAN_KEY` é interno e **excluído** do catálogo público (`getPlans`).

## Pagamento e webhooks

- `BILLING_REQUIRE_PAYMENT` controla o fluxo:
  - **true**: chama `gateway.createCheckout` **antes e fora** de qualquer tx; subscription fica
    pendente (`trialing`) até o webhook confirmar `active`. `reconcile` é adiado para o webhook.
  - **false**: ativa direto (`active`) e faz `reconcile` na hora.
- `processWebhook`:
  1. **Verifica a assinatura** (`gateway.verifySignature`) — rejeita inválida com 400.
  2. **Dedupe/idempotência**: insere `billing_webhook_event` (unique `external_event_id`);
     `P2002` → reprocessa só se `processed_at` ainda nulo, senão no-op.
  3. **Resolve o tenant pelo `external_subscription_id`** (`resolveTenantBySubscription`) —
     **nunca** confia em tenant id vindo do payload.
  4. Atualiza status sob `runWithTenant(tenantId, ...)`, audita e marca `processed_at`.

> Use o `rawBody` (configurado em `main.ts` com `rawBody: true`) para verificar assinatura;
> não use o corpo já parseado.

## `ModuleAccessGuard` + `@RequiresModule('key')`

- Guard roda **antes** do `TenantInterceptor`, então abre contexto explicitamente com
  `runWithTenant(user.tenantId, ...)`.
- Regras:
  - módulo não-core e `tenant_module.enabled = false` → `403`;
  - `status` `trialing`/`active` → permite;
  - `past_due` → permite só **leitura** (GET/HEAD/OPTIONS);
  - qualquer outro status → `403`.

## Job de expiração de trial

- `trial-expiry.job.ts` (`@nestjs/schedule`) varre subscriptions `trialing` vencidas e ajusta
  o status. Mantém o comportamento idempotente.
