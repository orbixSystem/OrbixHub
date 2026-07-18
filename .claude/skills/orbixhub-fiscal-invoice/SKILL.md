---
name: orbixhub-fiscal-invoice
description: Use when building or changing anything about Nota Fiscal / fiscal emission in OrbixHub (módulo `invoice`) — issuing NF from an OS, the abstract fiscal gateway, the fiscal webhook, invoice tables/RLS, permissions, or the fiscal config boundary. Encodes the DECIDED fiscal strategy (NFS-e via API gov.br, free), the implemented backend foundation, and how it obeys the "aponta, não invade" law.
---

# OrbixHub — Módulo Fiscal / Nota Fiscal (`invoice`)

> **Estado (2026-07-17 — FULL-STACK):** módulo `invoice` implementado no backend E no front.
> Emite NF a partir de uma **OS ou de uma venda** (migration `0030_invoice_sale_source`), **online-only**,
> via **gateway fiscal abstrato**. Feature Flutter completa (lista `/m/invoice` + detalhe `/m/invoice/:id`
> + emissão a partir da OS e da venda + Abrir PDF/XML + cancelar). **Ainda falta:** `GovBrNfseGateway`
> real, endpoints de config sensível (cert A1/CSC/série — hoje `fields:[]`), testes e2e, e o estado
> desabilitado "Requer conexão" offline (camada offline ainda não construída).

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

O módulo `invoice` **é dono do próprio registro** e **aponta** para OS/venda e cliente por **id**:
- Guarda `order_id` **ou** `sale_id` (uuid **escalar**, SEM relation/FK Prisma para `service_order`/`sale`)
  + snapshot (`order_number`, `customer_id`, `customer_name`, `customer_document`) e as **linhas** da nota.
- Lê a OS via `OsService.getOrderWithItems(id)` → `{ order, items }`, a venda via `SalesService.getOne(id)`
  (ambos **services públicos** = seams) e o documento do cliente via `CustomersService.getCustomer(user, id)`.
- **NUNCA** lê/escreve `service_order*`, `sale*` nem `customer` diretamente. OS/Sales **não** importam invoice de volta.
- No banco só `tenant_id` referencia tenant; `order_id`/`sale_id` são ponteiros puros (uuid), preservando o desacoplamento.

## Arquitetura implementada (`back/src/modules/invoice/`)

| Arquivo | Papel |
|---|---|
| `fiscal/fiscal-gateway.ts` | Contrato agnóstico. `FISCAL_GATEWAY` (Symbol) + tipos `FiscalDocumentType`, `FiscalEnvironment`, `FiscalLineKind`, `FiscalIssueLine`, `FiscalIssueParams`, `FiscalIssueResult`, `FiscalCancelParams/Result` + interface `FiscalGateway { issue(); cancel(); verifySignature() }`. Mesmo padrão do `PaymentGateway`. |
| `fiscal/noop-fiscal-gateway.ts` | Impl dev. `issue()` retorna síncrono `authorized` com número/série/`accessKey` fake. `cancel()` → `canceled`. `verifySignature()` = HMAC-SHA256 com `INVOICE_WEBHOOK_SECRET` + `timingSafeEqual`. `static sign()` compartilhado. |
| `dto/invoice.dto.ts` | `IssueInvoiceDto {orderId?:@IsUUID, saleId?:@IsUUID, documentType?:@IsEnum opt}` (XOR: informe OS **ou** venda, só uma), `ListInvoicesQueryDto {page?,status?,orderId?,saleId?}`, `CancelInvoiceDto {reason:@IsString @MinLength(3) @MaxLength(255)}`. |
| `invoice.repository.ts` | Único que toca o banco. Tabelas de tenant via `TenantContext.getClient()`; `invoice_webhook_event` (global) via `PrismaService`. `resolveByExternalId` via `$queryRaw` da função `SECURITY DEFINER`. Métodos incluem `createWithLines`, `findByIdWithLines`, `listLines`, `listEvents`, `countAuthorizedByOrder`, `countAuthorizedBySale`, `listInvoices` (filtra por orderId/saleId), `updateInvoice`, `createEvent`, `insertWebhookEvent`, `markWebhookProcessed`, `resolveByExternalId`. |
| `invoice.service.ts` | Regra de negócio. `issue`/`list`/`getOne`/`cancel`/`processWebhook`. |
| `invoice.controller.ts` | Gated: `@Controller('invoices')` + `@UseGuards(ModuleAccessGuard)` + `@RequiresModule('invoice')`. `GET /` + `GET /:id` (`@Permissions('invoice.read')`), `POST /` + `POST /:id/cancel` (`@Permissions('invoice.issue')`). |
| `invoice-webhook.controller.ts` | Público (classe separada, SEM `@RequiresModule`). `@Public() @Post('webhook') @HttpCode(200)` lê `req.rawBody` + `@Headers('x-webhook-signature')`. |
| `invoice.config.ts` | `INVOICE_CONFIG_KEY = 'invoice'`. |
| `invoice.module.ts` | `imports: [BillingModule, OsModule, SalesModule, CustomersModule, SettingsModule]`, provê `{ provide: FISCAL_GATEWAY, useClass: NoopFiscalGateway }`, `implements OnModuleInit` → registra seção de config (`SettingsSectionRegistry.register({ key:'invoice', title:'Nota Fiscal', moduleKey:'invoice', fields:[] })`). |

Wired em `back/src/app.module.ts` (após `OsModule`, antes de `SalesModule`).

## Fluxo de emissão (`InvoiceService.issue` + `resolveSource`) — a lógica

0. `documentType = dto.documentType ?? 'nfse'`. **XOR**: `(orderId==null) === (saleId==null)` →
   `BadRequestException('Informe uma OS ou uma venda (apenas uma).')`. `resolveSource(dto)` normaliza as
   duas origens num shape comum `{orderId, saleId, number, customerId, customerName, label, lines[]}`:
   - **OS:** `os.getOrderWithItems(orderId)` → bloqueia se `cancelada` (`BadRequest`) ou sem itens;
     `countAuthorizedByOrder>0` → `Conflict`. `label='OS '+number`.
   - **Venda:** `sales.getOne(saleId)` → bloqueia se `cancelada` ou sem itens; `countAuthorizedBySale>0`
     → `Conflict`. `customerName = sale.customer_name ?? 'Consumidor final'`. `label='venda '+number`.
2. **Snapshot** das linhas: cada item vira `invoice_line { kind: product|service, name, quantity,
   unit_price, total }`. Calcula `service_amount`, `product_amount`, `total_amount` (round2).
3. Busca `customer_document` via `customers.getCustomer` (try/catch → null; só se houver `customerId`).
4. **Tx curta:** cria o rascunho (`createWithLines`) + evento `created`.
5. **FORA de tx:** `gateway.issue(...)`. Falha → tx curta marca `status:'error'` + evento `error`
   + `ServiceUnavailableException`.
6. **Tx curta:** persiste resultado (`status`, `external_id`, `number`, `series`, `access_key`,
   `pdf_url`, `xml_url`, `rejection_reason`, `authorized_at`) + evento (`authorized`/`sent`/`rejected`).
7. `audit.log(tenantId, userId, 'invoice_issue', invoiceId, {orderId, saleId, documentType, status})` **por último**.

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

## Banco — migrations 0025_invoice + 0030_invoice_sale_source (aditivas nos 3 lugares)

Nos 3 lugares mantidos juntos: `sql/auth-multitenant-schema.sql` (canônico/idempotente) +
`prisma/migrations/0025_invoice/migration.sql` + `prisma/migrations/0030_invoice_sale_source/migration.sql`
+ `prisma/schema.prisma` (à mão). A `0030` adicionou `invoice.sale_id` (uuid ponteiro, nullable) +
índice `idx_invoice_tenant_sale (tenant_id,sale_id) WHERE sale_id IS NOT NULL`.

**Tabelas de tenant (RLS + FORCE + policy `tenant_isolation` = `tenant_id = current_tenant_id()`, GRANT app_user):**
- `invoice` (header): `id`, `tenant_id`→tenant CASCADE, `document_type` (def `nfse`, CHECK nfse|nfce|nfe),
  `status` (def `draft`, CHECK draft|processing|authorized|rejected|canceled|error), `environment`
  (def `homologacao`, CHECK homologacao|producao), `order_id` (uuid ponteiro, nullable),
  `sale_id` (uuid ponteiro, nullable — origem venda), `order_number`,
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

**Seeds:** permissions `invoice.read` (0025) + `invoice.issue` (baseline); role_permission — `invoice.read`
→ owner/gerente/caixa/mechanic, `invoice.issue` → owner/gerente/caixa (**mechanic NÃO emite**); `module`
`invoice` (`is_core=false`); `plan_module` `invoice` → `trial` + `pro`; backfill `tenant_module`
(enable p/ todos os tenants, source `plan`).

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

## Front (`front/lib/features/invoice/`) — IMPLEMENTADO

Feature-first (domain/data/presentation), repo dio real + fake, registrado em `di.dart`
(`invoiceRepositoryProvider`). Rotas (gated por `me.hasModule('invoice')`): `/m/invoice` (`InvoiceScreen`
lista — chips de filtro de status, desktop `NeuListTile`+`NeuPageControls` / mobile cards+infinite-scroll)
e `/m/invoice/:id` (`InvoiceDetailScreen` — header nº/série+status, destinatário, linhas, totais,
**Abrir PDF/XML** via `url_launcher` c/ fallback clipboard, **cancelar** se `authorized`+`invoice.issue`,
timeline). Nav item `invoice`→('Notas Fiscais', `receipt_long`). Providers: `invoiceListProvider`,
`invoiceProvider(id)`, `orderInvoicesProvider(orderId)`, `saleInvoicesProvider(saleId)`. Repo:
`list/getOne/issue({orderId?,saleId?,documentType?})/cancel(id,reason)`.

**Fluxos de emissão:** (1) da **OS** (`os_detail_screen`): botão "Emitir nota fiscal" ou "Ver nota
fiscal · <status>" se já existe ativa; **auto-oferta** (`showNeuConfirm`) ao concluir/entregar a OS.
(2) da **venda** (`sale_detail_screen`, só `status==concluida`): `_IssueNfSection`/`_NfExistingSection`.
Sempre `repo.issue(...)` → navega pra nota (evita o 409). Design segue `orbixhub-frontend-flutter`
(neumorfismo, `context.neu`).

## PENDENTE (próximos passos)

1. Endpoints de config sensível do módulo (certificado A1, série, ambiente, CSC) — hoje `fields:[]`.
2. Testes e2e: isolamento de tenant, autorização por cargo, idempotência de webhook, guardrails
   (OS/venda cancelada, sem itens, nota duplicada).
3. `GovBrNfseGateway` real (quando for para produção) — nova impl do contrato (`FISCAL_PROVIDER=govbr`
   já é aceito pelo Zod mas nada ramifica nele ainda).
4. Estado desabilitado "Requer conexão" no front quando offline (depende da camada offline, ainda não construída).

> Ao mexer aqui, siga também a skill `orbixhub-arquitetura` (regras de ouro) e
> `orbixhub-billing` (padrão de gateway + webhook idempotente que o invoice espelha).
