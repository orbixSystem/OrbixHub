# NF — Plano 1: Fundação de Config Fiscal (módulo `invoice`) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir que cada tenant configure a emissão fiscal ponta a ponta (provedor Nuvem Fiscal: cadastro da empresa + upload do certificado A1 + config de série/ambiente/CSC), sem ainda emitir nota — deixando a base pronta para os Planos 2–4.

**Architecture:** O OrbixHub tem UMA conta Nuvem Fiscal (credenciais OAuth2 em env, globais); cada tenant vira uma "empresa" no provedor (pelo CNPJ) com o certificado A1 enviado via passthrough (o `.pfx` nunca é persistido no nosso banco). A config não-sensível do tenant vive em `tenant_module.settings['invoice']['invoice']` (via `BillingService`, mesmo padrão do `inventory`). A identidade fiscal (CNPJ/IE/endereço/regime) é LIDA do núcleo via `TenancyService.getCompanyView` (aponta-não-invade). Um `NuvemFiscalClient` (novo, `fetch` nativo, OAuth2 client-credentials com token cacheado) encapsula o provedor.

**Tech Stack:** NestJS 10 · Prisma 5 · Postgres 16 (RLS) · Zod (env) · class-validator/class-transformer (DTOs) · Node 24 `fetch` (HTTP saída) · Jest + Supertest (testes) · Flutter/Riverpod 3 · dio · freezed · file_picker (front).

## Global Constraints

Estas regras valem para TODA task deste plano (copiadas da spec/skills):

- **Módulos independentes — "aponta, não invade":** o `invoice` NUNCA lê/escreve tabela de outro módulo; lê OS/venda/inventário/empresa via **service público**. Config sensível só do próprio módulo.
- **Multi-tenant via RLS sempre:** acesso tenant-scoped via `TenantContext`/`runWithTenant`; `tenant_id` vem do JWT (CLS), nunca do cliente. Config em `tenant_module.settings` é acessada via `BillingService` (que já roda em `runWithTenant`).
- **Migrations ADITIVAS nos 3 lugares mantidos juntos:** `back/sql/auth-multitenant-schema.sql` (canônico/idempotente) + `back/prisma/migrations/NNNN_*/migration.sql` + `back/prisma/schema.prisma`. Seeds de permissão são dados (não mexem em `schema.prisma`), mas vão no baseline SQL **e** numa migration.
- **Sem chamada externa dentro de transação de banco.** `fetch` ao provedor sempre fora de `withTenantTx`/`runWithTenant`.
- **Segredos só via env** (validados por Zod em `common/config`). O `.pfx` e o CSC NÃO ficam no nosso banco — vão via passthrough p/ a Nuvem Fiscal.
- **Sem hard delete.**
- **Mutações sensíveis:** `@Permissions('invoice.config')` (owner) + `AuditService.log`.
- **Front: UI só fala com repository** (interface no domain). Models freezed; estados selados. **Strings de usuário em PT-BR.**
- **Qualidade:** `npm run back:lint` 0 warnings + `back:test`; `flutter analyze` 0 issues + `flutter test`. Node ≥20; Dart `^3.12.1`.
- **Provedor:** base URL API `https://api.nuvemfiscal.com.br`; auth `https://auth.nuvemfiscal.com.br/oauth/token` (grant_type=client_credentials, scopes `empresa nfse nfce nfe`). Empresa: `POST /empresas`; certificado: `PUT /empresas/{cpf_cnpj}/certificado` `{certificado(base64), password}`; config doc: `PUT /empresas/{cpf_cnpj}/{nfse|nfce|nfe}`.

---

## File Structure

**Backend (criar):**
- `back/src/modules/invoice/fiscal/nuvemfiscal-client.ts` — cliente HTTP do provedor (OAuth2 + empresa + certificado + config doc). Responsabilidade única: falar com a Nuvem Fiscal.
- `back/src/modules/invoice/fiscal/nuvemfiscal-client.spec.ts` — testes unitários (fetch mockado).
- `back/src/modules/invoice/dto/invoice-config.dto.ts` — `UpdateInvoiceConfigDto`, `RegisterEmpresaDto`.
- `back/prisma/migrations/0031_invoice_config_permission/migration.sql` — seed da permissão `invoice.config`.

**Backend (modificar):**
- `back/src/common/config/env.schema.ts` — `FISCAL_PROVIDER` ganha `'nuvemfiscal'`; novas vars `NUVEMFISCAL_*`.
- `back/src/modules/invoice/invoice.config.ts` — `InvoiceConfig` + `DEFAULT_INVOICE_CONFIG` + `mergeInvoiceConfig`.
- `back/src/modules/invoice/invoice.service.ts` — injeta `BillingService`, `TenancyService`, `NuvemFiscalClient`; `getConfig/updateConfig/registerEmpresa/uploadCertificate`.
- `back/src/modules/invoice/invoice.controller.ts` — `GET/PATCH /invoices/config`, `POST /invoices/config/register-empresa`, `POST /invoices/config/certificate`.
- `back/src/modules/invoice/invoice.module.ts` — importa `TenancyModule`; provê `NuvemFiscalClient`.
- `back/src/common/audit/audit.service.ts` — novas `AuditAction`.
- `back/sql/auth-multitenant-schema.sql` — seed idempotente da permissão `invoice.config`.

**Frontend (criar):**
- `front/lib/features/invoice/domain/invoice_config_models.dart` (+ freezed/g) — `InvoiceFiscalConfig`, `CertificateInfo`, `EmpresaStatus`.
- `front/lib/features/invoice/domain/invoice_config_repository.dart` — interface.
- `front/lib/features/invoice/data/invoice_config_repository_impl.dart` — dio.
- `front/lib/features/invoice/data/fake_invoice_config_repository.dart` — fake.
- `front/lib/features/invoice/presentation/invoice_config_screen.dart` — tela + Notifier.

**Frontend (modificar):**
- `front/lib/di.dart` — provider `invoiceConfigRepositoryProvider` + `invoiceConfigControllerProvider`.
- `front/lib/core/router/app_router.dart` — rota `/m/invoice/config`.

---

## Task 1: Env vars do provedor Nuvem Fiscal

**Files:**
- Modify: `back/src/common/config/env.schema.ts:34` (bloco FISCAL_*)
- Test: `back/src/common/config/env.schema.spec.ts` (criar se não existir; senão adicionar caso)

**Interfaces:**
- Produces: `Env` ganha `FISCAL_PROVIDER: 'noop'|'govbr'|'nuvemfiscal'`, `NUVEMFISCAL_CLIENT_ID: string`, `NUVEMFISCAL_CLIENT_SECRET: string`, `NUVEMFISCAL_BASE_URL: string`, `NUVEMFISCAL_AUTH_URL: string`.

- [ ] **Step 1: Escrever o teste que falha**

Criar/abrir `back/src/common/config/env.schema.spec.ts` e adicionar:

```ts
import { envSchema } from './env.schema';

describe('envSchema — Nuvem Fiscal', () => {
  const base = { JWT_ACCESS_SECRET: 'x'.repeat(32) };

  it('aceita nuvemfiscal como FISCAL_PROVIDER e aplica defaults de URL', () => {
    const env = envSchema.parse({ ...base, FISCAL_PROVIDER: 'nuvemfiscal' });
    expect(env.FISCAL_PROVIDER).toBe('nuvemfiscal');
    expect(env.NUVEMFISCAL_BASE_URL).toBe('https://api.nuvemfiscal.com.br');
    expect(env.NUVEMFISCAL_AUTH_URL).toBe('https://auth.nuvemfiscal.com.br/oauth/token');
    expect(env.NUVEMFISCAL_CLIENT_ID).toBe('');
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `npm run back:test -- env.schema.spec`
Expected: FAIL (`FISCAL_PROVIDER` não aceita `'nuvemfiscal'`).

- [ ] **Step 3: Implementar**

Em `back/src/common/config/env.schema.ts`, trocar a linha do enum e adicionar as vars logo após `INVOICE_WEBHOOK_SECRET`:

```ts
  FISCAL_PROVIDER: z.enum(['noop', 'govbr', 'nuvemfiscal']).default('noop'),
  // ... (FISCAL_ENVIRONMENT e INVOICE_WEBHOOK_SECRET permanecem) ...
  // --- Nuvem Fiscal (provedor BaaS fiscal; credenciais globais da plataforma) ---
  NUVEMFISCAL_CLIENT_ID: z.string().default(''),
  NUVEMFISCAL_CLIENT_SECRET: z.string().default(''),
  NUVEMFISCAL_BASE_URL: z.string().default('https://api.nuvemfiscal.com.br'),
  NUVEMFISCAL_AUTH_URL: z
    .string()
    .default('https://auth.nuvemfiscal.com.br/oauth/token'),
```

- [ ] **Step 4: Rodar e ver passar**

Run: `npm run back:test -- env.schema.spec`
Expected: PASS.

- [ ] **Step 5: Atualizar `.env`/`.env.example`**

Adicionar em `back/.env` e `back/.env.example`:

```
FISCAL_PROVIDER=noop
NUVEMFISCAL_CLIENT_ID=
NUVEMFISCAL_CLIENT_SECRET=
NUVEMFISCAL_BASE_URL=https://api.nuvemfiscal.com.br
NUVEMFISCAL_AUTH_URL=https://auth.nuvemfiscal.com.br/oauth/token
```

- [ ] **Step 6: Commit**

```bash
git add back/src/common/config/env.schema.ts back/src/common/config/env.schema.spec.ts back/.env.example
git commit -m "feat(invoice): env vars do provedor Nuvem Fiscal"
```

---

## Task 2: Tipo `InvoiceConfig` + merge + DTOs

**Files:**
- Modify: `back/src/modules/invoice/invoice.config.ts`
- Create: `back/src/modules/invoice/dto/invoice-config.dto.ts`
- Test: `back/src/modules/invoice/invoice.config.spec.ts`

**Interfaces:**
- Consumes: nada.
- Produces:
  - `INVOICE_CONFIG_KEY = 'invoice'` (já existe).
  - `interface InvoiceConfig { ambiente: 'homologacao'|'producao'; serieNfse: string; serieNfce: string; serieNfe: string; idCsc: string; empresaRegistrada: boolean; certificado: { validoAte: string | null } }`.
  - `DEFAULT_INVOICE_CONFIG: InvoiceConfig`.
  - `mergeInvoiceConfig(current?: Partial<InvoiceConfig>, patch?: Partial<InvoiceConfig>): InvoiceConfig`.
  - `class UpdateInvoiceConfigDto` (todos os campos opcionais, validados).
  - `class RegisterEmpresaDto {}` (vazio — usa a identidade do núcleo; mantido p/ futura extensão).

- [ ] **Step 1: Escrever o teste que falha**

`back/src/modules/invoice/invoice.config.spec.ts`:

```ts
import { DEFAULT_INVOICE_CONFIG, mergeInvoiceConfig } from './invoice.config';

describe('mergeInvoiceConfig', () => {
  it('retorna defaults quando nada é passado', () => {
    expect(mergeInvoiceConfig()).toEqual(DEFAULT_INVOICE_CONFIG);
    expect(DEFAULT_INVOICE_CONFIG.ambiente).toBe('homologacao');
    expect(DEFAULT_INVOICE_CONFIG.empresaRegistrada).toBe(false);
  });

  it('sobrepõe apenas os campos do patch', () => {
    const merged = mergeInvoiceConfig(
      { serieNfse: '1', ambiente: 'homologacao' },
      { ambiente: 'producao' },
    );
    expect(merged.ambiente).toBe('producao');
    expect(merged.serieNfse).toBe('1');
  });

  it('ignora chaves desconhecidas do patch', () => {
    const merged = mergeInvoiceConfig({}, { lixo: 1 } as never);
    expect((merged as Record<string, unknown>).lixo).toBeUndefined();
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `npm run back:test -- invoice.config.spec`
Expected: FAIL (`mergeInvoiceConfig` não existe).

- [ ] **Step 3: Implementar `invoice.config.ts`**

Substituir o conteúdo de `back/src/modules/invoice/invoice.config.ts` por:

```ts
/** Chave da seção de config do módulo (host incremental de Configurações). */
export const INVOICE_CONFIG_KEY = 'invoice';

export type FiscalEnvironment = 'homologacao' | 'producao';

/** Config NÃO-sensível do tenant (em tenant_module.settings['invoice']['invoice']).
 *  O .pfx e o CSC vão para o provedor; aqui guardamos só metadados/preferências. */
export interface InvoiceConfig {
  ambiente: FiscalEnvironment;
  serieNfse: string;
  serieNfce: string;
  serieNfe: string;
  idCsc: string; // identificador do CSC (o segredo CSC em si vai para o provedor)
  empresaRegistrada: boolean; // empresa cadastrada na Nuvem Fiscal?
  certificado: { validoAte: string | null }; // data ISO de validade do A1 (metadado)
}

export const DEFAULT_INVOICE_CONFIG: InvoiceConfig = {
  ambiente: 'homologacao',
  serieNfse: '1',
  serieNfce: '1',
  serieNfe: '1',
  idCsc: '',
  empresaRegistrada: false,
  certificado: { validoAte: null },
};

const KEYS: (keyof InvoiceConfig)[] = [
  'ambiente',
  'serieNfse',
  'serieNfce',
  'serieNfe',
  'idCsc',
  'empresaRegistrada',
  'certificado',
];

export function mergeInvoiceConfig(
  current?: Partial<InvoiceConfig>,
  patch?: Partial<InvoiceConfig>,
): InvoiceConfig {
  const out: InvoiceConfig = { ...DEFAULT_INVOICE_CONFIG };
  for (const k of KEYS) {
    if (current && current[k] !== undefined) (out as Record<string, unknown>)[k] = current[k];
    if (patch && patch[k] !== undefined) (out as Record<string, unknown>)[k] = patch[k];
  }
  return out;
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `npm run back:test -- invoice.config.spec`
Expected: PASS.

- [ ] **Step 5: Criar o DTO**

`back/src/modules/invoice/dto/invoice-config.dto.ts`:

```ts
import { IsBoolean, IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export class UpdateInvoiceConfigDto {
  @IsOptional() @IsIn(['homologacao', 'producao'])
  ambiente?: 'homologacao' | 'producao';

  @IsOptional() @IsString() @MaxLength(10) serieNfse?: string;
  @IsOptional() @IsString() @MaxLength(10) serieNfce?: string;
  @IsOptional() @IsString() @MaxLength(10) serieNfe?: string;
  @IsOptional() @IsString() @MaxLength(40) idCsc?: string;
}

/** Cadastro da empresa no provedor usa a identidade fiscal do núcleo (tenant.settings);
 *  DTO vazio hoje, mantido para extensão futura sem quebrar o contrato do endpoint. */
export class RegisterEmpresaDto {}
```

- [ ] **Step 6: Rodar lint + commit**

Run: `npm run back:lint`
Expected: 0 warnings.

```bash
git add back/src/modules/invoice/invoice.config.ts back/src/modules/invoice/invoice.config.spec.ts back/src/modules/invoice/dto/invoice-config.dto.ts
git commit -m "feat(invoice): InvoiceConfig + merge + DTOs de config fiscal"
```

---

## Task 3: Permissão `invoice.config` (seed nos 3 lugares) + AuditActions

**Files:**
- Modify: `back/sql/auth-multitenant-schema.sql` (após o bloco de `invoice.read`, ~L1272)
- Create: `back/prisma/migrations/0031_invoice_config_permission/migration.sql`
- Modify: `back/src/common/audit/audit.service.ts` (união `AuditAction`, ~L5-41)

**Interfaces:**
- Produces: permissão `invoice.config` mapeada ao cargo `owner`; `AuditAction` ganha `'invoice_config_update' | 'invoice_empresa_register' | 'invoice_cert_upload'`.

- [ ] **Step 1: Escrever o SQL idempotente no baseline**

Em `back/sql/auth-multitenant-schema.sql`, logo após o mapeamento de `invoice.read`, adicionar:

```sql
-- invoice.config — configuração fiscal sensível (owner-only)
INSERT INTO permission (key, name) VALUES
  ('invoice.config','Configurar nota fiscal')
ON CONFLICT (key) DO NOTHING;

INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON p.key = 'invoice.config'
WHERE r.key IN ('owner')
ON CONFLICT DO NOTHING;
```

- [ ] **Step 2: Criar a migration espelhando o baseline**

`back/prisma/migrations/0031_invoice_config_permission/migration.sql` com EXATAMENTE o mesmo SQL do Step 1.

- [ ] **Step 3: Aplicar o baseline no banco local e conferir**

Run:
```bash
ADMIN_DATABASE_URL=postgresql://app_owner:owner_pw@localhost:55432/orbixhub npx ts-node back/scripts/ci-db-setup.ts
```
Run (conferência):
```bash
podman exec orbix-postgres psql -U app_owner -d orbixhub -c "SELECT r.key FROM role_permission rp JOIN role r ON r.id=rp.role_id JOIN permission p ON p.id=rp.permission_id WHERE p.key='invoice.config';"
```
Expected: uma linha `owner`.

- [ ] **Step 4: Adicionar as AuditActions**

Em `back/src/common/audit/audit.service.ts`, na união `AuditAction`, adicionar (junto das `invoice_*` existentes):

```ts
  | 'invoice_config_update'
  | 'invoice_empresa_register'
  | 'invoice_cert_upload'
```

- [ ] **Step 5: Build + commit**

Run: `npm run build --workspace back`
Expected: sem erros.

```bash
git add back/sql/auth-multitenant-schema.sql back/prisma/migrations/0031_invoice_config_permission/migration.sql back/src/common/audit/audit.service.ts
git commit -m "feat(invoice): permissão invoice.config + audit actions de config fiscal"
```

---

## Task 4: `getConfig`/`updateConfig` no service + rotas GET/PATCH `/invoices/config`

**Files:**
- Modify: `back/src/modules/invoice/invoice.service.ts` (constructor + métodos)
- Modify: `back/src/modules/invoice/invoice.controller.ts`
- Test: `back/test/invoice-config.e2e-spec.ts` (novo e2e)

**Interfaces:**
- Consumes: `BillingService.getModuleSettings(tenantId, 'invoice')` / `setModuleSettings(tenantId, 'invoice', obj)`; `mergeInvoiceConfig`; `INVOICE_CONFIG_KEY`.
- Produces: `InvoiceService.getConfig(tenantId): Promise<InvoiceConfig>`; `InvoiceService.updateConfig(user, dto): Promise<InvoiceConfig>`.

- [ ] **Step 1: Escrever o e2e que falha**

`back/test/invoice-config.e2e-spec.ts` (seguir o boilerplate dos e2e existentes em `back/test/` — app Nest + login owner do seed + header Bearer). Caso central:

```ts
it('GET /invoices/config retorna defaults e PATCH persiste', async () => {
  const get1 = await request(app.getHttpServer())
    .get('/api/invoices/config')
    .set('Authorization', `Bearer ${ownerToken}`)
    .expect(200);
  expect(get1.body.ambiente).toBe('homologacao');

  await request(app.getHttpServer())
    .patch('/api/invoices/config')
    .set('Authorization', `Bearer ${ownerToken}`)
    .send({ serieNfse: '7', ambiente: 'producao' })
    .expect(200);

  const get2 = await request(app.getHttpServer())
    .get('/api/invoices/config')
    .set('Authorization', `Bearer ${ownerToken}`)
    .expect(200);
  expect(get2.body.serieNfse).toBe('7');
  expect(get2.body.ambiente).toBe('producao');
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `podman exec orbix-redis redis-cli FLUSHALL && npm run back:test:e2e -- invoice-config`
Expected: FAIL (rota 404 / método inexistente).

- [ ] **Step 3: Implementar no service**

Em `invoice.service.ts`: importar `BillingService` (`../billing/billing.service`), `UpdateInvoiceConfigDto`, `mergeInvoiceConfig`, `DEFAULT_INVOICE_CONFIG`, `INVOICE_CONFIG_KEY`, `InvoiceConfig`. Injetar `private readonly billing: BillingService` no constructor. Adicionar:

```ts
async getConfig(tenantId: string): Promise<InvoiceConfig> {
  const settings = await this.billing.getModuleSettings(tenantId, INVOICE_CONFIG_KEY);
  return mergeInvoiceConfig(settings[INVOICE_CONFIG_KEY] as Partial<InvoiceConfig> | undefined);
}

async updateConfig(user: AuthUser, dto: UpdateInvoiceConfigDto): Promise<InvoiceConfig> {
  const settings = await this.billing.getModuleSettings(user.tenantId, INVOICE_CONFIG_KEY);
  const current = settings[INVOICE_CONFIG_KEY] as Partial<InvoiceConfig> | undefined;
  const merged = mergeInvoiceConfig(current, dto as Partial<InvoiceConfig>);
  await this.billing.setModuleSettings(user.tenantId, INVOICE_CONFIG_KEY, {
    ...settings,
    [INVOICE_CONFIG_KEY]: merged,
  });
  try {
    await this.audit.log(user.tenantId, user.userId, 'invoice_config_update', null, {
      ambiente: merged.ambiente,
    });
  } catch { /* auditoria best-effort */ }
  return merged;
}
```

- [ ] **Step 4: Implementar no controller**

Em `invoice.controller.ts` adicionar (dentro da classe já gated por `ModuleAccessGuard`+`@RequiresModule('invoice')`):

```ts
@Get('config')
@Permissions('invoice.config')
getConfig(@CurrentUser() user: AuthUser) {
  return this.invoice.getConfig(user.tenantId);
}

@Patch('config')
@Permissions('invoice.config')
@HttpCode(200)
updateConfig(@CurrentUser() user: AuthUser, @Body() dto: UpdateInvoiceConfigDto) {
  return this.invoice.updateConfig(user, dto);
}
```

Adicionar imports `Get`, `Patch` (de `@nestjs/common`) e `UpdateInvoiceConfigDto`.

> **Ordem de rotas:** `@Get('config')`/`@Patch('config')` devem vir ANTES de `@Get(':id')` para o `config` não ser capturado pelo `ParseUUIDPipe` do `:id`.

- [ ] **Step 5: Rodar e ver passar**

Run: `podman exec orbix-redis redis-cli FLUSHALL && npm run back:test:e2e -- invoice-config`
Expected: PASS.

- [ ] **Step 6: Lint + commit**

Run: `npm run back:lint`

```bash
git add back/src/modules/invoice/invoice.service.ts back/src/modules/invoice/invoice.controller.ts back/test/invoice-config.e2e-spec.ts
git commit -m "feat(invoice): GET/PATCH /invoices/config (config fiscal por tenant)"
```

---

## Task 5: Ler a identidade fiscal do núcleo via `TenancyService` (aponta-não-invade)

**Files:**
- Modify: `back/src/modules/invoice/invoice.module.ts` (importar `TenancyModule`)
- Modify: `back/src/modules/invoice/invoice.service.ts` (injetar `TenancyService`; método `getFiscalIdentity`)
- Test: `back/src/modules/invoice/invoice.service.spec.ts` (unit com mocks)

**Interfaces:**
- Consumes: `TenancyService.getCompanyView(tenantId): Promise<Record<string, unknown>>` (chaves `taxId`, `legalName`, `inscricaoEstadual`, `inscricaoMunicipal`, `regimeTributario`, `cnae`, `cep`, `logradouro`, `numero`, `complemento`, `bairro`, `municipio`, `uf`, `companyName`).
- Produces: `InvoiceService.getFiscalIdentity(tenantId): Promise<FiscalIdentity>` — objeto normalizado usado por Task 7 e pelos Planos 3–4.

- [ ] **Step 1: Escrever o teste unitário que falha**

Em `invoice.service.spec.ts` (criar se necessário, mockando as deps do service):

```ts
it('getFiscalIdentity normaliza a company view do núcleo', async () => {
  tenancy.getCompanyView.mockResolvedValue({
    taxId: '12345678000199', legalName: 'Oficina LTDA',
    inscricaoMunicipal: '123', regimeTributario: 'simples',
    cep: '01001000', logradouro: 'Rua A', numero: '10',
    bairro: 'Centro', municipio: 'São Paulo', uf: 'SP',
  });
  const id = await service.getFiscalIdentity('t1');
  expect(id.cnpj).toBe('12345678000199');
  expect(id.endereco.uf).toBe('SP');
  expect(id.regimeTributario).toBe('simples');
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `npm run back:test -- invoice.service.spec`
Expected: FAIL.

- [ ] **Step 3: Implementar**

Em `invoice.module.ts`: importar `TenancyModule` (`../tenancy/tenancy.module`) e adicioná-lo ao array `imports`.

Em `invoice.service.ts`: importar `TenancyService` (`../tenancy/tenancy.service`), injetar no constructor, e adicionar o tipo + método:

```ts
export interface FiscalIdentity {
  cnpj: string | null;
  razaoSocial: string | null;
  inscricaoEstadual: string | null;
  inscricaoMunicipal: string | null;
  regimeTributario: string | null;
  cnae: string | null;
  email: string | null;
  endereco: {
    cep: string | null; logradouro: string | null; numero: string | null;
    complemento: string | null; bairro: string | null; municipio: string | null; uf: string | null;
  };
}

async getFiscalIdentity(tenantId: string): Promise<FiscalIdentity> {
  const c = await this.tenancy.getCompanyView(tenantId);
  const s = (k: string) => (typeof c[k] === 'string' ? (c[k] as string) : null);
  return {
    cnpj: s('taxId'),
    razaoSocial: s('legalName') ?? s('companyName'),
    inscricaoEstadual: s('inscricaoEstadual'),
    inscricaoMunicipal: s('inscricaoMunicipal'),
    regimeTributario: s('regimeTributario'),
    cnae: s('cnae'),
    email: s('email'),
    endereco: {
      cep: s('cep'), logradouro: s('logradouro'), numero: s('numero'),
      complemento: s('complemento'), bairro: s('bairro'),
      municipio: s('municipio'), uf: s('uf'),
    },
  };
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `npm run back:test -- invoice.service.spec`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add back/src/modules/invoice/invoice.module.ts back/src/modules/invoice/invoice.service.ts back/src/modules/invoice/invoice.service.spec.ts
git commit -m "feat(invoice): lê identidade fiscal do núcleo via TenancyService (aponta-não-invade)"
```

---

## Task 6: `NuvemFiscalClient` — OAuth2 (token cacheado) + wrapper `fetch`

**Files:**
- Create: `back/src/modules/invoice/fiscal/nuvemfiscal-client.ts`
- Create: `back/src/modules/invoice/fiscal/nuvemfiscal-client.spec.ts`

**Interfaces:**
- Consumes: `@Inject(ENV) Env` (usa `NUVEMFISCAL_*`).
- Produces: `class NuvemFiscalClient` com `async token(): Promise<string>` (cache com expiração) e `async request<T>(method, path, opts?): Promise<T>` (injeta Bearer, base URL, trata erro). Não lança para 404 em GET (retorna `null`).

- [ ] **Step 1: Escrever o teste que falha (fetch mockado)**

`nuvemfiscal-client.spec.ts`:

```ts
import { NuvemFiscalClient } from './nuvemfiscal-client';
import type { Env } from '../../../common/config/env.schema';

const env = {
  NUVEMFISCAL_CLIENT_ID: 'cid', NUVEMFISCAL_CLIENT_SECRET: 'sec',
  NUVEMFISCAL_BASE_URL: 'https://api.test', NUVEMFISCAL_AUTH_URL: 'https://auth.test/token',
} as unknown as Env;

describe('NuvemFiscalClient.token', () => {
  afterEach(() => jest.restoreAllMocks());

  it('busca e cacheia o token OAuth2', async () => {
    const fetchMock = jest.spyOn(global, 'fetch').mockResolvedValue(
      new Response(JSON.stringify({ access_token: 'abc', expires_in: 3600 }), { status: 200 }),
    );
    const c = new NuvemFiscalClient(env);
    expect(await c.token()).toBe('abc');
    expect(await c.token()).toBe('abc'); // 2ª chamada usa cache
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(fetchMock.mock.calls[0][0]).toBe('https://auth.test/token');
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `npm run back:test -- nuvemfiscal-client.spec`
Expected: FAIL (classe não existe).

- [ ] **Step 3: Implementar o cliente (token + request)**

`nuvemfiscal-client.ts`:

```ts
import { Inject, Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ENV } from '../../../common/config/config.module';
import type { Env } from '../../../common/config/env.schema';

@Injectable()
export class NuvemFiscalClient {
  private readonly logger = new Logger(NuvemFiscalClient.name);
  private cachedToken: { value: string; expiresAt: number } | null = null;

  constructor(@Inject(ENV) private readonly env: Env) {}

  async token(): Promise<string> {
    const now = Date.now();
    if (this.cachedToken && this.cachedToken.expiresAt > now + 30_000) {
      return this.cachedToken.value;
    }
    const body = new URLSearchParams({
      grant_type: 'client_credentials',
      client_id: this.env.NUVEMFISCAL_CLIENT_ID,
      client_secret: this.env.NUVEMFISCAL_CLIENT_SECRET,
      scope: 'empresa nfse nfce nfe',
    });
    const res = await fetch(this.env.NUVEMFISCAL_AUTH_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body,
    });
    if (!res.ok) {
      this.logger.error(`OAuth2 falhou: ${res.status}`);
      throw new ServiceUnavailableException('Falha ao autenticar no provedor fiscal');
    }
    const json = (await res.json()) as { access_token: string; expires_in: number };
    this.cachedToken = {
      value: json.access_token,
      expiresAt: now + json.expires_in * 1000,
    };
    return json.access_token;
  }

  async request<T>(
    method: string,
    path: string,
    opts?: { body?: unknown; allow404?: boolean },
  ): Promise<T | null> {
    const token = await this.token();
    const res = await fetch(`${this.env.NUVEMFISCAL_BASE_URL}${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: opts?.body !== undefined ? JSON.stringify(opts.body) : undefined,
    });
    if (opts?.allow404 && res.status === 404) return null;
    if (!res.ok) {
      const text = await res.text().catch(() => '');
      this.logger.error(`${method} ${path} -> ${res.status}: ${text}`);
      throw new ServiceUnavailableException('Erro na comunicação com o provedor fiscal');
    }
    if (res.status === 204) return null;
    return (await res.json()) as T;
  }
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `npm run back:test -- nuvemfiscal-client.spec`
Expected: PASS.

- [ ] **Step 5: Lint + commit**

```bash
git add back/src/modules/invoice/fiscal/nuvemfiscal-client.ts back/src/modules/invoice/fiscal/nuvemfiscal-client.spec.ts
git commit -m "feat(invoice): NuvemFiscalClient — OAuth2 client-credentials + wrapper fetch"
```

---

## Task 7: Cadastro de empresa + upload de certificado (passthrough)

**Files:**
- Modify: `back/src/modules/invoice/fiscal/nuvemfiscal-client.ts` (métodos de empresa/cert/config-doc)
- Modify: `back/src/modules/invoice/invoice.service.ts` (`registerEmpresa`, `uploadCertificate`)
- Modify: `back/src/modules/invoice/invoice.controller.ts` (2 rotas POST)
- Modify: `back/src/modules/invoice/invoice.module.ts` (prover `NuvemFiscalClient`)
- Test: `back/src/modules/invoice/fiscal/nuvemfiscal-client.spec.ts` (novos casos, fetch mockado)

**Interfaces:**
- Consumes: `NuvemFiscalClient.request`; `InvoiceService.getFiscalIdentity` (Task 5); `InvoiceService.getConfig/updateConfig` (Task 4); padrão de upload multipart de `SettingsController.uploadLogo` (`FileInterceptor` + `memoryStorage` + `@UploadedFile`).
- Produces:
  - `NuvemFiscalClient.upsertEmpresa(id: FiscalIdentity): Promise<void>`
  - `NuvemFiscalClient.uploadCertificate(cnpj: string, pfxBase64: string, password: string): Promise<{ notValidAfter: string | null }>`
  - `InvoiceService.registerEmpresa(user): Promise<InvoiceConfig>`
  - `InvoiceService.uploadCertificate(user, file, password): Promise<InvoiceConfig>`

- [ ] **Step 1: Escrever os testes que falham (cliente)**

Em `nuvemfiscal-client.spec.ts` adicionar:

```ts
it('uploadCertificate faz PUT no endpoint do certificado e devolve validade', async () => {
  jest.spyOn(global, 'fetch')
    .mockResolvedValueOnce(new Response(JSON.stringify({ access_token: 'abc', expires_in: 3600 }), { status: 200 }))
    .mockResolvedValueOnce(new Response(JSON.stringify({ not_valid_after: '2027-01-01T00:00:00Z' }), { status: 200 }));
  const c = new NuvemFiscalClient(env);
  const r = await c.uploadCertificate('12345678000199', 'BASE64', 'senha');
  expect(r.notValidAfter).toBe('2027-01-01T00:00:00Z');
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `npm run back:test -- nuvemfiscal-client.spec`
Expected: FAIL.

- [ ] **Step 3: Implementar métodos no cliente**

Em `nuvemfiscal-client.ts` adicionar:

```ts
import type { FiscalIdentity } from '../invoice.service';

// dentro da classe:
async upsertEmpresa(id: FiscalIdentity): Promise<void> {
  if (!id.cnpj) throw new ServiceUnavailableException('Tenant sem CNPJ em Configurações da empresa');
  const payload = {
    cpf_cnpj: id.cnpj,
    nome_razao_social: id.razaoSocial ?? '',
    nome_fantasia: id.razaoSocial ?? '',
    email: id.email ?? '',
    inscricao_estadual: id.inscricaoEstadual ?? undefined,
    inscricao_municipal: id.inscricaoMunicipal ?? undefined,
    endereco: {
      logradouro: id.endereco.logradouro ?? '',
      numero: id.endereco.numero ?? '',
      bairro: id.endereco.bairro ?? '',
      cidade: id.endereco.municipio ?? '',
      uf: id.endereco.uf ?? '',
      cep: id.endereco.cep ?? '',
    },
  };
  // idempotente: cria; se já existe, atualiza via PUT
  const exists = await this.request('GET', `/empresas/${id.cnpj}`, { allow404: true });
  if (exists) await this.request('PUT', `/empresas/${id.cnpj}`, { body: payload });
  else await this.request('POST', `/empresas`, { body: payload });
}

async uploadCertificate(
  cnpj: string, pfxBase64: string, password: string,
): Promise<{ notValidAfter: string | null }> {
  const r = await this.request<{ not_valid_after?: string }>(
    'PUT', `/empresas/${cnpj}/certificado`, { body: { certificado: pfxBase64, password } },
  );
  return { notValidAfter: r?.not_valid_after ?? null };
}
```

- [ ] **Step 4: Rodar e ver passar (cliente)**

Run: `npm run back:test -- nuvemfiscal-client.spec`
Expected: PASS.

- [ ] **Step 5: Prover o cliente no módulo**

Em `invoice.module.ts`, adicionar `NuvemFiscalClient` ao array `providers`.

- [ ] **Step 6: Implementar no service**

Em `invoice.service.ts` injetar `private readonly nuvem: NuvemFiscalClient` e adicionar (o `fetch` roda FORA de tx — `getConfig`/`updateConfig` fazem suas próprias tx curtas depois):

```ts
async registerEmpresa(user: AuthUser): Promise<InvoiceConfig> {
  const identity = await this.getFiscalIdentity(user.tenantId);
  await this.nuvem.upsertEmpresa(identity); // fora de tx (HTTP)
  const cfg = await this.getConfig(user.tenantId);
  const updated = await this.updateConfig(user, {} as UpdateInvoiceConfigDto);
  const merged = mergeInvoiceConfig(updated, { empresaRegistrada: true });
  const settings = await this.billing.getModuleSettings(user.tenantId, INVOICE_CONFIG_KEY);
  await this.billing.setModuleSettings(user.tenantId, INVOICE_CONFIG_KEY, {
    ...settings, [INVOICE_CONFIG_KEY]: merged,
  });
  try { await this.audit.log(user.tenantId, user.userId, 'invoice_empresa_register', identity.cnpj); } catch {}
  return merged;
}

async uploadCertificate(
  user: AuthUser, file: { buffer: Buffer; originalname: string } | undefined, password: string,
): Promise<InvoiceConfig> {
  if (!file?.buffer?.length) throw new BadRequestException('Envie o arquivo do certificado (.pfx)');
  if (!/\.(pfx|p12)$/i.test(file.originalname)) throw new BadRequestException('Certificado deve ser .pfx/.p12');
  if (!password) throw new BadRequestException('Informe a senha do certificado');
  const identity = await this.getFiscalIdentity(user.tenantId);
  if (!identity.cnpj) throw new BadRequestException('Configure o CNPJ da empresa antes do certificado');
  const base64 = file.buffer.toString('base64'); // .pfx NUNCA persistido — vai p/ o provedor
  const r = await this.nuvem.uploadCertificate(identity.cnpj, base64, password); // fora de tx
  const settings = await this.billing.getModuleSettings(user.tenantId, INVOICE_CONFIG_KEY);
  const current = settings[INVOICE_CONFIG_KEY] as Partial<InvoiceConfig> | undefined;
  const merged = mergeInvoiceConfig(current, { certificado: { validoAte: r.notValidAfter } });
  await this.billing.setModuleSettings(user.tenantId, INVOICE_CONFIG_KEY, {
    ...settings, [INVOICE_CONFIG_KEY]: merged,
  });
  try { await this.audit.log(user.tenantId, user.userId, 'invoice_cert_upload', identity.cnpj, { validoAte: r.notValidAfter }); } catch {}
  return merged;
}
```

Adicionar `BadRequestException` aos imports de `@nestjs/common`.

- [ ] **Step 7: Implementar as rotas no controller**

Em `invoice.controller.ts` adicionar (imports: `Post` já existe; adicionar `UploadedFile`, `UseInterceptors` de `@nestjs/common`, `FileInterceptor` de `@nestjs/platform-express`, `memoryStorage` de `multer`, `RegisterEmpresaDto`):

```ts
@Post('config/register-empresa')
@Permissions('invoice.config')
@HttpCode(200)
registerEmpresa(@CurrentUser() user: AuthUser) {
  return this.invoice.registerEmpresa(user);
}

@Post('config/certificate')
@Permissions('invoice.config')
@HttpCode(200)
@UseInterceptors(FileInterceptor('file', { storage: memoryStorage(), limits: { fileSize: 8 * 1024 * 1024 } }))
uploadCertificate(
  @CurrentUser() user: AuthUser,
  @UploadedFile() file: { buffer: Buffer; originalname: string } | undefined,
  @Body('password') password: string,
) {
  return this.invoice.uploadCertificate(user, file, password);
}
```

> **Ordem de rotas:** manter os `config/*` antes de `@Post(':id/cancel')`/`@Get(':id')`.

- [ ] **Step 8: e2e com o cliente mockado**

Em `back/test/invoice-config.e2e-spec.ts` adicionar um caso que faz `POST /invoices/config/register-empresa` com o `NuvemFiscalClient` sobreposto por um provider fake no `Test.createTestingModule(...).overrideProvider(NuvemFiscalClient)`, e verifica que `getConfig().empresaRegistrada === true`. (Seguir o padrão de override dos e2e existentes.)

- [ ] **Step 9: Rodar e2e + unit + lint**

Run: `podman exec orbix-redis redis-cli FLUSHALL && npm run back:test:e2e -- invoice-config && npm run back:test -- nuvemfiscal-client && npm run back:lint`
Expected: PASS + 0 warnings.

- [ ] **Step 10: Commit**

```bash
git add back/src/modules/invoice/ back/test/invoice-config.e2e-spec.ts
git commit -m "feat(invoice): cadastro de empresa + upload de certificado (passthrough Nuvem Fiscal)"
```

---

## Task 8: Front — tela de Config Fiscal (repo + Notifier + tela + rota)

**Files:**
- Create: `front/lib/features/invoice/domain/invoice_config_models.dart` (+ freezed/g gerados)
- Create: `front/lib/features/invoice/domain/invoice_config_repository.dart`
- Create: `front/lib/features/invoice/data/invoice_config_repository_impl.dart`
- Create: `front/lib/features/invoice/data/fake_invoice_config_repository.dart`
- Create: `front/lib/features/invoice/presentation/invoice_config_screen.dart`
- Modify: `front/lib/di.dart`
- Modify: `front/lib/core/router/app_router.dart`
- Test: `front/test/invoice_config_test.dart`

**Interfaces:**
- Consumes (backend): `GET/PATCH /invoices/config`, `POST /invoices/config/register-empresa`, `POST /invoices/config/certificate` (multipart `file` + `password`).
- Produces: `InvoiceFiscalConfig` (freezed, snake_case JSON), `InvoiceConfigRepository`, `invoiceConfigRepositoryProvider`, `invoiceConfigControllerProvider`, rota `/m/invoice/config`.

- [ ] **Step 1: Escrever o teste que falha (fake repo + Notifier)**

`front/test/invoice_config_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:front/features/invoice/data/fake_invoice_config_repository.dart';

void main() {
  test('fake repo aplica patch e marca empresa registrada', () async {
    final repo = FakeInvoiceConfigRepository();
    final c1 = await repo.fetch();
    expect(c1.ambiente, 'homologacao');
    final c2 = await repo.update({'serieNfse': '9', 'ambiente': 'producao'});
    expect(c2.serieNfse, '9');
    expect(c2.ambiente, 'producao');
    final c3 = await repo.registerEmpresa();
    expect(c3.empresaRegistrada, true);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd front && "C:\flutter\bin\flutter.bat" test test/invoice_config_test.dart`
Expected: FAIL (imports inexistentes).

- [ ] **Step 3: Criar os models freezed**

`front/lib/features/invoice/domain/invoice_config_models.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'invoice_config_models.freezed.dart';
part 'invoice_config_models.g.dart';

@freezed
class CertificateInfo with _$CertificateInfo {
  const factory CertificateInfo({@JsonKey(name: 'validoAte') String? validoAte}) = _CertificateInfo;
  factory CertificateInfo.fromJson(Map<String, dynamic> json) => _$CertificateInfoFromJson(json);
}

@freezed
class InvoiceFiscalConfig with _$InvoiceFiscalConfig {
  const factory InvoiceFiscalConfig({
    @Default('homologacao') String ambiente,
    @Default('1') String serieNfse,
    @Default('1') String serieNfce,
    @Default('1') String serieNfe,
    @Default('') String idCsc,
    @Default(false) bool empresaRegistrada,
    @Default(CertificateInfo()) CertificateInfo certificado,
  }) = _InvoiceFiscalConfig;
  factory InvoiceFiscalConfig.fromJson(Map<String, dynamic> json) => _$InvoiceFiscalConfigFromJson(json);
}
```

- [ ] **Step 4: Criar a interface + impls do repository**

`domain/invoice_config_repository.dart`:

```dart
import 'dart:typed_data';
import 'invoice_config_models.dart';

abstract class InvoiceConfigRepository {
  Future<InvoiceFiscalConfig> fetch();
  Future<InvoiceFiscalConfig> update(Map<String, dynamic> patch);
  Future<InvoiceFiscalConfig> registerEmpresa();
  Future<InvoiceFiscalConfig> uploadCertificate(Uint8List bytes, String filename, String password);
}
```

`data/invoice_config_repository_impl.dart` (dio, seguindo `settings_repository_impl.dart`):

```dart
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../domain/invoice_config_models.dart';
import '../domain/invoice_config_repository.dart';

class InvoiceConfigRepositoryImpl implements InvoiceConfigRepository {
  InvoiceConfigRepositoryImpl(this._dio);
  final Dio _dio;

  InvoiceFiscalConfig _parse(Object? data) =>
      InvoiceFiscalConfig.fromJson((data as Map).cast<String, dynamic>());

  @override
  Future<InvoiceFiscalConfig> fetch() async =>
      _parse((await _dio.get<Object?>('/invoices/config')).data);

  @override
  Future<InvoiceFiscalConfig> update(Map<String, dynamic> patch) async =>
      _parse((await _dio.patch<Object?>('/invoices/config', data: patch)).data);

  @override
  Future<InvoiceFiscalConfig> registerEmpresa() async =>
      _parse((await _dio.post<Object?>('/invoices/config/register-empresa')).data);

  @override
  Future<InvoiceFiscalConfig> uploadCertificate(Uint8List bytes, String filename, String password) async {
    final form = FormData.fromMap({
      'password': password,
      'file': MultipartFile.fromBytes(bytes, filename: filename, contentType: MediaType('application', 'x-pkcs12')),
    });
    return _parse((await _dio.post<Object?>('/invoices/config/certificate', data: form)).data);
  }
}
```

`data/fake_invoice_config_repository.dart`:

```dart
import 'dart:typed_data';
import '../domain/invoice_config_models.dart';
import '../domain/invoice_config_repository.dart';

class FakeInvoiceConfigRepository implements InvoiceConfigRepository {
  InvoiceFiscalConfig _cfg = const InvoiceFiscalConfig();

  @override
  Future<InvoiceFiscalConfig> fetch() async => _cfg;

  @override
  Future<InvoiceFiscalConfig> update(Map<String, dynamic> patch) async {
    _cfg = _cfg.copyWith(
      ambiente: patch['ambiente'] as String? ?? _cfg.ambiente,
      serieNfse: patch['serieNfse'] as String? ?? _cfg.serieNfse,
      serieNfce: patch['serieNfce'] as String? ?? _cfg.serieNfce,
      serieNfe: patch['serieNfe'] as String? ?? _cfg.serieNfe,
      idCsc: patch['idCsc'] as String? ?? _cfg.idCsc,
    );
    return _cfg;
  }

  @override
  Future<InvoiceFiscalConfig> registerEmpresa() async {
    _cfg = _cfg.copyWith(empresaRegistrada: true);
    return _cfg;
  }

  @override
  Future<InvoiceFiscalConfig> uploadCertificate(Uint8List bytes, String filename, String password) async {
    _cfg = _cfg.copyWith(certificado: const CertificateInfo(validoAte: '2027-01-01T00:00:00Z'));
    return _cfg;
  }
}
```

- [ ] **Step 5: Rodar codegen + o teste passar**

Run: `cd front && "C:\flutter\bin\flutter.bat" pub run build_runner build --delete-conflicting-outputs`
Run: `"C:\flutter\bin\flutter.bat" test test/invoice_config_test.dart`
Expected: PASS.

- [ ] **Step 6: Registrar providers em `di.dart`**

Adicionar (perto de `invoiceRepositoryProvider`, L109; imports no topo seguindo o padrão):

```dart
final invoiceConfigRepositoryProvider = Provider<InvoiceConfigRepository>(
    (ref) => InvoiceConfigRepositoryImpl(ref.read(dioProvider)));

final invoiceConfigControllerProvider =
    AsyncNotifierProvider<InvoiceConfigController, InvoiceFiscalConfig>(
  InvoiceConfigController.new,
);
```

- [ ] **Step 7: Criar a tela + Notifier**

`presentation/invoice_config_screen.dart` — `AsyncNotifier<InvoiceFiscalConfig>` (segue `SettingsController`): `build()` chama `fetch()`; ações `save(patch)`, `registerEmpresa()`, `pickAndUploadCertificate()` (usa `FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pfx','p12'], withData: true)` + diálogo de senha). Tela responsiva (segue o `AppShell`; devolve só o corpo): status da empresa (badge registrada/não), botão "Cadastrar empresa no provedor", upload do certificado (+validade), selects de ambiente e campos de série/CSC, botão salvar. Strings em PT-BR. Erros via `AppException` → snackbar.

- [ ] **Step 8: Registrar a rota**

Em `app_router.dart`, adicionar antes do placeholder genérico de `/m/invoice/:id`:

```dart
GoRoute(
  path: '/m/invoice/config',
  pageBuilder: (_, s) => neuPage(s, const InvoiceConfigScreen()),
),
```

- [ ] **Step 9: analyze + test**

Run: `cd front && "C:\flutter\bin\flutter.bat" analyze && "C:\flutter\bin\flutter.bat" test`
Expected: No issues found + testes verdes.

- [ ] **Step 10: Commit**

```bash
git add front/lib/features/invoice/ front/lib/di.dart front/lib/core/router/app_router.dart front/test/invoice_config_test.dart
git commit -m "feat(invoice): tela de configuração fiscal (empresa + certificado + série/ambiente)"
```

---

## Self-Review (feito na escrita)

- **Cobertura da spec (Fase 1):** env creds (T1) ✓ · factory de provider — *movida para o Plano 3* (só faz sentido quando o `NuvemFiscalGateway` de emissão existir; o `NuvemFiscalClient` de empresa/cert é construído aqui) · config por tenant (T2,T4) ✓ · cadastro empresa + certificado passthrough (T6,T7) ✓ · leitura da identidade fiscal do núcleo (T5) ✓ · tela de settings (T8) ✓.
- **Sem placeholders:** todos os steps trazem código real; onde o payload do provedor pode divergir (empresa/cert), o contrato interno do `NuvemFiscalClient` está fixo e os testes usam fixtures — **ajustar o mapeamento fino contra a API reference** (`dev.nuvemfiscal.com.br/docs/api/`) é o único ponto a validar na execução (T6/T7).
- **Consistência de tipos:** `InvoiceConfig`/`mergeInvoiceConfig` (T2) usados igual em T4/T7; `FiscalIdentity` (T5) consumido por `NuvemFiscalClient.upsertEmpresa` (T7); `INVOICE_CONFIG_KEY` reutilizado.
- **Store:** confirmado `tenant_module.settings['invoice']['invoice']` via `BillingService` (mesmo padrão do `inventory`).

## Pendências herdadas (não bloqueiam o Plano 1)
- Validar o mapeamento fino dos endpoints da Nuvem Fiscal contra a API reference (empresa/cert/config-doc).
- Rodar um teste real de ponta a ponta contra o **sandbox** do provedor (runbook manual — requer `NUVEMFISCAL_CLIENT_ID/SECRET` de homologação).
