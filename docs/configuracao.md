# OrbixHub — Configuração (host incremental)

## Princípio
- A tela de Configurações é um HOST: seção núcleo (sempre) + uma seção por módulo contratado (aparece se `tenant_module.enabled`; a UI decide pelo `modules[]` do /me).
- Cada módulo REGISTRA a própria seção (chave, título, schema dos campos) no `SettingsSectionRegistry`. O host monta a resposta a partir das seções registradas + habilitadas — um módulo novo só registra a sua seção e ela aparece, sem editar o host.
- Settings de empresa/branding → `tenant.settings` (jsonb). Settings de módulo → `tenant_module.settings[<moduleKey>]`.
- Funcionários & cargos NÃO entra aqui (é a área própria "Equipe").

## Contrato de registro de seções
- Backend: `SettingsSectionRegistry.register({ key, title, moduleKey, fields })` (em `back/src/modules/settings/settings.section-registry.ts`).
  - `moduleKey`: `null` para a seção núcleo; senão a chave do módulo (a seção só aparece se aquele módulo estiver habilitado no tenant).
  - `fields`: `[{ key, label, type, group? }]` com `type` ∈ `text | email | tel | url | color | bool | select | image`.
- `GET /settings` devolve `{ company, sections: [seção núcleo, ...seções de módulos habilitados] }`.
- `PATCH /settings/company` (requer `settings.manage`) atualiza `tenant.settings` (cores validadas como hex `#RRGGBB`).
- `POST /settings/company/logo` (requer `settings.manage`) faz upload da logo via StorageProvider (máx. 4 MB, `image/*`); persiste internamente `logoStorageKey` e expõe a URL pública em `logoUrl`.
- `DELETE /settings/company/logo` (requer `settings.manage`) remove a logo do storage e limpa `logoUrl` / `logoStorageKey`.

## Seções
### Empresa & Identidade visual (núcleo)
| Config | Chave (`tenant.settings`) | Tipo | Grupo | Obs |
|---|---|---|---|---|
| Nome fantasia | `companyName` | text | Identidade | |
| Razão social | `legalName` | text | Identidade | sincronizado em `tenant.name` e `tenant.legal_name` |
| CNPJ / documento | `taxId` | text | Identidade | sincronizado em `tenant.cnpj` |
| Telefone / WhatsApp | `phone` | tel | Identidade | |
| E-mail | `email` | email | Identidade | |
| Site | `website` | url | Identidade | |
| Logo | `logoUrl` | image | Identidade | upload via `POST /settings/company/logo`; `logoStorageKey` é interno (não exposto no JSON) |
| Inscrição Estadual | `inscricaoEstadual` | text | Fiscal | |
| Inscrição Municipal | `inscricaoMunicipal` | text | Fiscal | |
| Regime tributário | `regimeTributario` | select | Fiscal | simples / mei / presumido / real |
| CNAE principal | `cnae` | text | Fiscal | |
| CEP | `cep` | text | Endereço | |
| Logradouro | `logradouro` | text | Endereço | |
| Número | `numero` | text | Endereço | |
| Complemento | `complemento` | text | Endereço | |
| Bairro | `bairro` | text | Endereço | |
| Município | `municipio` | text | Endereço | |
| UF | `uf` | select | Endereço | siglas dos 27 estados |
| Tema do sistema | `themePreset` | select | Aparência | tangerina / vermelho / azul / verde / roxo / petroleo / ambar |
| Cor primária | `primaryColor` | color | Aparência | hex `#RRGGBB`; substitui a semente do tema quando preenchida |
| Cor secundária | `secondaryColor` | color | Aparência | hex `#RRGGBB` |

> **Legado:** o campo `address` (texto livre) foi substituído pelo endereço estruturado acima. Dados anteriores permanecem preservados no JSONB do tenant; o campo não é mais exposto na seção registrada.

### Nota Fiscal (módulo `invoice`)

O módulo já existe no backend (emissão a partir da OS, **online-only**, via gateway
fiscal abstrato — `NoopFiscalGateway` em dev; `GovBrNfseGateway` real futuro, API
NFS-e Nacional gov.br). A seção de config é registrada no host quando o módulo está
habilitado; as credenciais sensíveis abaixo terão endpoints próprios do módulo. A
fronteira de responsabilidade segue o princípio "aponta, não invade":

**No config da empresa (núcleo — já disponível agora):**
Os campos abaixo são **identidade do tenant** e úteis a múltiplos módulos. Ficam em
`tenant.settings` e são geridos por `PATCH /settings/company`:

- CNPJ / documento (`taxId`)
- Razão social (`legalName`)
- Inscrição Estadual (`inscricaoEstadual`) e Municipal (`inscricaoMunicipal`)
- Regime tributário (`regimeTributario`) e CNAE (`cnae`)
- Endereço fiscal completo (campos `cep` → `uf`)

**No próprio módulo `invoice` (via seção registrada + endpoints próprios):**
Dados **operacionais e sensíveis** que pertencem exclusivamente ao módulo:

| Dado | Obs |
|---|---|
| Certificado digital A1 (`.pfx`) | sensível; armazenado criptografado; nunca exposto no settings genérico |
| Ambiente | homologação / produção |
| Série e numeração de NF | controle de sequência da emissão |
| CSC / token NFC-e | credencial por ambiente |

O módulo `invoice` **aponta** para `tenant.settings` (lê CNPJ, IE, endereço) mas
**não invade** a tabela de settings do núcleo; seus dados operacionais ficam em
`tenant_module.settings['invoice']`, geridos pelos endpoints próprios do módulo.

### Clientes & Veículos (módulo `customers`)
Seção registrada pelo módulo `customers` — aparece em `GET /settings` quando o
módulo está habilitado no tenant. Os **valores** ficam em
`tenant_module.settings['clientes_veiculos']` (tabela do billing); o módulo lê/grava
via `BillingService.getModuleSettings`/`setModuleSettings` ("aponta, não invade").

| Config | Chave | Tipo | Default | Obs |
|---|---|---|---|---|
| Usa "veículos"? | `usaSubjects` | bool | `true` | desliga a entidade subject (ex.: salão = false) — os endpoints de subject passam a responder 403 |
| Rótulo | `subjectLabel` | `{ singular, plural }` | `{ "Veículo","Veículos" }` | "Pet" no petshop; usado na UI |
| Campos do veículo | `subjectFields` | lista `{ chave, rótulo, tipo, obrigatório }` | placa(`identifier`), marca, modelo, ano, cor, km | monta o formulário; `chave: identifier` mapeia para `subject.identifier` (placa), o resto para `attributes` |
| Documento obrigatório? | `documentRequired` | bool | `false` | quando `true`, exige `document` no cadastro de cliente |

- Leitura/escrita ricas (incluindo `subjectFields`): `GET /customers/config`
  (requer `customer.read`) e `PATCH /customers/config` (requer `settings.manage`).
- A seção registrada no host expõe os toggles escalares (`usaSubjects`,
  `documentRequired`, `subjectLabel.*`) para descoberta; a lista `subjectFields` é
  gerida pelos endpoints próprios do módulo.

#### Autocomplete de campos (fonte)

Um campo de `subjectFields` pode declarar uma `fonte` de autocomplete e, opcionalmente,
`dependeDe` (cascata). O backend serve as opções por `GET /customers/lookups/:fonte`
(cache de 24h em Redis, degradação graciosa). Fontes disponíveis:

- `fipe.marcas` — marcas de veículos (Tabela FIPE).
- `fipe.modelos` — modelos da marca selecionada (`dependeDe: 'marca'`).

A sugestão é **não-obrigatória**: o usuário pode digitar valores fora da lista. O valor
salvo é sempre o texto, em `attributes` (nenhum código FIPE é persistido). Verticais sem
veículos simplesmente não declaram esses campos.

### Estoque / Produtos (módulo `inventory`)
Seção registrada pelo módulo `inventory` — aparece em `GET /settings` quando o módulo
está habilitado no tenant. Os **valores** ficam em `tenant_module.settings['inventory']`
(tabela do billing); o módulo lê/grava via `BillingService.getModuleSettings`/
`setModuleSettings` ("aponta, não invade").

A config rica é a lista **`itemFields`** — os **campos da vertical** que montam o
formulário do item (mesmo padrão do `subjectFields` do módulo Clientes). O módulo é
genérico e nunca conhece "veículo"; quem semeia os defaults por vertical é a casca da
vertical no provisionamento do tenant (oficina semeia `vehicleApplication`; petshop, outro).

| Config | Chave | Tipo | Default | Obs |
|---|---|---|---|---|
| Campos da vertical | `itemFields` | lista `{ key, label, type, required, options? }` | `[]` | `type ∈ text\|number\|tags\|select`; gravados em `attributes` (jsonb) do item, validados por whitelist |

- Leitura/escrita rica: `GET /inventory/config` (requer `inventory.read`) e
  `PATCH /inventory/config` (requer `settings.manage`). A seção registrada no host não
  tem campos escalares (a lista `itemFields` é gerida por esses endpoints próprios — mesmo
  split do `customers`/`subjectFields`).
- No create/update de item, `attributes` é validado **whitelist** contra `itemFields`
  (chave desconhecida → 400; tipo errado → 400; `required` ausente → 400).

### Caixa (módulo `cashier`)
Seção registrada pelo módulo `cashier` — aparece em `GET /settings` quando o módulo
está habilitado no tenant. Os **valores** ficam em `tenant_module.settings['cashier']`,
lidos/gravados via `BillingService.getModuleSettings`/`setModuleSettings` ("aponta, não
invade").

| Config | Chave | Tipo | Default | Obs |
|---|---|---|---|---|
| Formas de pagamento | `paymentMethods` | lista de `pix\|dinheiro\|cartao_credito\|cartao_debito\|outro` | todas | oferecidas na UI; lista vazia/invalida cai no default |
| Exigir caixa aberto | `requireOpenSession` | bool | `true` | sem caixa aberto, lançar é 400 (se `false`, abre sessão implícita) |
| Conferir só dinheiro | `countCashOnly` | bool | `true` | `expected` no fechamento usa só dinheiro; pix/cartão são informativos |

- Leitura: `GET /cashier/config` (requer `cashier.read`). Escrita:
  `PATCH /cashier/config` (requer `settings.manage`). Os toggles escalares
  (`requireOpenSession`, `countCashOnly`) também aparecem na seção registrada do host;
  `paymentMethods` é lista, gerida pelo PATCH próprio.

<!-- Próximos módulos: registrem e documentem a subseção de config de cada um aqui. -->
