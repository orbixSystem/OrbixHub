# OrbixHub — Configuração (host incremental)

## Princípio
- A tela de Configurações é um HOST: seção núcleo (sempre) + uma seção por módulo contratado (aparece se `tenant_module.enabled`; a UI decide pelo `modules[]` do /me).
- Cada módulo REGISTRA a própria seção (chave, título, schema dos campos) no `SettingsSectionRegistry`. O host monta a resposta a partir das seções registradas + habilitadas — um módulo novo só registra a sua seção e ela aparece, sem editar o host.
- Settings de empresa/branding → `tenant.settings` (jsonb). Settings de módulo → `tenant_module.settings[<moduleKey>]`.
- Funcionários & cargos NÃO entra aqui (é a área própria "Equipe").

## Contrato de registro de seções
- Backend: `SettingsSectionRegistry.register({ key, title, moduleKey, fields })` (em `back/src/modules/settings/settings.section-registry.ts`).
  - `moduleKey`: `null` para a seção núcleo; senão a chave do módulo (a seção só aparece se aquele módulo estiver habilitado no tenant).
  - `fields`: `[{ key, label, type }]` com `type` ∈ `text | color | url`.
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

<!-- Próximos módulos: registrem e documentem a subseção de config de cada um aqui. -->
