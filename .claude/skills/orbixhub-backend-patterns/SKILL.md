---
name: orbixhub-backend-patterns
description: Use when writing or reviewing any OrbixHub backend code (back/**) — NestJS modules, controllers, services, repositories, DTOs, transactions, env config, error handling. Encodes the layering rules, DTO validation, I/O-ordering, and code-style conventions.
---

# OrbixHub — Padrões do Backend (NestJS)

## Camadas

- **Controller** (fino): recebe DTO validado e delega ao service. Sem regra de negócio.
- **Service**: orquestra regra de negócio, transações e ordem de I/O.
- **Repository**: isola acesso a dados; em tabelas com RLS usa `tenant.getClient()`.

Monolito modular, "DDD-lite": sem CQRS, sem event sourcing, sem aggregates.

## Controllers

- Prefixo global `/api` (em `main.ts`). Não repita `api/` nas rotas.
- Rotas **públicas**: `@Public()`. Sem o decorator, o token é obrigatório.
- Permissões: `@Permissions('users.manage')` — checado pelo `PermissionsGuard` via
  `role`/`role_permission`/`permission` (tabelas globais).
- `@HttpCode(...)` explícito quando o default não bate (ex.: `204` em logout/delete).
- Throttle estrito em endpoints sensíveis: `@UseGuards(AuthThrottlerGuard)` + `@Throttle(...)`.
- Pegue o usuário com `@CurrentUser() user: AuthUser` (nunca leia tenant do body).
- Módulos contratáveis: `@UseGuards(ModuleAccessGuard)` + `@RequiresModule('chave')`.

## DTOs

- `class-validator` + `class-transformer`. `ValidationPipe` global usa
  `whitelist: true, forbidNonWhitelisted: true, transform: true`.
- Campos não declarados no DTO são **rejeitados** (não só removidos).

## Transações & ordem de I/O

- I/O externo (e-mail, gateway de pagamento/fiscal) acontece **fora** da tx e **após** o commit.
  Falha de e-mail nunca faz rollback de cadastro. **Nenhuma chamada externa dentro de tx de banco.**
- `audit.log()` abre **tx própria** → chame por último, fora de qualquer tx aberta.
- Erros do Prisma: `P2002` = unique violation → mapeie para `ConflictException` com mensagem
  genérica (não revele qual campo colidiu, quando for sensível).
- Erros no formato padrão `{ statusCode, error, message }` (filtro em `common/filters`).

## Configuração & env

- Toda env nova é validada em `src/common/config/env.schema.ts` (Zod) e exposta via provider `ENV`.
  Injete com `@Inject(ENV) env: Env` — não leia `process.env` direto nos services.
- Atenção: `z.coerce.boolean()` trata `"false"` como `true`. Para flags booleanas use
  `.transform((s) => s.toLowerCase() === 'true')` (ver `BILLING_REQUIRE_PAYMENT`).

## Estilo & qualidade

- Mensagens ao usuário final em **português**; comentários técnicos podem ser em inglês.
- **Sem ternário aninhado** (o eslint reprova) — extraia para função/statement.
- `eslint --max-warnings 0`: zero warnings. Rode `npm run lint --workspace back` antes de "pronto".
- Antes de usar tipos novos do Prisma, rode `npm run prisma:generate --workspace back`.
- Sem hard delete (status/`canceled_at`/`deleted_at`). Mutações sensíveis: `@Permissions` + auditar.
