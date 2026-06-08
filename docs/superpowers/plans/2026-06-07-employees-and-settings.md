# Funcionários & Cargos + Host de Configurações — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Estender o `iam` com gestão de funcionários/cargos (v1, cargos fixos) e criar a tela de Configurações como um HOST incremental (seção núcleo Empresa & Identidade + registry de seções por módulo), sobre a fundação existente do OrbixHub.

**Architecture:** Camadas (Controller fino → Service → Repository). Migration aditiva `0003` reflete nos 3 lugares (baseline SQL canônico + `prisma/migrations` + `schema.prisma`). Cargos são roles globais fixos (decisão: role mínima — sem `is_system`/`tenant_id`). Reautenticação por `currentPassword` no corpo das mutações sensíveis (não existia — será construída). "Último acesso" derivado de `login_attempt`. Settings de empresa em `tenant.settings` (jsonb); o host monta seção núcleo + seções de módulos habilitados via um `SettingsSectionRegistry`.

**Tech Stack:** NestJS 10, Prisma 5 (schema manual + SQL cru), Postgres + RLS, class-validator, Jest + Supertest.

**Decisões travadas:** (1) permissões de "veículos" usam `subject.*` (genérico); (2) `role` mínima — gerente/caixa como roles globais comuns; (3) último acesso vem de `login_attempt`.

---

## Estrutura de arquivos

**DB / schema (3 lugares mantidos juntos):**
- Modify `back/sql/auth-multitenant-schema.sql` — DDL aditivo idempotente (status, settings, permissões, roles) no fim do arquivo + ajuste do seed de `mechanic`.
- Create `back/prisma/migrations/0003_employees_settings/migration.sql` — mesma DDL aditiva.
- Modify `back/prisma/schema.prisma` — `membership.status`, `tenant.settings`.

**iam (estender):**
- Modify `back/src/modules/iam/dto/iam.dto.ts` — `currentPassword` no invite; `ChangeRoleDto`, `ReauthDto`.
- Create `back/src/modules/iam/reauth.service.ts` — `assertReauth(userId, currentPassword)`.
- Create `back/src/modules/iam/employees.service.ts` — listEmployees + mutações + 6 guardrails.
- Create `back/src/modules/iam/employees.controller.ts` — `GET /roles`, `GET /employees`, `PATCH /employees/:id/role`, `POST /employees/:id/(de)activate`.
- Modify `back/src/modules/iam/iam.repository.ts` — queries de employees (status, lastAccess, owners ativos, setRole/setStatus).
- Modify `back/src/modules/iam/iam.service.ts` — invite agora reautentica.
- Modify `back/src/modules/iam/iam.module.ts` — registra novos providers/controller.
- Modify `back/src/common/audit/audit.service.ts` — novas `AuditAction`.

**settings (novo módulo):**
- Create `back/src/modules/settings/settings.section-registry.ts`
- Create `back/src/modules/settings/settings.repository.ts`
- Create `back/src/modules/settings/settings.service.ts`
- Create `back/src/modules/settings/dto/settings.dto.ts`
- Create `back/src/modules/settings/settings.controller.ts`
- Create `back/src/modules/settings/settings.module.ts`
- Modify `back/src/app.module.ts` — importa `SettingsModule`.

**Testes:**
- Create `back/src/modules/iam/employees.service.spec.ts` (guardrails unit)
- Create `back/src/modules/settings/settings.service.spec.ts` (registry + assembly unit)
- Create `back/test/employees.e2e-spec.ts`
- Create `back/test/settings.e2e-spec.ts`
- Modify `back/test/iam.e2e-spec.ts` — passar `currentPassword` no invite.

**Docs:**
- Create-if-missing `docs/modulos-v1.md`
- Create `docs/configuracao.md`

---

## Task 1: Migration 0003 — schema aditivo (status, settings, permissões, cargos)

**Files:**
- Modify: `back/sql/auth-multitenant-schema.sql` (append no fim; idempotente)
- Create: `back/prisma/migrations/0003_employees_settings/migration.sql`
- Modify: `back/prisma/schema.prisma`

- [ ] **Step 1: Escrever a DDL aditiva** (mesma em ambos os .sql). Conteúdo:

```sql
-- ============================================================
-- 0003 — Employees & Settings (aditivo, idempotente)
-- ============================================================

-- membership.status (active|disabled) — nunca apagamos membros, só desativamos
ALTER TABLE membership ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active';
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'membership_status_chk') THEN
    ALTER TABLE membership ADD CONSTRAINT membership_status_chk CHECK (status IN ('active','disabled'));
  END IF;
END $$;

-- tenant.settings (jsonb) — preferências de empresa/branding
ALTER TABLE tenant ADD COLUMN IF NOT EXISTS settings jsonb NOT NULL DEFAULT '{}'::jsonb;

-- Permissões novas (catálogo global). subject.* = objeto de serviço (genérico).
INSERT INTO permission (key, name) VALUES
  ('customer.read','Ver clientes'), ('customer.write','Editar clientes'),
  ('subject.read','Ver objetos'), ('subject.write','Editar objetos'),
  ('os.approve','Aprovar OS'),
  ('tracking.manage','Gerenciar acompanhamento'),
  ('cashier.read','Ver caixa'), ('cashier.write','Operar caixa'),
  ('invoice.issue','Emitir nota'),
  ('finance.read','Ver financeiro'), ('finance.write','Editar financeiro'),
  ('report.read','Ver relatórios'),
  ('settings.manage','Gerenciar configurações')
ON CONFLICT (key) DO NOTHING;

-- Cargos novos (roles globais; decisão "role mínima")
INSERT INTO role (key, name) VALUES
  ('gerente','Gerente'), ('caixa','Caixa / Atendente')
ON CONFLICT (key) DO NOTHING;

-- owner: re-grant garante que ganhe as permissões novas também
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r, permission p WHERE r.key = 'owner'
ON CONFLICT DO NOTHING;

-- gerente: todas, exceto billing.manage
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r, permission p
WHERE r.key = 'gerente' AND p.key <> 'billing.manage'
ON CONFLICT DO NOTHING;

-- mechanic: operacional (inclui as novas customer.*/subject.*/tracking.manage)
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON p.key IN
  ('customer.read','customer.write','subject.read','subject.write',
   'os.read','os.write','inventory.read','tracking.manage')
WHERE r.key = 'mechanic'
ON CONFLICT DO NOTHING;

-- caixa: atendimento + caixa + nota
INSERT INTO role_permission (role_id, permission_id)
SELECT r.id, p.id FROM role r JOIN permission p ON p.key IN
  ('customer.read','customer.write','subject.read','subject.write',
   'os.read','os.write','inventory.read',
   'cashier.read','cashier.write','invoice.issue')
WHERE r.key = 'caixa'
ON CONFLICT DO NOTHING;
```

- [ ] **Step 2: Atualizar `schema.prisma`** — no model `membership` add `status String @default("active")`; no model `tenant` add `settings Json @default("{}")`. (Confira os nomes reais dos models no arquivo e mantenha o estilo.)

- [ ] **Step 3: Aplicar no DB de dev e regenerar client**

```bash
podman exec -i orbix-postgres psql -U app_owner -d orbixhub -v ON_ERROR_STOP=1 < back/prisma/migrations/0003_employees_settings/migration.sql
npm run prisma:generate --workspace back
```
Expected: aplica sem erro; client regenerado com `status`/`settings`.

- [ ] **Step 4: Verificar seeds**

```bash
podman exec orbix-postgres psql -U app_owner -d orbixhub -c "SELECT key FROM role ORDER BY key;" -c "SELECT count(*) FROM permission;" -c "SELECT r.key, count(*) FROM role r JOIN role_permission rp ON rp.role_id=r.id GROUP BY r.key ORDER BY r.key;"
```
Expected: roles incluem caixa/gerente/mechanic/owner; gerente = (total_perms - 1); mechanic = 8; caixa = 10; owner = total.

- [ ] **Step 5: Commit**

```bash
git add back/sql/auth-multitenant-schema.sql back/prisma/migrations/0003_employees_settings/migration.sql back/prisma/schema.prisma
git commit -m "feat(db): 0003 — membership.status, tenant.settings, subject.* perms, gerente/caixa roles"
```

---

## Task 2: AuditAction + ReauthService

**Files:**
- Modify: `back/src/common/audit/audit.service.ts`
- Create: `back/src/modules/iam/reauth.service.ts`
- Test: `back/src/modules/iam/reauth.service.spec.ts`

- [ ] **Step 1: Estender `AuditAction`** — adicionar `'role_change' | 'member_activate' | 'member_deactivate' | 'settings_change'` ao union.

- [ ] **Step 2: Teste falhando do ReauthService**

```ts
// reauth.service.spec.ts
import { UnauthorizedException } from '@nestjs/common';
import { ReauthService } from './reauth.service';

describe('ReauthService', () => {
  const users = { findUnique: jest.fn() } as never;
  const passwords = { verify: jest.fn() } as never;
  const svc = new ReauthService(
    { users } as never, // PrismaService
    passwords,          // PasswordService
  );

  it('passes when the current password matches', async () => {
    (users as any).findUnique.mockResolvedValue({ id: 'u1', password_hash: 'h' });
    (passwords as any).verify.mockResolvedValue(true);
    await expect(svc.assertReauth('u1', 'pw')).resolves.toBeUndefined();
  });
  it('throws 401 when password is wrong', async () => {
    (users as any).findUnique.mockResolvedValue({ id: 'u1', password_hash: 'h' });
    (passwords as any).verify.mockResolvedValue(false);
    await expect(svc.assertReauth('u1', 'bad')).rejects.toBeInstanceOf(UnauthorizedException);
  });
});
```

- [ ] **Step 3: Implementar `ReauthService`**

```ts
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PrismaService } from '../../common/database/prisma.service';
import { PasswordService } from '../../common/crypto/password.service';

@Injectable()
export class ReauthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly passwords: PasswordService,
  ) {}

  /** Re-verify the acting user's CURRENT password before a sensitive mutation. */
  async assertReauth(userId: string, currentPassword: string): Promise<void> {
    const user = await this.prisma.users.findUnique({ where: { id: userId } });
    const ok =
      !!user && (await this.passwords.verify(user.password_hash, currentPassword));
    if (!ok) throw new UnauthorizedException('Senha atual incorreta.');
  }
}
```

- [ ] **Step 4: Rodar o teste** — `npm run back:test -- reauth.service` → PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(iam): ReauthService + audit actions"`

---

## Task 3: DTOs do iam (invite reautenticado + employees)

**Files:** Modify `back/src/modules/iam/dto/iam.dto.ts`

- [ ] **Step 1: Reescrever os DTOs**

```ts
import { IsEmail, IsIn, IsOptional, IsString, MinLength } from 'class-validator';

const ROLE_KEYS = ['owner', 'gerente', 'mechanic', 'caixa'] as const;
export type RoleKeyInput = (typeof ROLE_KEYS)[number];

export class CreateInviteDto {
  @IsEmail() email!: string;
  @IsIn(ROLE_KEYS) role!: RoleKeyInput;
  @IsString() @MinLength(1) currentPassword!: string; // reautenticação
}

export class AcceptInviteDto {
  @IsString() token!: string;
  @IsOptional() @IsString() @MinLength(2) fullName?: string;
  @IsOptional() @IsString() @MinLength(8) password?: string;
}

export class ChangeRoleDto {
  @IsIn(ROLE_KEYS) role!: RoleKeyInput;
  @IsString() @MinLength(1) currentPassword!: string;
}

export class ReauthDto {
  @IsString() @MinLength(1) currentPassword!: string;
}
```

- [ ] **Step 2: Commit** — `git commit -m "feat(iam): role-aware + reauth DTOs"`

---

## Task 4: Repository — employees

**Files:** Modify `back/src/modules/iam/iam.repository.ts`

- [ ] **Step 1: Adicionar tipos + métodos** (usar `tenant.withTenantTx` p/ membership RLS; users/role/login_attempt globais via `this.prisma`):

```ts
export interface EmployeeView {
  membershipId: string;
  userId: string;
  fullName: string | undefined;
  email: string | undefined;
  role: string | undefined;
  status: string;
  lastAccess: Date | null;
}

// dentro de IamRepository:

async listEmployees(): Promise<EmployeeView[]> {
  return this.tenant.withTenantTx(async () => {
    const db = this.tenant.getClient();
    const memberships = await db.membership.findMany();
    const userIds = memberships.map((m) => m.user_id);
    const roleIds = memberships.map((m) => m.role_id);
    const [users, roles, lastLogins] = await Promise.all([
      this.prisma.users.findMany({ where: { id: { in: userIds } } }),
      this.prisma.role.findMany({ where: { id: { in: roleIds } } }),
      this.prisma.login_attempt.groupBy({
        by: ['user_id'],
        where: { success: true, user_id: { in: userIds } },
        _max: { created_at: true },
      }),
    ]);
    const uMap = new Map(users.map((u) => [u.id, u]));
    const rMap = new Map(roles.map((r) => [r.id, r]));
    const lMap = new Map(
      lastLogins.map((l) => [l.user_id, l._max.created_at ?? null]),
    );
    return memberships.map((m) => ({
      membershipId: m.id,
      userId: m.user_id,
      fullName: uMap.get(m.user_id)?.full_name,
      email: uMap.get(m.user_id)?.email_normalized,
      role: rMap.get(m.role_id)?.key,
      status: m.status,
      lastAccess: lMap.get(m.user_id) ?? null,
    }));
  });
}

/** {role_key, user_id, status} de UMA membership do tenant ativo (ou null). */
async getMembership(membershipId: string) {
  return this.tenant.withTenantTx(async () => {
    const db = this.tenant.getClient();
    const m = await db.membership.findUnique({ where: { id: membershipId } });
    if (!m) return null;
    const role = await this.prisma.role.findUnique({ where: { id: m.role_id } });
    return { id: m.id, userId: m.user_id, roleKey: role?.key, status: m.status };
  });
}

/** Quantos donos ATIVOS existem no tenant ativo. */
async countActiveOwners(): Promise<number> {
  const owner = await this.prisma.role.findUnique({ where: { key: 'owner' } });
  if (!owner) return 0;
  return this.tenant.withTenantTx(async () => {
    const db = this.tenant.getClient();
    return db.membership.count({
      where: { role_id: owner.id, status: 'active' },
    });
  });
}

async setRole(membershipId: string, roleKey: string): Promise<void> {
  const role = await this.prisma.role.findUnique({ where: { key: roleKey } });
  if (!role) throw new Error(`unknown role ${roleKey}`);
  await this.tenant.withTenantTx(async () => {
    const db = this.tenant.getClient();
    await db.membership.update({
      where: { id: membershipId },
      data: { role_id: role.id },
    });
  });
}

async setStatus(membershipId: string, status: 'active' | 'disabled'): Promise<void> {
  await this.tenant.withTenantTx(async () => {
    const db = this.tenant.getClient();
    await db.membership.update({ where: { id: membershipId }, data: { status } });
  });
}
```

- [ ] **Step 2: Build** — `npm run build --workspace back` → OK (confirma nomes do client Prisma: `login_attempt`, `membership.status`).
- [ ] **Step 3: Commit** — `git commit -m "feat(iam): employee repository queries"`

---

## Task 5: EmployeesService — guardrails (TDD, um teste por guardrail)

**Files:**
- Create: `back/src/modules/iam/employees.service.ts`
- Test: `back/src/modules/iam/employees.service.spec.ts`

Guardrails (todos no service):
1. Sempre ≥1 dono ativo (bloqueia rebaixar/desativar o último dono ativo).
2. Ninguém altera o próprio cargo.
3. Só `owner` concede/transfere `owner`.
4. Desativar não apaga (só `status='disabled'`).
5. Não desativar a si mesmo.
6. Reautenticação em convite, troca de cargo e ativar/desativar.

- [ ] **Step 1: Testes falhando** — cobrir cada guardrail com mocks de repo+reauth. Exemplos-chave:

```ts
// self-role
await expect(svc.changeRole(actorAsTarget, 'gerente', actor)).rejects.toBeInstanceOf(ForbiddenException);
// só owner cria owner
await expect(svc.changeRole(m2, 'owner', gerenteActor)).rejects.toBeInstanceOf(ForbiddenException);
// último dono
repo.countActiveOwners.mockResolvedValue(1); // target é esse owner
await expect(svc.changeRole(ownerMembership, 'gerente', otherOwner)).rejects.toBeInstanceOf(BadRequestException);
// self-deactivate
await expect(svc.deactivate(actorMembership, actor)).rejects.toBeInstanceOf(ForbiddenException);
// reauth
reauth.assertReauth.mockRejectedValue(new UnauthorizedException());
await expect(svc.changeRole(m2,'gerente',actor)).rejects.toBeInstanceOf(UnauthorizedException);
```

- [ ] **Step 2: Implementar `EmployeesService`**

```ts
import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { IamRepository } from './iam.repository';
import { ReauthService } from './reauth.service';
import { AuditService } from '../../common/audit/audit.service';
import type { AuthUser } from '../../common/auth/auth.types';

@Injectable()
export class EmployeesService {
  constructor(
    private readonly repo: IamRepository,
    private readonly reauth: ReauthService,
    private readonly audit: AuditService,
  ) {}

  listEmployees() {
    return this.repo.listEmployees();
  }

  async changeRole(membershipId: string, newRole: string, actor: AuthUser, currentPassword: string) {
    await this.reauth.assertReauth(actor.userId, currentPassword);     // G6
    const target = await this.repo.getMembership(membershipId);
    if (!target) throw new BadRequestException('Funcionário não encontrado.');
    if (target.userId === actor.userId) throw new ForbiddenException('Não é possível alterar o próprio cargo.'); // G2
    if (newRole === 'owner' && actor.role !== 'owner') throw new ForbiddenException('Apenas o dono concede o cargo de dono.'); // G3
    if (target.roleKey === 'owner' && newRole !== 'owner') {           // G1
      const owners = await this.repo.countActiveOwners();
      if (owners <= 1) throw new BadRequestException('A oficina precisa de pelo menos um dono ativo.');
    }
    await this.repo.setRole(membershipId, newRole);
    await this.audit.log(actor.tenantId, actor.userId, 'role_change', membershipId, { to: newRole });
    return { ok: true };
  }

  async deactivate(membershipId: string, actor: AuthUser, currentPassword: string) {
    await this.reauth.assertReauth(actor.userId, currentPassword);     // G6
    const target = await this.repo.getMembership(membershipId);
    if (!target) throw new BadRequestException('Funcionário não encontrado.');
    if (target.userId === actor.userId) throw new ForbiddenException('Não é possível desativar a si mesmo.'); // G5
    if (target.roleKey === 'owner' && target.status === 'active') {    // G1
      const owners = await this.repo.countActiveOwners();
      if (owners <= 1) throw new BadRequestException('A oficina precisa de pelo menos um dono ativo.');
    }
    await this.repo.setStatus(membershipId, 'disabled');               // G4 (nunca apaga)
    await this.audit.log(actor.tenantId, actor.userId, 'member_deactivate', membershipId);
    return { ok: true };
  }

  async activate(membershipId: string, actor: AuthUser, currentPassword: string) {
    await this.reauth.assertReauth(actor.userId, currentPassword);     // G6
    const target = await this.repo.getMembership(membershipId);
    if (!target) throw new BadRequestException('Funcionário não encontrado.');
    await this.repo.setStatus(membershipId, 'active');
    await this.audit.log(actor.tenantId, actor.userId, 'member_activate', membershipId);
    return { ok: true };
  }
}
```

- [ ] **Step 3: Rodar** — `npm run back:test -- employees.service` → todos PASS.
- [ ] **Step 4: Commit** — `git commit -m "feat(iam): EmployeesService with guardrails"`

---

## Task 6: Controller employees + invite reautenticado + module wiring

**Files:**
- Create: `back/src/modules/iam/employees.controller.ts`
- Modify: `back/src/modules/iam/iam.service.ts` (createInvite reautentica)
- Modify: `back/src/modules/iam/iam.module.ts`

- [ ] **Step 1: `employees.controller.ts`**

```ts
import { Body, Controller, Get, HttpCode, Param, Patch, Post } from '@nestjs/common';
import { Permissions, CurrentUser } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';
import { EmployeesService } from './employees.service';
import { IamService } from './iam.service';
import { ChangeRoleDto, ReauthDto } from './dto/iam.dto';

@Controller()
export class EmployeesController {
  constructor(
    private readonly employees: EmployeesService,
    private readonly iam: IamService,
  ) {}

  @Get('roles')
  roles() {
    return this.iam.listRolesWithPermissions();
  }

  @Get('employees')
  @Permissions('users.manage')
  list() {
    return this.employees.listEmployees();
  }

  @Patch('employees/:membershipId/role')
  @Permissions('users.manage')
  @HttpCode(200)
  changeRole(
    @CurrentUser() user: AuthUser,
    @Param('membershipId') id: string,
    @Body() dto: ChangeRoleDto,
  ) {
    return this.employees.changeRole(id, dto.role, user, dto.currentPassword);
  }

  @Post('employees/:membershipId/deactivate')
  @Permissions('users.manage')
  @HttpCode(200)
  deactivate(
    @CurrentUser() user: AuthUser,
    @Param('membershipId') id: string,
    @Body() dto: ReauthDto,
  ) {
    return this.employees.deactivate(id, user, dto.currentPassword);
  }

  @Post('employees/:membershipId/activate')
  @Permissions('users.manage')
  @HttpCode(200)
  activate(
    @CurrentUser() user: AuthUser,
    @Param('membershipId') id: string,
    @Body() dto: ReauthDto,
  ) {
    return this.employees.activate(id, user, dto.currentPassword);
  }
}
```

- [ ] **Step 2: `IamService`** — add `listRolesWithPermissions()` (roles + chaves de permissão de cada) e fazer `createInvite` reautenticar. Injetar `ReauthService` no construtor; em `createInvite`, primeiro `await this.reauth.assertReauth(invitedBy, dto.currentPassword)`. Adicionar:

```ts
async listRolesWithPermissions() {
  const [roles, rps, perms] = await Promise.all([
    this.repo.listRoles(),
    this.prisma.role_permission.findMany(),
    this.repo.listPermissions(),
  ]);
  const pMap = new Map(perms.map((p) => [p.id, p.key]));
  return roles.map((r) => ({
    key: r.key,
    name: r.name,
    permissions: rps.filter((rp) => rp.role_id === r.id).map((rp) => pMap.get(rp.permission_id)),
  }));
}
```

- [ ] **Step 3: `iam.module.ts`** — adicionar `EmployeesService`, `ReauthService`, `PasswordService` (se não exportado), aos `providers`; `EmployeesController` aos `controllers`. (Confirme se `PasswordService` já vem de um módulo importado; senão importe `CryptoModule`/equivalente.)

- [ ] **Step 4: Build** — `npm run build --workspace back` → OK.
- [ ] **Step 5: Commit** — `git commit -m "feat(iam): employees endpoints + reauthed invite + roles catalog"`

---

## Task 7: Settings — registry + service (TDD unit)

**Files:**
- Create: `back/src/modules/settings/settings.section-registry.ts`
- Create: `back/src/modules/settings/settings.repository.ts`
- Create: `back/src/modules/settings/settings.service.ts`
- Create: `back/src/modules/settings/dto/settings.dto.ts`
- Test: `back/src/modules/settings/settings.service.spec.ts`

- [ ] **Step 1: `settings.section-registry.ts`**

```ts
import { Injectable } from '@nestjs/common';

export type SettingsFieldType = 'text' | 'color' | 'url';
export interface SettingsFieldSchema { key: string; label: string; type: SettingsFieldType; }
export interface SettingsSection {
  key: string;
  title: string;
  moduleKey: string | null; // null = núcleo; senão aparece só se o módulo estiver habilitado
  fields: SettingsFieldSchema[];
}

/**
 * Mecanismo do host incremental: cada módulo REGISTRA a sua seção de config aqui
 * (no boot). O host monta a resposta = seção núcleo + seções registradas cujo
 * moduleKey estiver habilitado em tenant_module. Documentado em docs/configuracao.md.
 */
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

export const COMPANY_SECTION: SettingsSection = {
  key: 'company',
  title: 'Empresa & Identidade visual',
  moduleKey: null,
  fields: [
    { key: 'companyName', label: 'Nome fantasia', type: 'text' },
    { key: 'legalName', label: 'Razão social', type: 'text' },
    { key: 'taxId', label: 'CNPJ / documento', type: 'text' },
    { key: 'address', label: 'Endereço', type: 'text' },
    { key: 'phone', label: 'Telefone / WhatsApp', type: 'text' },
    { key: 'email', label: 'E-mail', type: 'text' },
    { key: 'logoUrl', label: 'Logo (URL)', type: 'url' },
    { key: 'primaryColor', label: 'Cor primária', type: 'color' },
    { key: 'secondaryColor', label: 'Cor secundária', type: 'color' },
  ],
};
```

- [ ] **Step 2: `dto/settings.dto.ts`**

```ts
import { IsEmail, IsOptional, IsString, IsUrl, Matches } from 'class-validator';
const HEX = /^#([0-9a-fA-F]{6})$/;

export class UpdateCompanyDto {
  @IsOptional() @IsString() companyName?: string;
  @IsOptional() @IsString() legalName?: string;
  @IsOptional() @IsString() taxId?: string;
  @IsOptional() @IsString() address?: string;
  @IsOptional() @IsString() phone?: string;
  @IsOptional() @IsEmail() email?: string;
  @IsOptional() @IsUrl() logoUrl?: string;
  @IsOptional() @Matches(HEX, { message: 'primaryColor deve ser hex #RRGGBB' }) primaryColor?: string;
  @IsOptional() @Matches(HEX, { message: 'secondaryColor deve ser hex #RRGGBB' }) secondaryColor?: string;
}
```

- [ ] **Step 3: `settings.repository.ts`**

```ts
import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/database/prisma.service';
import { TenantContext } from '../../common/database/tenant-context';

@Injectable()
export class SettingsRepository {
  constructor(
    private readonly prisma: PrismaService,
    private readonly tenant: TenantContext,
  ) {}

  async getCompany(tenantId: string): Promise<Record<string, unknown>> {
    const t = await this.prisma.tenant.findUnique({ where: { id: tenantId } });
    return (t?.settings as Record<string, unknown>) ?? {};
  }

  async updateCompany(tenantId: string, merged: Record<string, unknown>): Promise<void> {
    await this.prisma.tenant.update({
      where: { id: tenantId },
      data: { settings: merged as Prisma.InputJsonValue },
    });
  }

  /** Chaves de módulo HABILITADAS no tenant ativo (tenant_module é RLS). */
  async enabledModuleKeys(): Promise<string[]> {
    return this.tenant.withTenantTx(async () => {
      const db = this.tenant.getClient();
      const rows = await db.tenant_module.findMany({ where: { enabled: true } });
      const ids = rows.map((r) => r.module_id);
      const mods = await this.prisma.module.findMany({ where: { id: { in: ids } } });
      return mods.map((m) => m.key);
    });
  }
}
```

- [ ] **Step 4: `settings.service.ts`**

```ts
import { Injectable } from '@nestjs/common';
import { SettingsRepository } from './settings.repository';
import { SettingsSectionRegistry, COMPANY_SECTION } from './settings.section-registry';
import { AuditService } from '../../common/audit/audit.service';
import { UpdateCompanyDto } from './dto/settings.dto';
import type { AuthUser } from '../../common/auth/auth.types';

@Injectable()
export class SettingsService {
  constructor(
    private readonly repo: SettingsRepository,
    private readonly registry: SettingsSectionRegistry,
    private readonly audit: AuditService,
  ) {}

  async getSettings(user: AuthUser) {
    const [company, enabled] = await Promise.all([
      this.repo.getCompany(user.tenantId),
      this.repo.enabledModuleKeys(),
    ]);
    const moduleSections = this.registry
      .moduleSections()
      .filter((s) => s.moduleKey && enabled.includes(s.moduleKey));
    return { company, sections: [COMPANY_SECTION, ...moduleSections] };
  }

  async updateCompany(user: AuthUser, dto: UpdateCompanyDto) {
    const current = await this.repo.getCompany(user.tenantId);
    const merged = { ...current, ...JSON.parse(JSON.stringify(dto)) };
    await this.repo.updateCompany(user.tenantId, merged);
    await this.audit.log(user.tenantId, user.userId, 'settings_change', 'company');
    return { company: merged };
  }
}
```

- [ ] **Step 5: Teste unit (`settings.service.spec.ts`)** — registry monta seções; módulo habilitado aparece, desabilitado some:

```ts
it('inclui apenas a seção núcleo quando nenhum módulo registrado', async () => {
  registry.moduleSections = () => [];
  repo.enabledModuleKeys = async () => ['os'];
  const r = await svc.getSettings(user);
  expect(r.sections.map((s) => s.key)).toEqual(['company']);
});
it('inclui a seção do módulo só quando habilitado', async () => {
  registry.moduleSections = () => [{ key: 'os-cfg', title: 'OS', moduleKey: 'os', fields: [] }];
  repo.enabledModuleKeys = async () => ['os'];
  expect((await svc.getSettings(user)).sections.map((s) => s.key)).toContain('os-cfg');
  repo.enabledModuleKeys = async () => ['customers'];
  expect((await svc.getSettings(user)).sections.map((s) => s.key)).not.toContain('os-cfg');
});
```

- [ ] **Step 6: Rodar** — `npm run back:test -- settings.service` → PASS.
- [ ] **Step 7: Commit** — `git commit -m "feat(settings): section registry + service (incremental host)"`

---

## Task 8: Settings controller + module + app wiring

**Files:**
- Create: `back/src/modules/settings/settings.controller.ts`
- Create: `back/src/modules/settings/settings.module.ts`
- Modify: `back/src/app.module.ts`

- [ ] **Step 1: `settings.controller.ts`**

```ts
import { Body, Controller, Get, HttpCode, Patch } from '@nestjs/common';
import { Permissions, CurrentUser } from '../../common/auth/decorators';
import type { AuthUser } from '../../common/auth/auth.types';
import { SettingsService } from './settings.service';
import { UpdateCompanyDto } from './dto/settings.dto';

@Controller('settings')
export class SettingsController {
  constructor(private readonly settings: SettingsService) {}

  @Get()
  get(@CurrentUser() user: AuthUser) {
    return this.settings.getSettings(user); // leitura: qualquer membro autenticado
  }

  @Patch('company')
  @Permissions('settings.manage')
  @HttpCode(200)
  updateCompany(@CurrentUser() user: AuthUser, @Body() dto: UpdateCompanyDto) {
    return this.settings.updateCompany(user, dto);
  }
}
```

- [ ] **Step 2: `settings.module.ts`** — providers: `SettingsService`, `SettingsRepository`, `SettingsSectionRegistry`; controllers: `SettingsController`; exporta `SettingsSectionRegistry` (p/ módulos registrarem suas seções). `PrismaService`/`TenantContext`/`AuditService` vêm dos módulos globais (confirme se `AuditModule` é `@Global`; é).

- [ ] **Step 3: `app.module.ts`** — importar `SettingsModule`.
- [ ] **Step 4: Build** — `npm run build --workspace back` → OK.
- [ ] **Step 5: Commit** — `git commit -m "feat(settings): GET /settings + PATCH /settings/company"`

---

## Task 9: e2e — employees

**Files:** Create `back/test/employees.e2e-spec.ts`; Modify `back/test/iam.e2e-spec.ts`

- [ ] **Step 1: Atualizar `iam.e2e-spec.ts`** — todas as chamadas a `POST /api/tenants/invites` passam `currentPassword: 'supersecret1'` (a senha do owner registrado). Rodar e ver PASS.

- [ ] **Step 2: `employees.e2e-spec.ts`** (harness igual ao iam.e2e — CapturingMailer, registrar owner, etc.). Casos:
  - **Seeds/roles**: `GET /api/roles` inclui `gerente` e `caixa` com as permissões corretas (gerente sem `billing.manage`; caixa com `cashier.*`/`invoice.issue`); `mechanic` tem `tracking.manage` e `subject.*`. (Critério 1)
  - **Permissão**: um membro `mechanic` chamando `GET /api/employees` → 403; sem `currentPassword` → 400; com senha errada → 401. (Critério 2)
  - **Guardrails** (Critério 3): convidar+aceitar um 2º membro, depois:
    - rebaixar o último dono → 400;
    - owner tenta mudar o próprio cargo → 403;
    - gerente tenta promover alguém a `owner` → 403;
    - `POST /employees/:id/deactivate` em si mesmo → 403;
    - desativar um membro comum → 200 e ele some de "ativos" mas continua em `GET /employees` com `status:'disabled'` (sem hard delete).
  - **Isolamento** (Critério 7): owner do tenant B não enxerga/edita membros de A (membership de A não aparece; mutação com id de A → erro).

- [ ] **Step 3: Rodar e2e** — `podman exec orbix-redis redis-cli FLUSHALL` então `npm run back:test:e2e -- employees` (com env local 55432 — ver README §6). PASS.
- [ ] **Step 4: Commit** — `git commit -m "test(iam): employees e2e (roles, perms, guardrails, isolation)"`

---

## Task 10: e2e — settings

**Files:** Create `back/test/settings.e2e-spec.ts`

- [ ] **Step 1: Casos** (registra owner → trial habilita os+customers):
  - **Núcleo só** (Critério 4): com nenhuma seção de módulo registrada, `GET /api/settings` → `sections` = `[{key:'company',...}]`.
  - **PATCH** (Critério 5): `PATCH /api/settings/company` como owner com `{companyName, primaryColor:'#1E5BFF'}` → 200 e persiste (novo `GET` reflete); `primaryColor:'xyz'` → 400; um `mechanic` (sem `settings.manage`) → 403.
  - **Registry incremental** (Critério 6): pegar `app.get(SettingsSectionRegistry)` e `register({key:'os-cfg', title:'Config OS', moduleKey:'os', fields:[]})`. `GET /settings` (trial, os habilitado) → inclui `os-cfg`. Desabilitar `os` em `tenant_module` (via `tenantCtx.runWithTenant` + update). `GET /settings` → NÃO inclui `os-cfg`.
  - **Isolamento** (Critério 7): settings de B não vazam pra A.

```ts
// desabilitar módulo os do tenant ativo, dentro do contexto do tenant:
await tenantCtx.runWithTenant(tenantId, async () => {
  const db = tenantCtx.getClient() as TxClient;
  await db.$executeRaw`UPDATE tenant_module SET enabled=false
    WHERE module_id=(SELECT id FROM module WHERE key='os')`;
});
```

- [ ] **Step 2: Rodar** — FLUSHALL + `npm run back:test:e2e -- settings` → PASS.
- [ ] **Step 3: Commit** — `git commit -m "test(settings): host e2e (core-only, patch, registry, isolation)"`

---

## Task 11: Docs

**Files:** Create-if-missing `docs/modulos-v1.md`; Create `docs/configuracao.md`

- [ ] **Step 1:** Se `docs/modulos-v1.md` NÃO existir, criar com a tabela-mestre dos módulos v1 (os, customers, inventory, + os planejados: tracking, cashier, invoice, finance, report) — núcleo (sempre) vs contratável. Se existir, **não alterar**.
- [ ] **Step 2:** Criar `docs/configuracao.md` com o princípio do host incremental + contrato de registro de seções + a seção núcleo "Empresa & Identidade visual" (tabela de settings), seguindo o exemplo do spec, com o marcador `<!-- Próximos módulos: registrem e documentem a subseção aqui. -->`.
- [ ] **Step 3: Commit** — `git commit -m "docs: configuracao.md (host incremental) + modulos-v1.md"`

---

## Task 12: Gate final

- [ ] **Step 1:** Reaplicar o baseline canônico num DB limpo p/ provar idempotência:
  `podman exec -i orbix-postgres psql -U app_owner -d orbixhub -v ON_ERROR_STOP=1 < back/sql/auth-multitenant-schema.sql` (sem erro).
- [ ] **Step 2:** `npm run back:lint` → 0 warnings; `npm run build --workspace back` → OK.
- [ ] **Step 3:** `npm run back:test` (unit) → verde.
- [ ] **Step 4:** FLUSHALL + `npm run back:test:e2e` (suíte completa) → verde.
- [ ] **Step 5: Commit** final se necessário.

---

## Critérios de aceite → Tasks

1. gerente/caixa semeados + mechanic conferido → **T1, T9**
2. gestão exige `users.manage` (403) + reautenticação → **T2,T3,T6,T9**
3. guardrails (cada um) → **T5 (unit), T9 (e2e)**
4. `GET /settings` núcleo + módulos habilitados → **T7,T8,T10**
5. `PATCH /settings/company` perm + hex + persiste → **T7,T8,T10**
6. módulo de teste registra seção (aparece/some) → **T7,T10**
7. isolamento A↔B (membros e settings) → **T9,T10**
8. `docs/modulos-v1.md` garantido + `docs/configuracao.md` → **T11**
9. suíte verde + lint limpo → **T12**
