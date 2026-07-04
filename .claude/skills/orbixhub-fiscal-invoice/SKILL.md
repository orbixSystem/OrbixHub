---
name: orbixhub-fiscal-invoice
description: Use when building or changing anything about Nota Fiscal / fiscal emission in OrbixHub (módulo `invoice`) — issuing NF from an OS, the abstract fiscal gateway, the fiscal webhook, invoice tables/RLS, permissions, or the fiscal config boundary. Encodes the DECIDED fiscal strategy (NFS-e via API gov.br, free), the implemented backend foundation, and how it obeys the "aponta, não invade" law.
---

# OrbixHub — Módulo Fiscal / Nota Fiscal (`invoice`)

> **Estado (implementado — backend, 2026-07-04):** fundação do módulo `invoice` pronta,
> compilando (`nest build` ok) e com lint 0 warnings. Emite NF a partir da OS, **online-only**,
> via **gateway fiscal abstrato**. Falta aplicar o schema no DB local, endpoints de config
> sensível, testes e2e e a feature no front (front bloqueado por `flutter pub get`).

## Decisões do dono (DECIDIDAS — não reabrir sem pedir)

- **Documento MVP = NFS-e** (nota de **serviço** — mão de obra da oficina). NFC-e/NF-e de
  **produto** ficam para depois. **Mas o design é agnóstico ao tipo de documento** (`document_type`
  ∈ `nfse|nfce|nfe`) e a oficina **tem serviços E pode ter produtos** — por isso a nota faz
  snapshot das linhas das duas naturezas e separa `service_amount` / `product_amount`.
- **Gateway = API NFS-e Nacional (gov.br) — GRATUITA** (sem mensalidade/custo por nota; produção
  liberada out/2025; fluxo DPS → NFS-e → Eventos/DFe, REST). Impl real futura = `GovBrNfseGateway`.
  Em dev, `NoopFiscalGateway`. Trocar por gateway pago é só outra impl do mesmo contrato.
- **Ressalvas do gov.br:** exige **certificado A1** do lojista (custo dele, ~R$120/ano) e que o
  **município tenha aderido ao ADN** (Ambiente de Dados Nacional). Usar o **leiaute novo/atual**
  (a API antiga será descontinuada).
- **Online-only.** Emissão de NF **NÃO** funciona offline (depende de rede/API) — fica desabilitada
  com aviso "Requer conexão" quando offline. Web é online-only de qualquer forma.
- **SG Master** (concorrente) usa um **emissor fiscal proprietário in-house** — não é um modelo
  copiável; reforça a escolha da API gov.br gratuita.

## Regra-mãe: "aponta, não invade" (como o invoice se relaciona)

O módulo `invoice` **é dono do próprio registro** e **aponta** para OS e cliente por **id**:
- Guarda `order_id` (uuid **escalar**, SEM relation/FK Prisma para `service_order`) + snapshot
  (`order_number`, `customer_id`, `customer_name`, `customer_document`) e as **linhas** da nota.
- Lê a OS via `OsService.getOrderWithItems(id)` → `{ order, items }` (**service público**, criado
  como seam) e o documento do cliente via `CustomersService.getCustomer(user, id)`.
- **NUNCA** lê/escreve `service_order*` nem `customer` diretamente.
- No banco, `invoice.order_id` tem `REFERENCES tenant(id)`? Não — só `tenant_id` referencia tenant.
  `order_id` é ponteiro puro (uuid), preservando o desacoplamento.

## Arquitetura implementada (`back/src/modules/invoice/`)

| Arquivo | Papel |
|---|---|
| `fiscal/fiscal-gateway.ts` | Contrato agnóstico. `FISCAL_GATEWAY` (Symbol) + tipos `FiscalDocumentType`, `FiscalEnvironment`, `FiscalLineKind`, `FiscalIssueLine`, `FiscalIssueParams`, `FiscalIssueResult`, `FiscalCancelParams/Result` + interface `FiscalGateway { issue(); cancel(); verifySignature() }`. Mesmo padrão do `PaymentGateway`. |
| `fiscal/noop-fiscal-gateway.ts` | Impl dev. `issue()` retorna síncrono `authorized` com número/série/`accessKey` fake. `cancel()` → `canceled`. `verifySignature()` = HMAC-SHA256 com `INVOICE_WEBHOOK_SECRET` + `timingSafeEqual`. `static sign()` compartilhado. |
| `dto/invoice.dto.ts` | `IssueInvoiceDto {orderId:@IsUUID, documentType?:@IsEnum opt}`, `ListInvoicesQueryDto {page?,status?,orderId?}`, `CancelInvoiceDto {reason:@IsString @MinLength(3) @MaxLength(255)}`. |
| `invoice.repository.ts` | Único que toca o banco. Tabelas de tenant via `TenantContext.getClient()`; `invoice_webhook_event` (global) via `PrismaService`. `resolveByExternalId` via `$queryRaw` da função `SECURITY DEFINER`. Métodos: `createWithLines`, `findById`, `findByIdWithLines`, `listLines`, `listEvents`, `countAuthorizedByOrder`, `listInvoices`, `updateInvoice`, `createEvent`, `insertWebhookEvent`, `markWebhookProcessed`, `findWebhookEventByExternalId`, `resolveByExternalId`. |
| `invoice.service.ts` | Regra de negócio. `issue`/`list`/`getOne`/`cancel`/`processWebhook`. |
| `invoice.controller.ts` | Gated: `@Controller('invoices')` + `@UseGuards(ModuleAccessGuard)` + `@RequiresModule('invoice')`. `GET /` + `GET /:id` (`@Permissions('invoice.read')`), `POST /` + `POST /:id/cancel` (`@Permissions('invoice.issue')`). |
| `invoice-webhook.controller.ts` | Público (classe separada, SEM `@RequiresModule`). `@Public() @Post('webhook') @HttpCode(200)` lê `req.rawBody` + `@Headers('x-webhook-signature')`. |
| `invoice.config.ts` | `INVOICE_CONFIG_KEY = 'invoice'`. |
| `invoice.module.ts` | `imports: [BillingModule, OsModule, CustomersModule, SettingsModule]`, provê `{ provide: FISCAL_GATEWAY, useClass: NoopFiscalGateway }`, `implements OnModuleInit` → registra seção de config (`SettingsSectionRegistry.register({ key:'invoice', title:'Nota Fiscal', moduleKey:'invoice', fields:[] })`). |

Wired em `back/src/app.module.ts` (após `OsModule`, antes de `ReportModule`).

## Fluxo de emissão (`InvoiceService.issue`) — a lógica

1. `os.getOrderWithItems(dto.orderId)` → bloqueia se OS `cancelada` (`BadRequest`) ou sem itens.
2. `countAuthorizedByOrder(orderId) > 0` → `ConflictException` (uma OS não tem 2 notas ativas;
   ativa = status `draft`/`processing`/`authorized`).
3. **Snapshot** das linhas: cada item vira `invoice_line { kind: product|service, name, quantity,
   unit_price, total }`. Calcula `service_amount`, `product_amount`, `total_amount` (round2).
4. Busca `customer_document` via `customers.getCustomer` (try/catch → null se não achar).
5. **Tx curta:** cria o rascunho (`createWithLines`) + evento `created`.
6. **FORA de tx:** `gateway.issue(...)`. Falha → tx curta marca `status:'error'` + evento `error`
   + `ServiceUnavailableException`.
7. **Tx curta:** persiste resultado (`status`, `external_id`, `number`, `series`, `access_key`,
   `pdf_url`, `xml_url`, `rejection_reason`, `authorized_at`) + evento (`authorized`/`sent`/`rejected`).
8. `audit.log(tenantId, userId, 'invoice_issue', invoiceId, {...})` **por último**.

**Cancelamento (`cancel`):** exige `status === 'authorized'`; chama `gateway.cancel` FORA de tx;
atualiza (`status:'canceled'` + `canceled_at`) + evento + `audit.log('invoice_cancel')`.
**Sem hard delete** — cancelar é só mudar status.

## Webhook fiscal (`processWebhook`) — idempotente, tenant resolvido no servidor

Espelha exatamente `billing.service.ts`:
1. `gateway.verifySignature(rawBody, signature)` → falso ⇒ `BadRequestException`.
2. Parse do corpo. `insertWebhookEvent(id, type, payload)`; `P2002` ⇒ já visto → reprocessa só se
   `processed_at` nulo, senão no-op.
3. `WEBHOOK_STATUS[type]` (`invoice.authorized|rejected|canceled` → status interno) + `externalId`.
4. `repo.resolveByExternalId(externalId)` (função `SECURITY DEFINER` → `{tenantId, invoiceId}`) —
   **NUNCA** confia em tenant vindo do payload.
5. `runWithTenant(tenantId, ...)`: `updateInvoice` + `createEvent`.
6. `audit.log('invoice_webhook')` + `markWebhookProcessed`.

## Banco — migration 0025_invoice (aditiva nos 3 lugares)

Nos 3 lugares mantidos juntos: `sql/auth-multitenant-schema.sql` (canônico/idempotente) +
`prisma/migrations/0025_invoice/migration.sql` + `prisma/schema.prisma` (à mão).

**Tabelas de tenant (RLS + FORCE + policy `tenant_isolation` = `tenant_id = current_tenant_id()`, GRANT app_user):**
- `invoice` (header): `id`, `tenant_id`→tenant CASCADE, `document_type` (def `nfse`, CHECK nfse|nfce|nfe),
  `status` (def `draft`, CHECK draft|processing|authorized|rejected|canceled|error), `environment`
  (def `homologacao`, CHECK homologacao|producao), `order_id` (uuid ponteiro, nullable), `order_number`,
  `customer_id`, `customer_name`, `customer_document`, `series`, `number`, `access_key`,
  `service_amount`/`product_amount`/`total_amount` (numeric 14,2), `external_id`, `pdf_url`, `xml_url`,
  `rejection_reason`, `issued_by`, `canceled_at`, `authorized_at`, `created_at`, `updated_at`.
  Índices: (tenant_id,status), (tenant_id,order_id), (tenant_id,created_at), UNIQUE external_id WHERE NOT NULL.
- `invoice_line`: `id`, `tenant_id`, `invoice_id`→invoice CASCADE, `kind` (CHECK product|service),
  `name`, `quantity` (14,3), `unit_price` (14,2), `total` (14,2), `created_at`. Índice (tenant_id,invoice_id).
- `invoice_event`: `id`, `tenant_id`, `invoice_id`→invoice, `kind`, `message`, `status_snapshot`,
  `created_at`. Índice (tenant_id,invoice_id).

**Global (sem RLS):**
- `invoice_webhook_event`: `id`, `external_event_id` (UNIQUE), `type`, `payload` jsonb, `received_at`,
  `processed_at`. GRANT SELECT/INSERT/UPDATE a app_user.

**Função:** `invoice_resolve_by_external_id(text)` `SECURITY DEFINER` → `(tenant_id, invoice_id)`.

**Seeds:** permission `invoice.read`; role_permission — `invoice.read` → owner/gerente/caixa/mechanic,
`invoice.issue` → owner/gerente/caixa (já semeada no baseline); `module` `invoice` (`is_core=false`);
`plan_module` `invoice` → `trial` + `pro`; backfill `tenant_module` (enable p/ todos os tenants, source `plan`).

**Prisma:** models `invoice` (com `lines invoice_line[]` + `events invoice_event[]`, **sem** relation
`tenant` — só `tenant_id` escalar), `invoice_line`, `invoice_event`, `invoice_webhook_event` (global).

## Env (validado por Zod em `common/config/env.schema.ts`)

- `FISCAL_PROVIDER` (enum `noop|govbr`, default `noop`).
- `FISCAL_ENVIRONMENT` (enum `homologacao|producao`, default `homologacao`).
- `INVOICE_WEBHOOK_SECRET` (string min 16, default de dev — trocar em prod).

`AuditAction` estendida com: `invoice_issue`, `invoice_authorized`, `invoice_rejected`,
`invoice_cancel`, `invoice_webhook`.

## Fronteira de config (documentada em `docs/configuracao.md`)

- **Núcleo (`tenant.settings`, via `PATCH /settings/company`):** identidade fiscal — `taxId` (CNPJ),
  `legalName`, `inscricaoEstadual`, `inscricaoMunicipal`, `regimeTributario`, `cnae`, endereço (`cep`→`uf`).
- **Módulo (`tenant_module.settings['invoice']`, endpoints próprios — a fazer):** dados sensíveis —
  certificado A1 (.pfx, criptografado), ambiente, série/numeração, CSC/token. O módulo **aponta** para
  `tenant.settings` (lê CNPJ/IE/endereço), **não invade** a tabela de settings do núcleo.

## PENDENTE (próximos passos)

1. Aplicar schema no DB local: `ADMIN_DATABASE_URL=... npx ts-node scripts/ci-db-setup.ts` (app_owner).
2. Endpoints de config sensível do módulo (certificado A1, série, ambiente, CSC).
3. Testes e2e: isolamento de tenant, autorização por cargo, idempotência de webhook, guardrails
   (OS cancelada, sem itens, nota duplicada).
4. `GovBrNfseGateway` real (quando for para produção) — nova impl do contrato.
5. Front: feature `invoice` + botão "emitir nota" na tela da OS (bloqueado por `flutter pub get`).

> Ao mexer aqui, siga também a skill `orbixhub-arquitetura` (regras de ouro) e
> `orbixhub-billing` (padrão de gateway + webhook idempotente que o invoice espelha).
