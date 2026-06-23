# OrbixHub — Módulos v1

## O que é um "módulo"

No OrbixHub, um **módulo** é uma unidade funcional que pode ser habilitada ou desabilitada por tenant conforme o plano contratado. Módulos do tipo **núcleo** estão sempre ativos (não dependem de plano); módulos do tipo **contratável** são ligados por plano e aparecem para o tenant somente quando habilitados.

A lista de módulos ativos do tenant é exposta pelo endpoint `GET /me` no array `modules[]`. A UI utiliza essa lista para exibir (ou ocultar) seções de navegação, telas e configurações de cada módulo. O guard `ModuleAccessGuard` bloqueia acessos a rotas de módulos não habilitados.

## Tabela de módulos

| Módulo | Chave | Tipo | Descrição |
|---|---|---|---|
| Identidade & Acesso | _(núcleo)_ | núcleo | Autenticação, usuários, perfis e controle de acesso baseado em cargos (IAM/RBAC). Sempre ativo. |
| Equipe | _(núcleo)_ | núcleo | Gestão de funcionários e cargos da oficina. Sempre ativo; possui área própria "Equipe" separada das configurações. |
| Configurações | _(núcleo)_ | núcleo | Host incremental de configurações da empresa e de módulos. Sempre ativo; cada módulo contratado registra a própria seção. A seção núcleo ("Empresa & Identidade visual") cobre: identidade (`companyName`, `legalName`, `taxId`, `phone`, `email`, `website`), logo (upload real via `POST /settings/company/logo`), campos fiscais (`inscricaoEstadual`, `inscricaoMunicipal`, `regimeTributario`, `cnae`), endereço estruturado (`cep` → `uf`) e aparência (`themePreset` com 7 presets, `primaryColor`/`secondaryColor`). A fronteira com o módulo `invoice` está documentada em `docs/configuracao.md`: campos de identidade fiscal ficam aqui; certificado A1, ambiente, série e CSC ficam no módulo invoice quando existir. |
| Assinatura / Billing | _(núcleo)_ | núcleo | Gestão de planos, ciclo de vida da assinatura (trial, ativo, vencido) e webhooks de pagamento. Sempre ativo. |
| Ordens de Serviço | `os` | contratável | Abertura, acompanhamento e encerramento de ordens de serviço de veículos. |
| Clientes | `customers` | contratável _(implementado)_ | Cadastros-base genéricos: **cliente** (contato/pagador) e **subject** (o que recebe o serviço — "Veículo" na oficina, "Pet" no petshop; rótulo/campos vêm da config). CRUD + arquivar + excluir (soft delete, status `deleted`) + busca; `GET /subjects/:id/history` pronto p/ consumir o service público da OS. |
| Estoque | `inventory` | contratável _(implementado)_ | Itens genéricos com **tipo `produto` \| `serviço`** (serviço = sem estoque, com preço + duração). Produtos: `sku`/`manufacturerCode`/`barcode`, preços decimais, `currentStock`/`minStock` + filtro "abaixo do mínimo". **SKU sugerido** (8 chars: 4 letras do nome + 4 dígitos, ex. `CAFE0001`, único por tenant). Campos da vertical via `itemFields` + `attributes` (jsonb, whitelist). **Código-first** `GET /inventory/lookup?code=` (interno → catálogo EAN via `CatalogProvider` Noop/Cosmos/OpenFoodFacts, **cache durável `catalog_product`** global 60d). **Soft delete** (`deleted_at`); filtro por tipo. Serviço público `getItem`/`incrementStock`/`decrementStock` p/ a OS ("aponta, não invade"). No plano `trial`. |
| Acompanhamento | `tracking` | contratável _(planejado)_ | Página pública de acompanhamento do status da OS pelo cliente final. |
| Caixa | `cashier` | contratável _(planejado)_ | Controle de caixa, recebimentos e pagamentos do dia. |
| Nota / Fiscal | `invoice` | contratável _(planejado)_ | Emissão e gestão de notas fiscais de serviço e produto. |
| Financeiro | `finance` | contratável _(planejado)_ | Fluxo de caixa, contas a pagar/receber e relatórios financeiros. |
| Relatórios | `report` | contratável _(implementado — backend)_ | Relatórios gerenciais e operacionais por período/módulo/técnico. **Sem tabela própria:** compõe on-the-fly chamando os services públicos de cada módulo (regra "aponta, não invade"). Gated por `@RequiresModule('report')` + `@Permissions('report.read')`. Habilitado em **trial + pro** (grátis hoje; paywall futuro = remover de um plano). Endpoints: `GET /report/os` (operacional), `/report/revenue` (faturamento + série por dia), `/report/team` (rendimento por responsável), `/report/top-items` (top produtos/serviços), `/report/inventory` (posição), `/report/customers` (novos + ativos). Front e export CSV/PDF nas Fases 3–4. |

> **Nota — "planejado":** módulos marcados como _planejado_ ainda não possuem implementação de backend. Suas chaves já estão presentes no catálogo de permissões (seeds), mas nenhum `BillingModule` / guard de rota está ativo para eles nesta versão.
