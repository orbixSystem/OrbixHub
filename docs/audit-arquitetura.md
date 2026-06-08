# Mini-audit de arquitetura — OrbixHub

**Data:** 2026-06-08
**Escopo:** varredura das regras de ouro, com foco na regra-mãe **"módulos
independentes — aponta, não invade"** (um módulo nunca lê/escreve a *tabela* de
outro módulo; busca via *service público*). Relatório apenas — **nada corrigido**.

## Resumo

| # | Severidade | Arquivo:linha | Regra ferida | Status |
|---|-----------|---------------|--------------|--------|
| 1 | **Alta** | `back/src/modules/settings/settings.repository.ts:26-34` | Independência — lia `tenant_module` + `module` (módulo **billing**) | ✅ **Corrigida** (2026-06-08) |
| 2 | Média | `back/src/modules/settings/settings.repository.ts:13-16` | Independência — lê `tenant` (módulo **tenancy**) | Aberta |
| 3 | Média | `back/src/modules/settings/settings.repository.ts:18-23` | Independência — escreve `tenant` (módulo **tenancy**) | Aberta |

Nenhuma outra violação encontrada. `auth`, `iam`, `billing`, `tenancy` e `devtools`
respeitam as fronteiras. Em particular, **`TenancyService` lê módulos do jeito certo**:
chama `BillingService.getEnabledModules(tenantId)` (service público), não a tabela —
é o exemplo de referência de "aponta, não invade".

---

## Detalhe das violações

### 1. Settings lê tabelas do Billing (`tenant_module` e `module`) — ALTA

`back/src/modules/settings/settings.repository.ts:26-34`

```ts
async enabledModuleKeys(): Promise<string[]> {
  return this.tenant.withTenantTx(async () => {
    const db = this.tenant.getClient();
    const rows = await db.tenant_module.findMany({ where: { enabled: true } }); // tabela do billing
    const ids = rows.map((r) => r.module_id);
    const mods = await this.prisma.module.findMany({ where: { id: { in: ids } } }); // tabela do billing
    return mods.map((m) => m.key);
  });
}
```

`tenant_module` e `module` são propriedade do módulo **billing**. O billing **já
expõe** o método público equivalente: `BillingService.getEnabledModules(tenantId)`.
Settings deveria injetar `BillingService` e chamá-lo, em vez de consultar as tabelas
diretamente. É o caso textbook de "invadir em vez de apontar".

**✅ Corrigida (2026-06-08):** `enabledModuleKeys()` removido do `SettingsRepository`;
`SettingsService` agora injeta `BillingService` e usa `getEnabledModules(user.tenantId)`;
`SettingsModule` importa `BillingModule`. Unit tests (4 de settings, 83 no total) e lint
verdes. Settings não toca mais `tenant_module`/`module`.

### 2 e 3. Settings lê e escreve a tabela `tenant` (módulo Tenancy) — MÉDIA

`back/src/modules/settings/settings.repository.ts:13-23`

```ts
async getCompany(tenantId: string) {
  const t = await this.prisma.tenant.findUnique({ where: { id: tenantId } }); // :14 leitura
  return (t?.settings as Record<string, unknown>) ?? {};
}
async updateCompany(tenantId: string, merged: Record<string, unknown>) {
  await this.prisma.tenant.update({                                           // :19 escrita
    where: { id: tenantId },
    data: { settings: merged as Prisma.InputJsonValue },
  });
}
```

A tabela `tenant` é propriedade do módulo **tenancy**. Settings persiste a config da
empresa no `tenant.settings` (JSONB), mas o faz tocando a tabela alheia diretamente.

**Nuance:** dá pra argumentar que `settings` é um *host* e que `tenant.settings` é "o
lugar da config" — mas pela letra da regra 1 isso ainda é acessar a tabela de outro
módulo. **Correção sugerida (não aplicada):** Tenancy expõe
`getTenantSettings(tid)` / `updateTenantSettings(tid, patch)` e Settings chama esses
métodos. Alternativa de longo prazo: dar a Settings sua própria tabela
(`tenant_settings` RLS) e deixar de depender de `tenant.settings`.

---

## Demais regras de ouro — sem violações observadas

- **RLS/multi-tenant:** `tenant_id` vem do JWT (CLS); tabelas de tenant têm RLS+FORCE;
  repositórios usam `getClient()` sob `withTenantTx`/`runWithTenant`; fluxos públicos
  (webhook, invite, trial job) resolvem tenant via funções `SECURITY DEFINER`. OK.
- **Sem hard delete:** desativação via `status='disabled'`, `canceled_at`,
  `access_expires_at`. OK.
- **Segurança:** ORM parametrizado; segredos via Zod env; webhook com assinatura HMAC +
  idempotência; dev-inbox gated por `DEV_TOOLS_ENABLED`. Nenhuma chamada externa dentro
  de transação observada. OK.
- **Mutações sensíveis:** `@Permissions` + `AuditService.log` + reauth nas operações de
  IAM. OK.
- **Front:** UI fala só com repository (interface no domain + impl dio + fake); models
  freezed; estado selado. OK.

> Observação: as violações 1-3 estão concentradas no `SettingsRepository`. Como
> `settings` é um módulo **host** novo, vale priorizar o conserto da #1 (service público
> já existe) e decidir o destino do `tenant.settings` para #2/#3.
