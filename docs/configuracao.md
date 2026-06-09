# OrbixHub — Configuração (host incremental)

## Princípio
- A tela de Configurações é um HOST: seção núcleo (sempre) + uma seção por módulo contratado (aparece se `tenant_module.enabled`; a UI decide pelo `modules[]` do /me).
- Cada módulo REGISTRA a própria seção (chave, título, schema dos campos) no `SettingsSectionRegistry`. O host monta a resposta a partir das seções registradas + habilitadas — um módulo novo só registra a sua seção e ela aparece, sem editar o host.
- Settings de empresa/branding → `tenant.settings` (jsonb). Settings de módulo → `tenant_module.settings[<moduleKey>]`.
- Funcionários & cargos NÃO entra aqui (é a área própria "Equipe").

## Contrato de registro de seções
- Backend: `SettingsSectionRegistry.register({ key, title, moduleKey, fields })` (em `back/src/modules/settings/settings.section-registry.ts`).
  - `moduleKey`: `null` para a seção núcleo; senão a chave do módulo (a seção só aparece se aquele módulo estiver habilitado no tenant).
  - `fields`: `[{ key, label, type }]` com `type` ∈ `text | color | url | bool`.
- `GET /settings` devolve `{ company, sections: [seção núcleo, ...seções de módulos habilitados] }`.
- `PATCH /settings/company` (requer `settings.manage`) atualiza `tenant.settings` (cores validadas como hex `#RRGGBB`).

## Seções
### Empresa & Identidade visual (núcleo)
| Config | Chave (tenant.settings) | Tipo | Obs |
|---|---|---|---|
| Nome fantasia | companyName | text | |
| Razão social | legalName | text | |
| CNPJ / documento | taxId | text | |
| Endereço | address | text | |
| Telefone / WhatsApp | phone | text | |
| E-mail | email | text | |
| Logo | logoUrl | url | nesta versão só a URL (upload de arquivo fica para depois) |
| Cor primária | primaryColor | color | hex #RRGGBB; usada no app e na página de acompanhamento |
| Cor secundária | secondaryColor | color | hex #RRGGBB |

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

<!-- Próximos módulos: registrem e documentem a subseção de config de cada um aqui. -->
