---
applyTo: "back/**"
description: "Multi-tenancy e Postgres Row-Level Security (RLS) — o núcleo de isolamento do OrbixHub."
---

# Multi-tenancy & RLS

O isolamento entre oficinas (tenants) é imposto **no banco**, via Postgres Row-Level
Security. A aplicação **não** confia em filtros `WHERE tenant_id = ...` na camada de
aplicação para segurança — o RLS é a última linha de defesa.

## Como funciona

1. O `JwtAuthGuard` verifica o access token e popula `req.user` com `tenantId` vindo da
   claim `tid` (e somente dela).
2. O `TenantInterceptor` lê `req.user.tenantId` e grava no CLS via `TenantContext.setTenantId`.
3. Ao acessar dados, abre-se uma transação curta que executa
   `SELECT set_config('app.current_tenant_id', $tenantId, true)` e expõe o `tx` client no CLS.
4. As policies RLS comparam `tenant_id` da linha com `current_setting('app.current_tenant_id')`.

## Regras

- **NUNCA** aceite `tenantId` vindo de body, query ou header. Sempre do JWT verificado
  (ou resolvido pelo servidor em fluxos públicos, ex.: webhook → `resolveTenantBySubscription`).
- Em tabelas com RLS, repositórios usam `tenant.getClient()` — **nunca** `PrismaService` direto.
  Fora de uma tx com tenant setado, `getClient()` devolve o client base que **vê zero linhas**.
- A app conecta como `app_user` (RLS imposto, sem BYPASSRLS). Migrations rodam como
  `app_migrator` (BYPASSRLS). Confira `DATABASE_URL` vs `MIGRATION_DATABASE_URL`.

## API do `TenantContext` (`src/common/database/tenant-context.ts`)

| Método | Quando usar |
|--------|-------------|
| `withTenantTx(fn)` | Fluxo autenticado normal — usa o tenant do request (CLS). |
| `runWithTenant(tenantId, fn)` | Fluxo público/sistema (webhook, job) com tenant resolvido no servidor. |
| `bindTx(tx, tenantId, fn)` | Quando uma tx externa já está aberta e os repos internos devem enxergá-la. |
| `getClient()` | Dentro de repositórios — devolve o tx client (ou base, que vê zero linhas). |
| `withoutTenant(fn)` | Apenas tabelas globais/auth (sem RLS), ex.: `users`, `refresh_token`. |

## Tabelas

- **Com RLS** (isoladas): `tenant`, `membership`, `invite`, `subscription`, `tenant_module`,
  `audit_log`.
- **Globais** (sem RLS): `users`, `role`, `permission`, `role_permission`, `module`, `plan`,
  `plan_module`, `one_time_token`, `refresh_token`, `login_attempt`, `billing_webhook_event`.

> Tabelas globais podem ser lidas com `PrismaService`/`getClient()` mesmo sem tenant, pois
> não têm policy RLS. Ainda assim, prefira `withoutTenant` para deixar a intenção explícita.

## Armadilha comum

Se uma query a tabela com RLS retorna vazio inesperadamente, quase sempre é porque o código
rodou **fora** de `withTenantTx`/`runWithTenant` — o `app.current_tenant_id` não estava setado.
