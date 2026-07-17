# Emissão de Nota Fiscal (serviço + produto) — Design

> **Status:** RASCUNHO aguardando revisão/aprovação do dono (design apresentado via
> brainstorming em 2026-07-16). **Nenhuma implementação iniciada.** Próximo passo após
> aprovação: `writing-plans` → plano de implementação faseado.
>
> Skills base: `orbixhub-arquitetura`, `orbixhub-fiscal-invoice`, `orbixhub-billing`,
> `orbixhub-backend-patterns`, `orbixhub-multitenancy-rls`, `orbixhub-frontend-flutter`,
> `orbixhub-testing`.

## Objetivo

Fazer o OrbixHub **emitir notas fiscais reais para serviço E produto**, posicionando-o como
concorrente do SG Master. Hoje o módulo `invoice` é uma fundação completa (backend + DB +
front + fronteira de config) que **já modela serviço e produto** (`invoice_line.kind`, split
`service_amount`/`product_amount`, `document_type ∈ nfse|nfce|nfe`), mas o único gateway que
existe é o `NoopFiscalGateway` (autoriza fake). **Falta a emissão real.**

## Decisões aprovadas (via brainstorming, 2026-07-16)

1. **Estratégia = gateway fiscal terceirizado (BaaS).** Não construir emissor próprio
   (SEFAZ/gov.br direto). Encaixa no contrato `FiscalGateway` abstrato já existente.
2. **Entregável desta rodada = completo + validado em SANDBOX (homologação), production-ready.**
   Não depende de o dono ter conta/certificado reais agora; fica pronto p/ produção assim que
   plugar conta + certificado + dados tributários.
3. **Provedor de referência = Nuvem Fiscal.** Design permanece agnóstico (trocar = outra impl
   do mesmo contrato). Confirmado: OAuth2 client credentials
   (`auth.nuvemfiscal.com.br/oauth/token`, scopes `empresa/nfe/nfce/nfse`); cadastro de
   **empresa + certificado + configurações no provedor**; cobre NFS-e (1.845 municípios),
   NFC-e e NF-e; XML download, envio de e-mail com PDF/XML, cancelamento.
4. **OS/venda mista = auto-split por natureza.** 1 clique → NFS-e (linhas de serviço) +
   NFC-e/NF-e (linhas de produto), como registros de `invoice` separados e independentes.
5. **Classificação fiscal = por item + padrões do tenant.** A Nuvem Fiscal calcula os tributos;
   nós enviamos a classificação correta.
6. **Derivação do documento de produto (proposta, a confirmar):** cliente PJ com CNPJ → NF-e;
   CPF / consumidor final / sem doc → NFC-e. Serviço sempre NFS-e.

## Arquitetura & componentes

**Modelo SaaS de provedor:** o OrbixHub tem **uma conta Nuvem Fiscal na plataforma**
(credenciais OAuth2 em env, globais). **Cada tenant vira uma "empresa"** cadastrada no provedor
pelo CNPJ, com o **certificado A1 enviado via passthrough** — o `.pfx` e o CSC ficam **no
provedor**, nunca persistidos no nosso banco. A plataforma paga o provedor; o lojista só fornece
CNPJ + certificado.

- **Novo `NuvemFiscalGateway implements FiscalGateway`** (`back/src/modules/invoice/fiscal/`).
  O contrato já tem tudo: `kind`, `serviceAmount`/`productAmount`, `nfse|nfce|nfe`,
  `issue/cancel/verifySignature`.
- **Factory de provider** no `invoice.module.ts`: trocar `useClass: NoopFiscalGateway` por
  `useFactory` que escolhe pelo `FISCAL_PROVIDER` (`noop` | `nuvemfiscal`). **Esse switch não
  existe hoje** (está hardcoded Noop — mesmo com `FISCAL_PROVIDER=govbr` nada muda).
- **Webhook idempotente já existe** (`invoice-webhook.controller` + `InvoiceService.processWebhook`
  + `invoice_webhook_event` global + `invoice_resolve_by_external_id` SECURITY DEFINER). Só mapear
  a assinatura/eventos da Nuvem Fiscal no `verifySignature`/parse.
- **"Aponta, não invade":** o `invoice` lê a classificação fiscal do item via **`InventoryService`
  público** (novo import no `InvoiceModule`), nunca tocando a tabela `inventory_item`. Identidade
  fiscal (CNPJ/IE/endereço) é lida de `tenant.settings` (núcleo), não duplicada.
- **Cliente HTTP fora de transação** (regra de ouro): `gateway.issue/cancel` já são chamados fora
  de tx no `InvoiceService`. Token OAuth2 cacheado com TTL.

## Modelo de dados (mudanças ADITIVAS, nos 3 lugares: baseline SQL + migration + schema.prisma)

| Tabela | Campos novos | Motivo |
|---|---|---|
| `inventory_item` (produto) | `ncm`, `cfop`, `origem`, `gtin` (opc) | classificação p/ NFC-e/NF-e (reusa `unit` como unidade comercial) |
| `inventory_item` (serviço) | `codigo_servico` (lista LC116/municipal), `aliquota_iss` (opc) | classificação p/ NFS-e |
| `invoice_line` | `ncm`, `cfop`, `unidade`, `gtin`, `codigo_servico` | **snapshot** da classificação usada (histórico) |
| `invoice` | *(nenhum)* | doc types e split de valor já existem; múltiplas notas por OS já são permitidas (não há unique por order_id) |
| config fiscal | `tenant_module.settings['invoice']` (jsonb) — **sem DDL** | série/numeração por doc, ambiente, flag "empresa cadastrada", validade do certificado |

Migrations previstas: `0031_inventory_fiscal_fields`, `0032_invoice_line_fiscal_snapshot`
(+ seed da permissão `invoice.config`). Todos os campos novos nullable (aditivo, não quebra baseline).

## Fluxo de emissão (auto-split por natureza)

Um clique em **"Emitir nota"** numa OS/venda:

1. `InvoiceService.issue` lê a OS/venda via service público (`OsService.getOrderWithItems` /
   `SalesService.getOne`) e separa as linhas por `kind`.
2. Havendo linhas de **serviço** → cria invoice **NFS-e**.
3. Havendo linhas de **produto** → cria invoice de produto com **derivação do tipo**:
   PJ/CNPJ → **NF-e** (mod. 55); CPF/consumidor final/sem doc → **NFC-e** (mod. 65).
4. Enriquecimento: cada linha recebe a classificação fiscal via `InventoryService.getItem`
   (snapshot em `invoice_line`). Item sem classificação → padrão do tenant, senão erro claro
   ("item sem NCM/CFOP" / "serviço sem código LC116").
5. Cada nota segue o fluxo atual: rascunho + evento `created` (tx curta) → `gateway.issue`
   **fora de tx** → persiste resultado (`status/external_id/number/series/access_key/pdf_url/
   xml_url/authorized_at`) + timeline (tx curta) → `audit.log('invoice_issue')`. Em falha do
   gateway: marca `status:'error'` + evento + `ServiceUnavailableException`.
6. **Guard por natureza:** `countAuthorizedByOrder`/`countAuthorizedBySale` passam a contar por
   (fonte, natureza) → permite **1 NFS-e ativa + 1 nota de produto ativa** por OS/venda (hoje a
   2ª nota de qualquer tipo é bloqueada por `ConflictException`).

Assíncrono: NFC-e/NF-e podem autorizar via SEFAZ de forma assíncrona → status inicial
`processing`, confirmação via **webhook** (plumbing já existe) com **polling de consulta** como
fallback.

## Config & segurança

- **Env (global, Zod em `common/config/env.schema.ts`):** `FISCAL_PROVIDER` (+`nuvemfiscal`),
  `NUVEMFISCAL_CLIENT_ID`, `NUVEMFISCAL_CLIENT_SECRET`, `NUVEMFISCAL_BASE_URL`,
  `NUVEMFISCAL_AUTH_URL`, `FISCAL_ENVIRONMENT`, `INVOICE_WEBHOOK_SECRET` (já existe).
- **Por tenant (endpoints próprios do módulo, owner-only `@Permissions('invoice.config')` +
  auditado):**
  - `PUT /invoices/config` — ambiente, série/numeração por doc, CSC idToken (repassado ao provedor).
  - `POST /invoices/config/certificate` — upload `.pfx` + senha → passthrough p/ Nuvem Fiscal;
    guardamos só validade + flag (nunca o `.pfx`).
  - `POST /invoices/config/register-empresa` — cadastra o tenant como empresa no provedor usando
    `tenant.settings` (CNPJ/IE/insc. municipal/CNAE/endereço já existentes).
- **Fronteira "aponta, não invade":** identidade fiscal no núcleo (`tenant.settings` via
  `/settings/company`); o módulo lê isso e é dono só do sensível/fiscal-específico. Segredos só
  via env; sem `.pfx`/CSC no nosso banco.

## Frontend (`front/lib/features/`)

- **`inventory` — cadastro de item:** campos fiscais condicionais (produto: NCM/CFOP/origem/GTIN;
  serviço: código LC116/ISS).
- **`settings` — nova tela "Nota Fiscal":** status do provedor, cadastro da empresa, upload do
  certificado (+aviso de validade), ambiente, série/numeração, CSC.
- **`os` / `sales` — detalhe:** "Emitir nota" chama o backend → auto-split → retorna as notas
  criadas; UI mostra as duas (NFS-e + produto) com status, download PDF/XML e cancelar cada uma.
  Botões e o diálogo "Emitir nota fiscal?" já existem (`os_detail_screen`, `sale_detail_screen`).
- **`invoice` — lista/detalhe:** já existem; garantir exibição do tipo de doc, PDF/XML e
  cancelamento. Regra de negócio/planos nunca hardcoded (vêm de `/me`).
- **Offline:** emissão é **online-only** (bloqueada offline com aviso "Requer conexão").

## Testes (`orbixhub-testing`)

- **Unit:** split por natureza; derivação NFC-e(CPF)/NF-e(CNPJ); guard por natureza; mapeamento
  do request p/ Nuvem Fiscal; validação de config.
- **e2e:** emissão NFS-e; emissão produto; OS mista → 2 notas; guard de duplicidade por natureza;
  webhook (assinatura + idempotência por `external_event_id`); isolamento de tenant (A não vê B);
  autorização por cargo; guardrails (OS/venda cancelada, sem itens).
- **Sandbox:** runbook de teste manual contra a homologação da Nuvem Fiscal (fora do CI; exige
  credenciais de teste). Documentar em `docs/`.

## Faseamento (para o plano de implementação)

1. **Fundação de config fiscal** — env creds + factory de provider + endpoints de config do tenant
   + cadastro empresa/certificado (passthrough) + tela de settings.
2. **Classificação fiscal** — campos fiscais no `inventory` (back+front) + snapshot em `invoice_line`.
3. **`NuvemFiscalGateway`** — NFS-e primeiro, depois NFC-e/NF-e; auto-split + guard por natureza +
   derivação; mapeamento de webhook.
4. **UX de emissão + validação em sandbox.**

## Itens a confirmar com o dono (não bloqueiam o registro)

- Regra de derivação **CPF→NFC-e / CNPJ→NF-e** (proposta acima).
- **Branch base** para a `feat/nf-servico-produto` (working tree atual: `branch-do-inacio`; o dono
  havia mencionado `master`).
- Permissão nova **`invoice.config`** (owner) para a config fiscal.
- Mapeamento fino de endpoints/campos da Nuvem Fiscal — fechar contra a API reference
  (`dev.nuvemfiscal.com.br/docs/api/`) na implementação.

## Fontes

- [API Nuvem Fiscal](https://dev.nuvemfiscal.com.br/docs/api/)
- [Autenticação — Nuvem Fiscal](https://dev.nuvemfiscal.com.br/docs/autenticacao/)
- [NFS-e — Nuvem Fiscal](https://dev.nuvemfiscal.com.br/docs/nfse/)
- [NFC-e — Nuvem Fiscal](https://dev.nuvemfiscal.com.br/docs/nfce/)
- [NF-e — Nuvem Fiscal](https://dev.nuvemfiscal.com.br/docs/nfe/)
