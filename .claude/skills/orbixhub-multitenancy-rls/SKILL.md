---
name: orbixhub-multitenancy-rls
description: Use when writing or reviewing ANY backend data access in OrbixHub (back/**) — repositories, services, migrations, public/webhook flows, or debugging "query returns empty" issues. Encodes how multi-tenancy is enforced at the DB via Postgres Row-Level Security (RLS), the TenantContext API, and the tenant/global table split.
---

# OrbixHub — Multi-tenancy & RLS

O isolamento entre tenants (oficinas) é imposto **no banco**, via Postgres Row-Level Security.
A aplicação **não** confia em filtros `WHERE tenant_id = ...` na camada de app para segurança —
o RLS é a última linha de defesa.

## Como funciona

1. O `JwtAuthGuard` verifica o access token e popula `req.user` com `tenantId` vindo **só** da
   claim `tid`.
2. O `TenantInterceptor` lê `req.user.tenantId` e grava no CLS via `TenantContext.setTenantId`.
3. Ao acessar dados, abre-se uma transação curta que executa
   `SELECT set_config('app.current_tenant_id', $tenantId, true)` e expõe o `tx` client no CLS.
4. As policies RLS comparam `tenant_id` da linha com `current_setting('app.current_tenant_id')`.

## Regras (não-negociáveis)

- **NUNCA** aceite `tenantId` de body, query ou header. Sempre do JWT verificado — ou resolvido
  no servidor em fluxos públicos (webhook → função `SECURITY DEFINER`).
- Em tabelas com RLS, repositórios usam `tenant.getClient()` — **nunca** `PrismaService` direto.
  Fora de uma tx com tenant setado, `getClient()` devolve o client base que **vê zero linhas**.
- A app conecta como `app_user` (RLS imposto, NOBYPASSRLS). Migrations como `app_migrator`
  (BYPASSRLS). DDL/baseline como `app_owner`. Confira `DATABASE_URL` vs `MIGRATION_DATABASE_URL`.
- Tabelas de tenant têm **RLS + FORCE** e policy `tenant_isolation` (`tenant_id = current_tenant_id()`).

## API do `TenantContext` (`src/common/database/tenant-context.ts`)

| Método | Quando usar |
|--------|-------------|
| `withTenantTx(fn)` | Fluxo autenticado normal — usa o tenant do request (CLS). |
| `runWithTenant(tenantId, fn)` | Fluxo público/sistema (webhook, job) com tenant resolvido no servidor. |
| `bindTx(tx, tenantId, fn)` | Quando uma tx externa já está aberta e os repos internos devem enxergá-la. |
| `getClient()` | Dentro de repositórios — devolve o tx client (ou base, que vê zero linhas). |
| `withoutTenant(fn)` | Apenas tabelas globais/auth (sem RLS), ex.: `users`, `refresh_token`. |

## Tabelas

- **Com RLS** (isoladas por tenant): `membership`, `invite`, `subscription`, `tenant_module`,
  `audit_log`, `customer`, `subject`, `inventory_item`, `stock_movement`, `service_order(_item/_event/_photo)`,
  `service_order_template(_item)`, `conversation`, `message`, `notification`, e as novas
  `invoice`, `invoice_line`, `invoice_event`.
- **Globais** (sem RLS): `tenant`, `users`, `role`, `permission`, `role_permission`, `module`,
  `plan`, `plan_module`, `one_time_token`, `refresh_token`, `login_attempt`,
  `billing_webhook_event`, `invoice_webhook_event`, `catalog_product`.

> Globais podem ser lidas com `PrismaService`/`getClient()` sem tenant. Ainda assim, prefira
> `withoutTenant` para deixar a intenção explícita.

## Armadilha comum

Query a tabela com RLS retorna vazio inesperadamente? Quase sempre é porque o código rodou
**fora** de `withTenantTx`/`runWithTenant` — `app.current_tenant_id` não estava setado.
