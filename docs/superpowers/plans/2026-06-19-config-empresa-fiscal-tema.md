# Configuração — Empresa, Fiscal & Tema — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dar ao dono (owner/gerente) uma tela de **Configurações** completa: editar identidade da empresa (nome fantasia, razão social, telefone, e-mail, **logo por upload**), preencher os **dados fiscais** que o futuro módulo de Nota Fiscal (NF-e) vai precisar, e **escolher o tema/cor do sistema** entre presets curados (mantendo o tangerina atual), cada um com modo claro e escuro.

**Architecture:** Estende o **host `settings` que já existe** (não é módulo novo). Os campos novos vivem em `tenant.settings` (JSONB) → **sem migration**. Logo reusa o `StorageProvider` (local/MinIO) já existente. Tema reusa o sistema já "seedável" (`AppTheme.light/dark({seed})` + `brandingSeedProvider` lê `company.primaryColor`); presets são apenas cores-semente curadas. Modo claro/escuro continua **por usuário** (`themeControllerProvider`, SharedPreferences); a cor/preset é **por tenant** (em `tenant.settings`). A tela Flutter `features/settings/` é **criada do zero** (hoje só existe o fetch de branding, não a tela).

**Tech Stack:** Back: NestJS, Prisma, class-validator, `StorageProvider`, `SettingsSectionRegistry`. Front: Flutter, Riverpod 3, go_router, dio, freezed, `file_picker` (já no pubspec), `ColorScheme.fromSeed`. Verificação visual: Playwright (`front/tmp-pw/`).

## Global Constraints

- **Arquitetura OrbixHub (skill `orbixhub-arquitetura`) é lei.** "Aponta, não invade": `settings` NUNCA toca tabela de outro módulo — lê company via `TenancyService`, módulos via `BillingService`. Mantido.
- **Sem migration:** todos os campos novos da empresa moram em `tenant.settings` (JSONB schemaless). Nenhuma alteração em `schema.prisma` / `sql` / `prisma/migrations`. (Se algum dia virar coluna tipada, aí sim aditivo nos 3 lugares — **não** neste plano.)
- **Mutações sensíveis:** `@Permissions('settings.manage')` + `AuditService.log(... 'settings_change' ...)`. Leitura (`GET /settings`) é de qualquer membro autenticado.
- **Multi-tenant via RLS sempre**; `tenant_id` do JWT/CLS. `tenant.settings` é tabela global (tenant não-RLS), acessada só via `TenancyService` (já é assim).
- **Nada de I/O externo dentro de transação de banco:** upload (storage.put) acontece FORA do `withTenantTx` (padrão do OS).
- **Strings de usuário em PT-BR.** Front: UI só fala com repository (interface no domain); models freezed; estado selado.
- **Ambiente local desta máquina:** npm (não pnpm); Postgres podman em **55432**; backend em `PORT=4500` rodando `node back/dist/src/main.js` (porta 3000/4400 são "envenenadas" — ver memória [[run-stack-this-machine]]). Flutter SDK fora do PATH: invocar por `C:\Users\KaueSobral\develop\flutter\bin\flutter.bat`. Verificar via **web (Chrome)** + `flutter test`.
- **Comandos de verificação (cite o output real):** `npm run back:lint` (0 warnings) · `npm run back:test` · `npm run back:test:e2e` (FLUSHALL no redis antes) · `flutter analyze` (0 issues) · `flutter test`.
- **Sem hard delete.** Remover logo = limpar `logoUrl` + `storage.remove` (o arquivo), não apagar tenant.

---

## File Structure

**Backend (`back/src`):**
- Modify `modules/settings/settings.section-registry.ts` — estender `SettingsFieldType` (+`email`,`tel`,`select`,`image`), `SettingsFieldSchema` (+`options?`), e `COMPANY_SECTION` (campos fiscais + endereço estruturado + `themePreset`). Reagrupar em subseções via `group`.
- Modify `modules/settings/dto/settings.dto.ts` — novos campos opcionais validados (regime, UF, CEP, themePreset).
- Modify `modules/settings/settings.controller.ts` — `POST /settings/company/logo` (upload) e `DELETE /settings/company/logo`.
- Modify `modules/settings/settings.service.ts` — `uploadLogo`, `removeLogo`, e sincronizar colunas tipadas via tenancy ao salvar identidade.
- Modify `modules/settings/settings.module.ts` — (storage é global; nada a importar além do já existente).
- Modify `modules/tenancy/tenancy.service.ts` (+ `tenancy.repository.ts`) — `syncCompanyIdentity(tenantId, {tradeName, legalName, cnpj})` (dono da tabela `tenant`).
- Create `modules/settings/settings.types.ts` — `UploadedImage` (shape do multipart, local, sem acoplar ao OS).
- Test `test/settings.e2e-spec.ts` — atualizar/estender (company fields, logo, permissão, isolamento).
- Modify `docs/configuracao.md` — tabela da seção Empresa (fiscal+tema) + subseção "Nota Fiscal (módulo `invoice`)".

**Frontend (`front/lib`):**
- Create `core/theme/theme_presets.dart` — `ThemePreset{key,label,seed}` + lista curada (tangerina default + 6).
- Modify `core/theme/branding.dart` — resolver `themePreset`→seed (fallback `primaryColor`→`AppColors.brand`).
- Create `features/settings/domain/settings_models.dart` — freezed: `CompanySettings`, `SettingsSection`, `SettingsField`, `SettingsBundle`.
- Create `features/settings/domain/settings_repository.dart` — interface.
- Create `features/settings/data/settings_repository_impl.dart` — dio.
- Create `features/settings/data/fake_settings_repository.dart` — fake.
- Create `features/settings/presentation/settings_controller.dart` — Notifier (estado selado).
- Create `features/settings/presentation/settings_screen.dart` — host da tela (abas/seções).
- Create `features/settings/presentation/company_form.dart` — form identidade + fiscal + upload logo.
- Create `features/settings/presentation/appearance_section.dart` — presets (swatches) + claro/escuro/sistema + preview.
- Create `features/settings/presentation/dynamic_section.dart` — renderiza seções de módulos (campos por tipo).
- Modify `di.dart` — `settingsRepositoryProvider` + `settingsControllerProvider`.
- Modify `core/router/app_router.dart` — rota `/configuracoes` (guardada por permissão).
- Modify `features/shell/presentation/nav_items.dart` — item "Configurações" (gated por `settings.manage`).
- Modify `features/shell/presentation/sidebar.dart` — exibir `logoUrl` (Image.network) quando houver, senão `BrandMark`.
- Test `front/test/theme_presets_test.dart`, `front/test/settings_controller_test.dart`, `front/test/nav_items_settings_test.dart`, `front/test/appearance_section_test.dart`.

**Verificação visual:**
- Use `front/tmp-pw/` (Playwright) — script novo `tmp-pw/verify-themes.mjs`.

---

## Phase 1 — Backend: campos da empresa (fiscal + tema) + tipos de campo

### Task 1.1: Estender o schema de campos e a COMPANY_SECTION

**Files:**
- Modify: `back/src/modules/settings/settings.section-registry.ts`

**Interfaces:**
- Produces: `SettingsFieldType = 'text'|'email'|'tel'|'url'|'color'|'bool'|'select'|'image'`; `SettingsFieldSchema { key; label; type; options?: {value;label}[]; group?: string }`; `COMPANY_SECTION` com os campos novos.

- [ ] **Step 1: Escrever o teste que falha**

`back/src/modules/settings/settings.section-registry.spec.ts`:
```ts
import { COMPANY_SECTION } from './settings.section-registry';

describe('COMPANY_SECTION', () => {
  const keys = COMPANY_SECTION.fields.map((f) => f.key);

  it('mantém os campos de identidade já existentes', () => {
    for (const k of ['companyName', 'legalName', 'taxId', 'phone', 'email', 'logoUrl', 'primaryColor']) {
      expect(keys).toContain(k);
    }
  });

  it('inclui os campos fiscais para NF-e', () => {
    for (const k of ['inscricaoEstadual', 'inscricaoMunicipal', 'regimeTributario', 'cnae', 'cep', 'logradouro', 'numero', 'bairro', 'municipio', 'uf']) {
      expect(keys).toContain(k);
    }
  });

  it('regimeTributario é select com opções e uf tem 27 UFs', () => {
    const regime = COMPANY_SECTION.fields.find((f) => f.key === 'regimeTributario')!;
    expect(regime.type).toBe('select');
    expect(regime.options?.map((o) => o.value)).toEqual(
      expect.arrayContaining(['simples', 'mei', 'presumido', 'real']),
    );
    const uf = COMPANY_SECTION.fields.find((f) => f.key === 'uf')!;
    expect(uf.type).toBe('select');
    expect(uf.options).toHaveLength(27);
  });

  it('themePreset é select e inclui tangerina (default) + variações', () => {
    const t = COMPANY_SECTION.fields.find((f) => f.key === 'themePreset')!;
    expect(t.type).toBe('select');
    expect(t.options?.map((o) => o.value)).toEqual(
      expect.arrayContaining(['tangerina', 'vermelho', 'azul', 'verde', 'roxo', 'petroleo', 'ambar']),
    );
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd back && npx jest src/modules/settings/settings.section-registry.spec.ts`
Expected: FAIL (campos fiscais ausentes; `select`/`options` não existem no tipo).

- [ ] **Step 3: Implementar**

Substituir o conteúdo de `back/src/modules/settings/settings.section-registry.ts` por:
```ts
import { Injectable } from '@nestjs/common';

export type SettingsFieldType =
  | 'text' | 'email' | 'tel' | 'url' | 'color' | 'bool' | 'select' | 'image';

export interface SettingsFieldOption { value: string; label: string }

export interface SettingsFieldSchema {
  key: string;
  label: string;
  type: SettingsFieldType;
  options?: SettingsFieldOption[]; // só para type 'select'
  group?: string;                  // subtítulo p/ agrupar na UI (ex.: 'Fiscal')
}

export interface SettingsSection {
  key: string;
  title: string;
  moduleKey: string | null; // null = núcleo; senão aparece só se o módulo estiver habilitado
  fields: SettingsFieldSchema[];
}

@Injectable()
export class SettingsSectionRegistry {
  private readonly sections = new Map<string, SettingsSection>();
  register(section: SettingsSection): void {
    this.sections.set(section.key, section);
  }
  moduleSections(): SettingsSection[] {
    return [...this.sections.values()].filter((s) => s.moduleKey !== null);
  }
}

const UFS = [
  'AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG','PA','PB',
  'PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO',
].map((u) => ({ value: u, label: u }));

const REGIMES: SettingsFieldOption[] = [
  { value: 'simples', label: 'Simples Nacional' },
  { value: 'mei', label: 'MEI' },
  { value: 'presumido', label: 'Lucro Presumido' },
  { value: 'real', label: 'Lucro Real' },
];

// Presets de tema (a UI mapeia value->cor-semente; o back só guarda a escolha).
export const THEME_PRESETS: SettingsFieldOption[] = [
  { value: 'tangerina', label: 'Tangerina (padrão)' },
  { value: 'vermelho', label: 'Vermelho' },
  { value: 'azul', label: 'Azul' },
  { value: 'verde', label: 'Verde' },
  { value: 'roxo', label: 'Roxo' },
  { value: 'petroleo', label: 'Petróleo' },
  { value: 'ambar', label: 'Âmbar' },
];

export const COMPANY_SECTION: SettingsSection = {
  key: 'company',
  title: 'Empresa & Identidade visual',
  moduleKey: null,
  fields: [
    // Identidade
    { key: 'companyName', label: 'Nome fantasia', type: 'text', group: 'Identidade' },
    { key: 'legalName', label: 'Razão social', type: 'text', group: 'Identidade' },
    { key: 'taxId', label: 'CNPJ / documento', type: 'text', group: 'Identidade' },
    { key: 'phone', label: 'Telefone / WhatsApp', type: 'tel', group: 'Identidade' },
    { key: 'email', label: 'E-mail', type: 'email', group: 'Identidade' },
    { key: 'website', label: 'Site', type: 'url', group: 'Identidade' },
    { key: 'logoUrl', label: 'Logo', type: 'image', group: 'Identidade' },
    // Fiscal (para o módulo de Nota Fiscal)
    { key: 'inscricaoEstadual', label: 'Inscrição Estadual', type: 'text', group: 'Fiscal' },
    { key: 'inscricaoMunicipal', label: 'Inscrição Municipal', type: 'text', group: 'Fiscal' },
    { key: 'regimeTributario', label: 'Regime tributário', type: 'select', options: REGIMES, group: 'Fiscal' },
    { key: 'cnae', label: 'CNAE principal', type: 'text', group: 'Fiscal' },
    // Endereço fiscal estruturado (NF-e exige)
    { key: 'cep', label: 'CEP', type: 'text', group: 'Endereço' },
    { key: 'logradouro', label: 'Logradouro', type: 'text', group: 'Endereço' },
    { key: 'numero', label: 'Número', type: 'text', group: 'Endereço' },
    { key: 'complemento', label: 'Complemento', type: 'text', group: 'Endereço' },
    { key: 'bairro', label: 'Bairro', type: 'text', group: 'Endereço' },
    { key: 'municipio', label: 'Município', type: 'text', group: 'Endereço' },
    { key: 'uf', label: 'UF', type: 'select', options: UFS, group: 'Endereço' },
    // Aparência
    { key: 'themePreset', label: 'Tema do sistema', type: 'select', options: THEME_PRESETS, group: 'Aparência' },
    { key: 'primaryColor', label: 'Cor primária', type: 'color', group: 'Aparência' },
    { key: 'secondaryColor', label: 'Cor secundária', type: 'color', group: 'Aparência' },
  ],
};
```
> `address` (texto livre) foi substituído pelo endereço estruturado (NF-e precisa dos campos separados). Dados antigos em `tenant.settings.address` continuam no JSONB sem quebrar nada; a UI nova não os edita. Documentar em `docs/configuracao.md`.

- [ ] **Step 4: Rodar e ver passar**

Run: `cd back && npx jest src/modules/settings/settings.section-registry.spec.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add back/src/modules/settings/settings.section-registry.ts back/src/modules/settings/settings.section-registry.spec.ts
git commit -m "feat(settings): campos fiscais + endereço estruturado + themePreset; tipos select/email/tel/image

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

### Task 1.2: DTO valida os campos novos

**Files:**
- Modify: `back/src/modules/settings/dto/settings.dto.ts`
- Test: `back/src/modules/settings/dto/settings.dto.spec.ts`

**Interfaces:**
- Produces: `UpdateCompanyDto` com os campos novos (todos `@IsOptional`).

- [ ] **Step 1: Teste que falha**

`back/src/modules/settings/dto/settings.dto.spec.ts`:
```ts
import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { UpdateCompanyDto } from './settings.dto';

async function errs(obj: Record<string, unknown>) {
  return validate(plainToInstance(UpdateCompanyDto, obj));
}

describe('UpdateCompanyDto', () => {
  it('aceita um payload fiscal válido', async () => {
    expect(await errs({
      legalName: 'Oficina Silva ME', taxId: '12345678000199',
      regimeTributario: 'simples', uf: 'SP', themePreset: 'azul',
      email: 'a@b.com', primaryColor: '#2E6BE6',
    })).toHaveLength(0);
  });
  it('rejeita regimeTributario fora da lista', async () => {
    expect((await errs({ regimeTributario: 'inventado' })).length).toBeGreaterThan(0);
  });
  it('rejeita uf inválida e themePreset inválido', async () => {
    expect((await errs({ uf: 'XX' })).length).toBeGreaterThan(0);
    expect((await errs({ themePreset: 'arcoiris' })).length).toBeGreaterThan(0);
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd back && npx jest src/modules/settings/dto/settings.dto.spec.ts`
Expected: FAIL (campos não existem / sem validação de enum).

- [ ] **Step 3: Implementar**

Substituir `back/src/modules/settings/dto/settings.dto.ts`:
```ts
import { IsEmail, IsIn, IsOptional, IsString, IsUrl, Matches } from 'class-validator';

const HEX = /^#([0-9a-fA-F]{6})$/;
const UFS = ['AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG','PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'];
const REGIMES = ['simples', 'mei', 'presumido', 'real'];
const PRESETS = ['tangerina', 'vermelho', 'azul', 'verde', 'roxo', 'petroleo', 'ambar'];

export class UpdateCompanyDto {
  // Identidade
  @IsOptional() @IsString() companyName?: string;
  @IsOptional() @IsString() legalName?: string;
  @IsOptional() @IsString() taxId?: string;
  @IsOptional() @IsString() phone?: string;
  @IsOptional() @IsEmail() email?: string;
  @IsOptional() @IsUrl({ require_tld: false }) website?: string;
  @IsOptional() @IsUrl({ require_tld: false }) logoUrl?: string;
  // Fiscal
  @IsOptional() @IsString() inscricaoEstadual?: string;
  @IsOptional() @IsString() inscricaoMunicipal?: string;
  @IsOptional() @IsIn(REGIMES, { message: 'regimeTributario inválido' }) regimeTributario?: string;
  @IsOptional() @IsString() cnae?: string;
  // Endereço
  @IsOptional() @IsString() cep?: string;
  @IsOptional() @IsString() logradouro?: string;
  @IsOptional() @IsString() numero?: string;
  @IsOptional() @IsString() complemento?: string;
  @IsOptional() @IsString() bairro?: string;
  @IsOptional() @IsString() municipio?: string;
  @IsOptional() @IsIn(UFS, { message: 'uf inválida' }) uf?: string;
  // Aparência
  @IsOptional() @IsIn(PRESETS, { message: 'themePreset inválido' }) themePreset?: string;
  @IsOptional() @Matches(HEX, { message: 'primaryColor deve ser hex #RRGGBB' }) primaryColor?: string;
  @IsOptional() @Matches(HEX, { message: 'secondaryColor deve ser hex #RRGGBB' }) secondaryColor?: string;
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `cd back && npx jest src/modules/settings/dto/settings.dto.spec.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add back/src/modules/settings/dto/settings.dto.ts back/src/modules/settings/dto/settings.dto.spec.ts
git commit -m "feat(settings): valida campos fiscais/endereço/tema no UpdateCompanyDto

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

### Task 1.3: Sincronizar colunas tipadas do tenant ao salvar identidade

Por quê: `/me` e a sidebar leem `tenant.name`/`legal_name`/`trade_name`/`cnpj` (colunas), mas a tela edita `tenant.settings`. Sem sync, `/me` fica defasado. `settings` chama o **service público** da tenancy (dona da tabela `tenant`) — respeita "aponta, não invade".

**Files:**
- Modify: `back/src/modules/tenancy/tenancy.repository.ts`, `back/src/modules/tenancy/tenancy.service.ts`
- Modify: `back/src/modules/settings/settings.service.ts`
- Test: `back/src/modules/tenancy/tenancy.repository.ts` coberto via e2e (Task 2.3); unit do service abaixo.

**Interfaces:**
- Produces: `TenancyService.syncCompanyIdentity(tenantId, { tradeName?, legalName?, cnpj? }): Promise<void>`.
- Consumes (settings): chama o acima dentro de `updateCompany`.

- [ ] **Step 1: Implementar repo (dono da tabela tenant)**

Adicionar em `back/src/modules/tenancy/tenancy.repository.ts`:
```ts
  async updateTenantIdentity(
    tenantId: string,
    data: { trade_name?: string | null; legal_name?: string | null; cnpj?: string | null; name?: string },
  ): Promise<void> {
    await this.prisma.tenant.update({ where: { id: tenantId }, data });
  }
```

- [ ] **Step 2: Implementar service**

Adicionar em `back/src/modules/tenancy/tenancy.service.ts`:
```ts
  /** Sincroniza colunas tipadas a partir do company settings (chamado pelo Settings). */
  async syncCompanyIdentity(
    tenantId: string,
    id: { tradeName?: string; legalName?: string; cnpj?: string },
  ): Promise<void> {
    const data: { trade_name?: string; legal_name?: string; cnpj?: string; name?: string } = {};
    if (id.tradeName !== undefined) { data.trade_name = id.tradeName; data.name = id.tradeName; }
    if (id.legalName !== undefined) data.legal_name = id.legalName;
    if (id.cnpj !== undefined) data.cnpj = id.cnpj;
    if (Object.keys(data).length === 0) return;
    await this.repo.updateTenantIdentity(tenantId, data);
  }
```
> `cnpj` tem UNIQUE no schema; se colidir, o Prisma lança P2002 → o filtro global devolve 409. Aceitável (CNPJ duplicado entre tenants é erro real).

- [ ] **Step 3: Ligar no settings.service**

Em `back/src/modules/settings/settings.service.ts`, dentro de `updateCompany`, depois do `updateCompanySettings` e antes do `audit.log`:
```ts
    await this.tenancy.syncCompanyIdentity(user.tenantId, {
      tradeName: dto.companyName,
      legalName: dto.legalName,
      cnpj: dto.taxId,
    });
```

- [ ] **Step 4: Unit do settings.service (mock tenancy)**

`back/src/modules/settings/settings.service.spec.ts`:
```ts
import { SettingsService } from './settings.service';

describe('SettingsService.updateCompany', () => {
  it('faz merge, persiste, sincroniza identidade e audita', async () => {
    const tenancy = {
      getCompanySettings: jest.fn(async () => ({ companyName: 'Velho' })),
      updateCompanySettings: jest.fn(async () => undefined),
      syncCompanyIdentity: jest.fn(async () => undefined),
    } as any;
    const audit = { log: jest.fn(async () => undefined) } as any;
    const billing = { getEnabledModules: jest.fn(async () => []) } as any;
    const registry = { moduleSections: () => [] } as any;
    const svc = new SettingsService(registry, billing, tenancy, audit);
    const user = { tenantId: 't1', userId: 'u1' } as any;

    const res = await svc.updateCompany(user, { companyName: 'Novo', legalName: 'Novo ME', taxId: '123' } as any);

    expect(tenancy.updateCompanySettings).toHaveBeenCalledWith('t1', expect.objectContaining({ companyName: 'Novo' }));
    expect(tenancy.syncCompanyIdentity).toHaveBeenCalledWith('t1', { tradeName: 'Novo', legalName: 'Novo ME', cnpj: '123' });
    expect(audit.log).toHaveBeenCalledWith('t1', 'u1', 'settings_change', 'company');
    expect(res.company.companyName).toBe('Novo');
  });
});
```

- [ ] **Step 5: Rodar**

Run: `cd back && npx jest src/modules/settings/settings.service.spec.ts`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add back/src/modules/tenancy/tenancy.repository.ts back/src/modules/tenancy/tenancy.service.ts back/src/modules/settings/settings.service.ts back/src/modules/settings/settings.service.spec.ts
git commit -m "feat(settings): sincroniza colunas tipadas do tenant (name/legal/cnpj) ao salvar empresa

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Phase 2 — Backend: upload de logo

### Task 2.1: Endpoint de upload e remoção de logo

**Files:**
- Create: `back/src/modules/settings/settings.types.ts`
- Modify: `back/src/modules/settings/settings.controller.ts`, `back/src/modules/settings/settings.service.ts`, `back/src/modules/settings/settings.module.ts`

**Interfaces:**
- Consumes: `STORAGE_PROVIDER` (token global), `TenancyService.getCompanySettings/updateCompanySettings`.
- Produces: `POST /settings/company/logo` (multipart `file`) → `{ company }`; `DELETE /settings/company/logo` → `{ company }`. `SettingsService.uploadLogo(user, file)`, `removeLogo(user)`.

- [ ] **Step 1: Tipo do arquivo (sem acoplar ao OS)**

`back/src/modules/settings/settings.types.ts`:
```ts
/** Shape do arquivo multipart (memoryStorage do multer). Local p/ não acoplar ao OS. */
export interface UploadedImage {
  buffer: Buffer;
  mimetype: string;
  size: number;
  originalname: string;
}
```

- [ ] **Step 2: Service — uploadLogo / removeLogo**

Em `back/src/modules/settings/settings.service.ts`: importar e injetar storage; adicionar métodos. Topo do arquivo:
```ts
import { BadRequestException, Inject, Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { STORAGE_PROVIDER, StorageProvider } from '../../common/storage/storage.provider';
import { UploadedImage } from './settings.types';
```
Construtor: adicionar `@Inject(STORAGE_PROVIDER) private readonly storage: StorageProvider,`.
Métodos:
```ts
  private static readonly MAX_LOGO_BYTES = 4 * 1024 * 1024;

  async uploadLogo(user: AuthUser, file: UploadedImage | undefined) {
    if (!file?.buffer) throw new BadRequestException('Arquivo de imagem é obrigatório.');
    if (!file.mimetype?.startsWith('image/')) throw new BadRequestException('O arquivo deve ser uma imagem.');
    if (file.size > SettingsService.MAX_LOGO_BYTES) throw new BadRequestException('Imagem muito grande (máx. 4 MB).');

    const ext = (file.mimetype.split('/')[1] || 'png').replace(/[^a-z0-9]/gi, '');
    const key = `tenant/${user.tenantId}/logo/${randomUUID()}.${ext}`;
    // I/O FORA de transação (regra de ouro).
    await this.storage.put(key, file.buffer, file.mimetype);
    const url = this.storage.url(key);

    const current = await this.tenancy.getCompanySettings(user.tenantId);
    const oldKey = (current.logoStorageKey as string | undefined) ?? null;
    const merged = { ...current, logoUrl: url, logoStorageKey: key };
    await this.tenancy.updateCompanySettings(user.tenantId, merged);
    await this.audit.log(user.tenantId, user.userId, 'settings_change', 'company.logo');
    if (oldKey && oldKey !== key) { try { await this.storage.remove(oldKey); } catch { /* best-effort */ } }
    return { company: merged };
  }

  async removeLogo(user: AuthUser) {
    const current = await this.tenancy.getCompanySettings(user.tenantId);
    const key = current.logoStorageKey as string | undefined;
    const merged = { ...current };
    delete (merged as Record<string, unknown>).logoUrl;
    delete (merged as Record<string, unknown>).logoStorageKey;
    await this.tenancy.updateCompanySettings(user.tenantId, merged);
    await this.audit.log(user.tenantId, user.userId, 'settings_change', 'company.logo');
    if (key) { try { await this.storage.remove(key); } catch { /* best-effort */ } }
    return { company: merged };
  }
```

- [ ] **Step 3: Controller — rotas multipart**

Em `back/src/modules/settings/settings.controller.ts`:
```ts
import { Body, Controller, Delete, Get, HttpCode, Patch, Post, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { memoryStorage } from 'multer';
// ...imports existentes + UploadedImage
import { UploadedImage } from './settings.types';

  @Post('company/logo')
  @Permissions('settings.manage')
  @HttpCode(200)
  @UseInterceptors(FileInterceptor('file', { storage: memoryStorage(), limits: { fileSize: 4 * 1024 * 1024 } }))
  uploadLogo(@CurrentUser() user: AuthUser, @UploadedFile() file: UploadedImage | undefined) {
    return this.settings.uploadLogo(user, file);
  }

  @Delete('company/logo')
  @Permissions('settings.manage')
  @HttpCode(200)
  removeLogo(@CurrentUser() user: AuthUser) {
    return this.settings.removeLogo(user);
  }
```

- [ ] **Step 4: Build + lint**

Run: `cd back && npm run build && npm run lint`
Expected: build ok; lint 0 warnings. (StorageModule é `@Global`, então o token já é injetável sem novo import no settings.module.)

- [ ] **Step 5: Commit**

```bash
git add back/src/modules/settings/
git commit -m "feat(settings): upload e remoção de logo via StorageProvider (memoryStorage, 4MB, image/*)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

### Task 2.2: e2e — empresa, logo, permissão, isolamento

**Files:**
- Modify/extend: `back/test/settings.e2e-spec.ts` (se não existir, criar)

- [ ] **Step 1: Escrever e2e**

Estender `back/test/settings.e2e-spec.ts` (seguir o helper de boot/login usado nos outros e2e do projeto — `test/helpers`). Casos:
```ts
// pseudo-estrutura: usa o helper existente para registrar tenant + login owner.
// 1. PATCH /settings/company com campos fiscais -> 200; GET /settings reflete os valores e /me reflete legalName/tradeName sincronizados.
// 2. PATCH /settings/company como cargo SEM settings.manage (ex.: mechanic) -> 403.
// 3. POST /settings/company/logo com um buffer PNG pequeno (supertest .attach) -> 200, company.logoUrl definido (regex /files/ ou http).
// 4. POST /settings/company/logo com um .txt -> 400 ("deve ser uma imagem").
// 5. Isolamento: tenant A grava companyName; GET /settings do tenant B NÃO vê o valor de A.
```
Implementar concretamente com o mesmo estilo dos e2e existentes (ver `back/test/*.e2e-spec.ts` para o helper de auth e `.attach('file', Buffer.from(...), { filename, contentType })`).

- [ ] **Step 2: Rodar (flush redis antes)**

Run:
```bash
podman exec orbix-redis redis-cli FLUSHALL
cd back && npm run test:e2e -- test/settings.e2e-spec.ts
```
Expected: todos PASS. (e2e usa `forceExit` já configurado.)

- [ ] **Step 3: Commit**

```bash
git add back/test/settings.e2e-spec.ts
git commit -m "test(settings): e2e empresa/fiscal, upload de logo, permissão e isolamento de tenant

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

### Task 2.3: Documentar em docs/configuracao.md

**Files:**
- Modify: `docs/configuracao.md`

- [ ] **Step 1: Atualizar a tabela da seção Empresa** com os campos novos (chave em `tenant.settings`, tipo, grupo) e remover/observar `address` (legado). Adicionar nota: logo é upload (`POST /settings/company/logo`), guardado via StorageProvider; `logoStorageKey` é interno.

- [ ] **Step 2: Adicionar subseção "### Nota Fiscal (módulo `invoice`) — planejado"** explicitando a fronteira:
  - **No config da empresa (núcleo, agora):** CNPJ, razão social, IE, IM, regime tributário, CNAE, endereço fiscal completo. São identidade do tenant, usadas por vários módulos.
  - **No próprio módulo `invoice` (quando existir, via seção registrada):** certificado digital A1 (.pfx, sensível/criptografado), ambiente (homologação/produção), série e numeração de NF, CSC/token NFC-e. Operacional e sensível → dono é o `invoice` (aponta, não invade).

- [ ] **Step 3: Commit**

```bash
git add docs/configuracao.md
git commit -m "docs(configuracao): seção Empresa (fiscal+tema) e fronteira do módulo invoice (NF-e)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Phase 3 — Frontend: presets de tema + scaffold da feature settings

### Task 3.1: Presets de tema

**Files:**
- Create: `front/lib/core/theme/theme_presets.dart`
- Modify: `front/lib/core/theme/branding.dart`
- Test: `front/test/theme_presets_test.dart`

**Interfaces:**
- Produces: `class ThemePreset { final String key; final String label; final Color seed; }`; `const kThemePresets` (List<ThemePreset>); `Color seedForPreset(String? key)`; `String? presetForSeed(Color seed)`.

- [ ] **Step 1: Teste que falha**

`front/test/theme_presets_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbixhub/core/theme/app_colors.dart';
import 'package:orbixhub/core/theme/theme_presets.dart';

void main() {
  test('tangerina é o default e mapeia para AppColors.brand', () {
    expect(seedForPreset('tangerina').value, AppColors.brand.value);
    expect(seedForPreset(null).value, AppColors.brand.value); // fallback
    expect(seedForPreset('inexistente').value, AppColors.brand.value);
  });
  test('inclui 7 presets com chaves esperadas', () {
    expect(kThemePresets.map((p) => p.key), containsAll(
      ['tangerina', 'vermelho', 'azul', 'verde', 'roxo', 'petroleo', 'ambar']));
    expect(kThemePresets.length, 7);
  });
  test('presetForSeed faz o caminho inverso', () {
    expect(presetForSeed(seedForPreset('azul')), 'azul');
  });
}
```
> Confirme o nome do package em `front/pubspec.yaml` (`name:`) e ajuste os imports `package:<name>/...` se não for `orbixhub`.

- [ ] **Step 2: Rodar e ver falhar**

Run: `C:\Users\KaueSobral\develop\flutter\bin\flutter.bat test test/theme_presets_test.dart` (a partir de `front/`)
Expected: FAIL (arquivo não existe).

- [ ] **Step 3: Implementar**

`front/lib/core/theme/theme_presets.dart`:
```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Um tema do sistema = uma cor-semente curada. O ColorScheme.fromSeed gera
/// claro e escuro a partir dela; a sidebar grafite é constante em todos.
class ThemePreset {
  final String key;
  final String label;
  final Color seed;
  const ThemePreset(this.key, this.label, this.seed);
}

const kThemePresets = <ThemePreset>[
  ThemePreset('tangerina', 'Tangerina', AppColors.brand), // #EC5E12 (padrão atual)
  ThemePreset('vermelho', 'Vermelho', Color(0xFFD7263D)),
  ThemePreset('azul', 'Azul', Color(0xFF2E6BE6)),
  ThemePreset('verde', 'Verde', Color(0xFF0E9F6E)),
  ThemePreset('roxo', 'Roxo', Color(0xFF7C3AED)),
  ThemePreset('petroleo', 'Petróleo', Color(0xFF0E7C86)),
  ThemePreset('ambar', 'Âmbar', Color(0xFFE8A302)),
];

Color seedForPreset(String? key) {
  for (final p in kThemePresets) {
    if (p.key == key) return p.seed;
  }
  return AppColors.brand;
}

String? presetForSeed(Color seed) {
  for (final p in kThemePresets) {
    if (p.seed.value == seed.value) return p.key;
  }
  return null;
}
```

- [ ] **Step 4: branding lê o preset (fallback primaryColor)**

Substituir o corpo do `try` em `front/lib/core/theme/branding.dart` para preferir `themePreset`:
```dart
    final res = await ref.read(dioProvider).get<Object?>('/settings');
    final data = (res.data as Map)['company'];
    final preset = (data is Map ? data['themePreset'] : null) as String?;
    if (preset != null) return seedForPreset(preset);
    final hex = (data is Map ? data['primaryColor'] : null) as String?;
    if (hex != null && RegExp(r'^#([0-9a-fA-F]{6})$').hasMatch(hex)) {
      return Color(int.parse('FF${hex.substring(1)}', radix: 16));
    }
```
Adicionar `import 'theme_presets.dart';` no topo.

- [ ] **Step 5: Rodar e ver passar**

Run: `C:\Users\KaueSobral\develop\flutter\bin\flutter.bat test test/theme_presets_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add front/lib/core/theme/theme_presets.dart front/lib/core/theme/branding.dart front/test/theme_presets_test.dart
git commit -m "feat(front/theme): presets de tema curados + branding resolve themePreset->seed

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

### Task 3.2: Domain + data da feature settings

**Files:**
- Create: `front/lib/features/settings/domain/settings_models.dart`
- Create: `front/lib/features/settings/domain/settings_repository.dart`
- Create: `front/lib/features/settings/data/settings_repository_impl.dart`
- Create: `front/lib/features/settings/data/fake_settings_repository.dart`
- Modify: `front/lib/di.dart`

**Interfaces:**
- Produces: `CompanySettings` (freezed, todos os campos como `String?`/`Map` flexível), `SettingsField`, `SettingsSection`, `SettingsBundle{company: Map<String,dynamic>, sections: List<SettingsSection>}`; `abstract class SettingsRepository { Future<SettingsBundle> fetch(); Future<Map<String,dynamic>> updateCompany(Map<String,dynamic> patch); Future<Map<String,dynamic>> uploadLogo(Uint8List bytes, String filename, String contentType); Future<Map<String,dynamic>> removeLogo(); }`; `settingsRepositoryProvider`.

- [ ] **Step 1: Models freezed**

`front/lib/features/settings/domain/settings_models.dart`:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';
part 'settings_models.freezed.dart';
part 'settings_models.g.dart';

@freezed
class SettingsFieldOption with _$SettingsFieldOption {
  const factory SettingsFieldOption({required String value, required String label}) = _SettingsFieldOption;
  factory SettingsFieldOption.fromJson(Map<String, dynamic> j) => _$SettingsFieldOptionFromJson(j);
}

@freezed
class SettingsField with _$SettingsField {
  const factory SettingsField({
    required String key,
    required String label,
    required String type,
    @Default(<SettingsFieldOption>[]) List<SettingsFieldOption> options,
    String? group,
  }) = _SettingsField;
  factory SettingsField.fromJson(Map<String, dynamic> j) => _$SettingsFieldFromJson(j);
}

@freezed
class SettingsSection with _$SettingsSection {
  const factory SettingsSection({
    required String key,
    required String title,
    String? moduleKey,
    @Default(<SettingsField>[]) List<SettingsField> fields,
  }) = _SettingsSection;
  factory SettingsSection.fromJson(Map<String, dynamic> j) => _$SettingsSectionFromJson(j);
}

@freezed
class SettingsBundle with _$SettingsBundle {
  const factory SettingsBundle({
    @Default(<String, dynamic>{}) Map<String, dynamic> company,
    @Default(<SettingsSection>[]) List<SettingsSection> sections,
  }) = _SettingsBundle;
  factory SettingsBundle.fromJson(Map<String, dynamic> j) => _$SettingsBundleFromJson(j);
}
```

- [ ] **Step 2: Repository interface**

`front/lib/features/settings/domain/settings_repository.dart`:
```dart
import 'dart:typed_data';
import 'settings_models.dart';

abstract class SettingsRepository {
  Future<SettingsBundle> fetch();
  Future<Map<String, dynamic>> updateCompany(Map<String, dynamic> patch);
  Future<Map<String, dynamic>> uploadLogo(Uint8List bytes, String filename, String contentType);
  Future<Map<String, dynamic>> removeLogo();
}
```

- [ ] **Step 3: Impl dio**

`front/lib/features/settings/data/settings_repository_impl.dart`:
```dart
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../domain/settings_models.dart';
import '../domain/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<SettingsBundle> fetch() async {
    final res = await _dio.get<Object?>('/settings');
    return SettingsBundle.fromJson((res.data as Map).cast<String, dynamic>());
  }

  @override
  Future<Map<String, dynamic>> updateCompany(Map<String, dynamic> patch) async {
    final res = await _dio.patch<Object?>('/settings/company', data: patch);
    return ((res.data as Map)['company'] as Map).cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> uploadLogo(Uint8List bytes, String filename, String contentType) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename,
          contentType: DioMediaType.parse(contentType)),
    });
    final res = await _dio.post<Object?>('/settings/company/logo', data: form);
    return ((res.data as Map)['company'] as Map).cast<String, dynamic>();
  }

  @override
  Future<Map<String, dynamic>> removeLogo() async {
    final res = await _dio.delete<Object?>('/settings/company/logo');
    return ((res.data as Map)['company'] as Map).cast<String, dynamic>();
  }
}
```
> Confirme a classe de media type usada na versão do dio do projeto (`DioMediaType` no dio 5.4+, ou `MediaType` de `http_parser`). Olhe como o OS faz upload no front (`os_repository_impl.dart`) e siga o mesmo.

- [ ] **Step 4: Fake**

`front/lib/features/settings/data/fake_settings_repository.dart`:
```dart
import 'dart:typed_data';
import '../domain/settings_models.dart';
import '../domain/settings_repository.dart';

class FakeSettingsRepository implements SettingsRepository {
  Map<String, dynamic> _company = {'companyName': 'Oficina Demo', 'themePreset': 'tangerina'};

  @override
  Future<SettingsBundle> fetch() async => SettingsBundle(
        company: Map.of(_company),
        sections: const [
          SettingsSection(key: 'company', title: 'Empresa & Identidade visual', fields: []),
        ],
      );
  @override
  Future<Map<String, dynamic>> updateCompany(Map<String, dynamic> patch) async {
    _company = {..._company, ...patch};
    return Map.of(_company);
  }
  @override
  Future<Map<String, dynamic>> uploadLogo(Uint8List b, String f, String c) async {
    _company = {..._company, 'logoUrl': 'https://example/logo.png'};
    return Map.of(_company);
  }
  @override
  Future<Map<String, dynamic>> removeLogo() async {
    _company = {..._company}..remove('logoUrl');
    return Map.of(_company);
  }
}
```

- [ ] **Step 5: Registrar no di.dart**

Em `front/lib/di.dart` (perto dos outros repositories):
```dart
import 'features/settings/data/settings_repository_impl.dart';
import 'features/settings/domain/settings_repository.dart';

final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => SettingsRepositoryImpl(ref.read(dioProvider)));
```
> Se o projeto usa `diOverrides` com fakes em teste, adicionar override análogo aos existentes.

- [ ] **Step 6: Codegen + analyze**

Run (em `front/`):
```bash
C:\Users\KaueSobral\develop\flutter\bin\dart.bat run build_runner build --delete-conflicting-outputs
C:\Users\KaueSobral\develop\flutter\bin\flutter.bat analyze
```
Expected: gera `*.freezed.dart`/`*.g.dart`; analyze sem issues.

- [ ] **Step 7: Commit**

```bash
git add front/lib/features/settings/domain front/lib/features/settings/data front/lib/di.dart
git commit -m "feat(front/settings): domain models (freezed) + repository (dio + fake) + DI

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Phase 4 — Frontend: tela de Configurações (empresa + logo + seções dinâmicas)

### Task 4.1: Controller de estado da tela

**Files:**
- Create: `front/lib/features/settings/presentation/settings_controller.dart`
- Test: `front/test/settings_controller_test.dart`

**Interfaces:**
- Produces: estado selado `SettingsState (Loading|Ready(bundle)|Error(msg))`; `SettingsController extends AsyncNotifier`-like (seguir padrão do projeto — provavelmente `Notifier<SettingsState>` + load no build); métodos `Future<void> load()`, `Future<void> saveCompany(Map patch)`, `Future<void> uploadLogo(...)`, `Future<void> removeLogo()`; `settingsControllerProvider`.

- [ ] **Step 1: Teste com fake repo**

`front/test/settings_controller_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbixhub/di.dart';
import 'package:orbixhub/features/settings/data/fake_settings_repository.dart';
import 'package:orbixhub/features/settings/domain/settings_repository.dart';
import 'package:orbixhub/features/settings/presentation/settings_controller.dart';

void main() {
  test('carrega e salva company via fake', () async {
    final container = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository() as SettingsRepository),
    ]);
    addTearDown(container.dispose);

    await container.read(settingsControllerProvider.notifier).load();
    final st = container.read(settingsControllerProvider);
    expect(st.whenOrNull(ready: (b) => b.company['companyName']), 'Oficina Demo');

    await container.read(settingsControllerProvider.notifier).saveCompany({'companyName': 'Nova'});
    final st2 = container.read(settingsControllerProvider);
    expect(st2.whenOrNull(ready: (b) => b.company['companyName']), 'Nova');
  });
}
```
> Ajuste a forma do estado (`whenOrNull`) ao padrão real de estado selado do projeto (ver `session_state.dart`). Se o projeto usa `AsyncValue`, use `AsyncValue` aqui em vez de um union custom.

- [ ] **Step 2: Implementar controller** seguindo o padrão de Notifier/estado do projeto (espelhar `session_controller.dart`). Carrega `repo.fetch()`; `saveCompany` faz `repo.updateCompany(patch)`, atualiza o bundle e **invalida `brandingSeedProvider`** quando `themePreset`/`primaryColor` mudaram (para o tema re-renderizar na hora):
```dart
    if (patch.containsKey('themePreset') || patch.containsKey('primaryColor')) {
      ref.invalidate(brandingSeedProvider);
    }
```

- [ ] **Step 3: Rodar teste**

Run: `C:\Users\KaueSobral\develop\flutter\bin\flutter.bat test test/settings_controller_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add front/lib/features/settings/presentation/settings_controller.dart front/test/settings_controller_test.dart
git commit -m "feat(front/settings): controller (carrega/salva, invalida branding ao trocar tema)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

### Task 4.2: Tela + form da empresa + upload de logo + seções dinâmicas

**Files:**
- Create: `front/lib/features/settings/presentation/settings_screen.dart`
- Create: `front/lib/features/settings/presentation/company_form.dart`
- Create: `front/lib/features/settings/presentation/dynamic_section.dart`
- Modify: `front/lib/core/router/app_router.dart`

- [ ] **Step 1: Form da empresa** (`company_form.dart`): campos agrupados (Identidade / Fiscal / Endereço) usando `TextEditingController`s; selects (regime, UF) como `DropdownButtonFormField`; logo com `file_picker` (espelhar `os_detail_screen.dart`: `FilePicker.pickFiles(type: FileType.image, withData: true)` → `settingsController.uploadLogo(bytes, name, 'image/<ext>')`), mostrando logo atual (`Image.network(company['logoUrl'])`) com botão "Remover". Botão "Salvar" → `saveCompany(patchMap)`. Strings PT-BR. Usar `Theme.of(context).colorScheme` (não cores hardcoded). FilledButton em Row → `minimumSize: Size(0, 48)` (bug conhecido).

- [ ] **Step 2: Seção dinâmica** (`dynamic_section.dart`): recebe `SettingsSection` + valores e renderiza por `field.type` (`text/email/tel/url`→TextField; `bool`→Switch; `select`→Dropdown com `field.options`; `color`→swatch/!editável aqui; `image`→preview). É o que mostra seções de módulos (ex.: customers/inventory) genericamente.

- [ ] **Step 3: Tela host** (`settings_screen.dart`): `ConsumerWidget` que assiste `settingsControllerProvider`; estados loading/erro/pronto; abas ou lista de seções: **Empresa** (company_form), **Aparência** (Task 5.1), e uma `DynamicSection` para cada `bundle.sections` com `moduleKey != null`. Devolve só o corpo (o shell é dono da moldura).

- [ ] **Step 4: Rota** em `front/lib/core/router/app_router.dart`: adicionar rota `/configuracoes` apontando para `SettingsScreen`, dentro do shell autenticado, **guardada**: se `me.permissions` não contém `settings.manage`, redireciona/mostra 403 elegante (seguir o padrão de gating do router do projeto).

- [ ] **Step 5: analyze**

Run: `C:\Users\KaueSobral\develop\flutter\bin\flutter.bat analyze`
Expected: 0 issues.

- [ ] **Step 6: Commit**

```bash
git add front/lib/features/settings/presentation/ front/lib/core/router/app_router.dart
git commit -m "feat(front/settings): tela Configurações — form empresa, upload de logo, seções dinâmicas + rota

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

### Task 4.3: Item de menu "Configurações" (gated)

**Files:**
- Modify: `front/lib/features/shell/presentation/nav_items.dart`
- Test: `front/test/nav_items_settings_test.dart`

- [ ] **Step 1: Teste de gating**

`front/test/nav_items_settings_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
// importar gatedNavItems + o tipo Me/fake do projeto (ver testes existentes de nav_items)
void main() {
  test('Configurações aparece para quem tem settings.manage', () {
    // montar um Me com permissions: ['settings.manage'] -> espera item com rota '/configuracoes'
  });
  test('Configurações some sem settings.manage', () {
    // Me sem a permissão -> item ausente
  });
}
```
> Preencher seguindo o teste de `gatedNavItems` que já existe no projeto (mesma fábrica de `Me`).

- [ ] **Step 2: Implementar** o item em `gatedNavItems(me)`: incluir "Configurações" (ícone settings, rota `/configuracoes`) quando `me.permissions.contains('settings.manage')`. É núcleo (não depende de módulo).

- [ ] **Step 3: Rodar**

Run: `C:\Users\KaueSobral\develop\flutter\bin\flutter.bat test test/nav_items_settings_test.dart`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add front/lib/features/shell/presentation/nav_items.dart front/test/nav_items_settings_test.dart
git commit -m "feat(front/shell): item de menu Configurações gated por settings.manage

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Phase 5 — Frontend: seletor de aparência + logo na sidebar

### Task 5.1: Seletor de tema (presets + claro/escuro) com preview

**Files:**
- Create: `front/lib/features/settings/presentation/appearance_section.dart`
- Test: `front/test/appearance_section_test.dart`

- [ ] **Step 1: Teste de widget**

`front/test/appearance_section_test.dart`:
```dart
// Monta AppearanceSection com ProviderContainer (fake settings repo + brandingSeed override),
// toca no swatch 'Azul' -> espera que settingsController.saveCompany seja chamado com {'themePreset':'azul'}
// e toca no segmento 'Escuro' -> espera themeControllerProvider == ThemeMode.dark.
```
Preencher com `WidgetTester` no padrão dos widget tests do projeto.

- [ ] **Step 2: Implementar** `appearance_section.dart`:
  - Grid de swatches a partir de `kThemePresets`: cada um mostra a `seed` (círculo) + label; selecionado = o `company['themePreset']` (ou `presetForSeed` do primaryColor). Ao tocar: `settingsController.saveCompany({'themePreset': preset.key})` (o controller invalida `brandingSeedProvider` → tema muda na hora).
  - Segmented control claro/escuro/sistema → `ref.read(themeControllerProvider.notifier).set(...)` (preferência por usuário; não vai pro backend).
  - Mini-preview (um Card com botão primário + texto) usando `Theme.of(context).colorScheme` pra mostrar como fica.

- [ ] **Step 3: analyze + test**

Run: `C:\Users\KaueSobral\develop\flutter\bin\flutter.bat analyze && C:\Users\KaueSobral\develop\flutter\bin\flutter.bat test test/appearance_section_test.dart`
Expected: 0 issues; PASS.

- [ ] **Step 4: Commit**

```bash
git add front/lib/features/settings/presentation/appearance_section.dart front/test/appearance_section_test.dart
git commit -m "feat(front/settings): seletor de tema (presets + claro/escuro) com preview ao vivo

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

### Task 5.2: Logo do tenant na sidebar

**Files:**
- Modify: `front/lib/features/shell/presentation/sidebar.dart`

- [ ] **Step 1: Implementar**: na sidebar, se `me`/settings tiver `logoUrl`, mostrar `Image.network(logoUrl, height: 26, errorBuilder: ... -> BrandMark)`; senão `BrandMark` (atual). Buscar o `logoUrl` da fonte já disponível (provavelmente um provider de company/settings; se não houver um leve, ler do `settingsControllerProvider`/um `companyProvider` simples). Evitar regressão de layout (manter altura/alinhamento).

- [ ] **Step 2: analyze**

Run: `C:\Users\KaueSobral\develop\flutter\bin\flutter.bat analyze`
Expected: 0 issues.

- [ ] **Step 3: Commit**

```bash
git add front/lib/features/shell/presentation/sidebar.dart
git commit -m "feat(front/shell): exibe logo do tenant na sidebar (fallback BrandMark)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Phase 6 — Verificação visual (Playwright) + fechamento

### Task 6.1: Conferir os temas no layout com Playwright

**Files:**
- Create: `front/tmp-pw/verify-themes.mjs`

- [ ] **Step 1: Subir o stack local** (ver memórias [[run-stack-this-machine]] e [[local-web-serve-and-devtools]]):
  - Backend compilado em porta livre: `PORT=4500 node back/dist/src/main.js` (build antes: `npm run build --workspace back`). Postgres podman 55432 + redis up.
  - Build web do front com dev-tools e a base API: `C:\Users\KaueSobral\develop\flutter\bin\flutter.bat build web --dart-define=API_BASE_URL=http://localhost:4500/api --dart-define=DEV_TOOLS=true` e servir `build/web` em `:8090` (via `tmp-pw/serve.mjs`). Adicionar `http://localhost:8090` ao `CORS_ORIGINS`.

- [ ] **Step 2: Script Playwright** `front/tmp-pw/verify-themes.mjs`: login (conta dev `dono@teste.com`/`senha12345`), navegar para `/configuracoes` → Aparência; para cada preset em [tangerina,vermelho,azul,verde,roxo,petroleo,ambar] × modo [claro,escuro]: selecionar, aguardar re-render, e `page.screenshot` de (a) dashboard, (b) sidebar, (c) a própria tela de config, (d) uma tela com form (ex.: clientes). Salvar em `tmp-pw/shots/<preset>-<modo>-<tela>.png`.

- [ ] **Step 3: Avaliar contraste/legibilidade** abrindo os PNGs (especialmente **âmbar** e **verde** em modo claro — risco de baixo contraste do texto sobre primário; e **modo escuro** de todos). Onde ficar ruim, ajustar a `seed` do preset em `theme_presets.dart` (ex.: escurecer âmbar para melhor contraste de `onPrimary`) e repetir. Critério: texto sobre `primary` legível, foco/realce visível, sidebar grafite mantém contraste. Anotar o resultado (quais ajustes foram feitos) no commit.

- [ ] **Step 4: Commit** (o `tmp-pw/` é ferramenta de verificação; commitar o script e os ajustes de seed, não necessariamente os PNGs):
```bash
git add front/lib/core/theme/theme_presets.dart front/tmp-pw/verify-themes.mjs
git commit -m "test(front/theme): verificação visual dos presets (claro/escuro) via Playwright + ajustes de contraste

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

### Task 6.2: Suíte completa verde + fechamento

- [ ] **Step 1: Backend** — `cd back && npm run lint && npm run test && (podman exec orbix-redis redis-cli FLUSHALL && npm run test:e2e)`. Tudo verde; citar contagem real.
- [ ] **Step 2: Front** — `flutter analyze` (0 issues) + `flutter test` (todos verdes; citar contagem).
- [ ] **Step 3: Atualizar `docs/modulos-v1.md`** se o inventário/seção mudou (config da empresa agora cobre fiscal+tema; nota sobre a fronteira do invoice).
- [ ] **Step 4: Commit final**
```bash
git add -A
git commit -m "docs: atualiza inventário; suíte completa verde (config empresa/fiscal/tema)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (cobertura do pedido do usuário)

| Pedido | Onde |
|---|---|
| Cadastrar **logo** | Task 2.1 (upload back) + 4.2 (UI) + 5.2 (sidebar) |
| Mudar **razão social** | já existe `legalName`; editável na Task 4.2 + sync /me na 1.3 |
| Mudar **telefone / e-mail** | `phone`/`email` (tipos tel/email) — Tasks 1.1/1.2/4.2 |
| **Mais campos** (módulos atuais + NF-e) | Task 1.1 (IE, IM, regime, CNAE, endereço fiscal estruturado, website) + doc da fronteira invoice (2.3) |
| **Temas / cor do sistema** (+4 opções, manter atuais) | 7 presets na Task 3.1 (tangerina mantido + vermelho/azul/verde/roxo/petróleo/âmbar), cada um claro+escuro; seletor na 5.1 |
| Modo **claro/escuro** | `themeControllerProvider` por usuário, exposto no seletor (5.1) |
| **Playwright** para conferir as cores no layout | Task 6.1 |

**Decisões assumidas (corrija na revisão se quiser diferente):**
1. Logo = **upload real** (reusa StorageProvider), não só URL.
2. Campos fiscais ficam **no config da empresa agora** (identidade do tenant); certificado A1/ambiente/série/CSC ficam para o **módulo invoice** (documentado, não construído) — "aponta, não invade".
3. Cor/preset = **por tenant** (em `tenant.settings`); claro/escuro = **por usuário** (SharedPreferences). Cada preset gera claro+escuro via `fromSeed`; a sidebar grafite é constante (o "preto" do "X/preto").
4. **Sem migration** (tudo em `tenant.settings` JSONB). `address` livre vira endereço estruturado (legado preservado no JSONB).
5. `themePreset` é a fonte da verdade do tema; `primaryColor` continua aceito como fallback (compat).
