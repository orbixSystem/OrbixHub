# Verticais: nicho, vocabulário e funcionalidades

> Design aprovado em 17/08/2026. Substitui a discussão em aberto de 10/08/2026
> (`tenant.vertical` rejeitado — ver §9, "Decisões descartadas").

## 1. Problema

O OrbixHub é vendido como SaaS multi-nicho, mas hoje **só atende oficina**. O
"contexto de veículo" não é configuração: é default cravado no código e casca de
vertical espalhada por módulos que deveriam ser genéricos.

Evidência no código de hoje:

| Onde | O que está preso |
|---|---|
| `back/src/modules/customers/customers.config.ts` | `DEFAULT_CUSTOMERS_CONFIG` = oficina: rótulo "Veículo", campo "Placa", cascata FIPE |
| `back/src/modules/customers/plates/` (7 arquivos) | Consulta WDAPI **sempre ligada**, gated só por env global `PLACAS_ENABLED` |
| `back/src/modules/customers/fipe.client.ts` | Cliente FIPE dentro do módulo genérico |
| `back/src/modules/customers/subject-lookup.service.ts:22` | `SOURCES = new Set(['fipe.marcas','fipe.modelos','fipe.anos'])` — fechado |
| `back/src/modules/os/os.service.ts:74` | `entregue: 'Veículo entregue'` |
| `back/src/modules/os/os-public.service.ts:19` | `entregue: 'Veículo entregue'` — vaza pro cliente final |
| `subject` (tabela) | Colunas `plate_data` / `plate_data_at` — casca de veículo na tabela genérica |
| `front/lib/features/customers/presentation/` | `vehicle_ficha_pdf`, `vehicle_ficha_dialog`, `plate_labels`, `brand_logo` |

Faltam também duas capacidades de produto:

- **Granularidade abaixo de módulo.** Só dá pra ligar/desligar módulo inteiro
  (`tenant_module.enabled`).
- **Nicho.** Não existe nenhum conceito de vertical. Os 6 tenants em produção estão
  com `tenant_module.settings` nulo, rodando o default de oficina do código.

## 2. Princípio: dois eixos ortogonais

**Nicho** e **funcionalidade** são eixos independentes.

- **Nicho** manda **só no vocabulário** — rótulos, campos do formulário, textos de
  status, e-mail, PDF, tela pública de acompanhamento.
- **Funcionalidade** é **capacidade**: liga/desliga por módulo, independente do nicho.

A prova de que precisam ser separados: a consulta do identificador numa base
externa serve oficina *e* assistência de câmera, mas não serve fisioterapia. Se a
funcionalidade fosse derivada do nicho, estaria duplicada em dois pacotes e
faltaria num terceiro. Como eixo próprio, cada vertical apenas **declara quais
capacidades genéricas ela liga** — e o módulo dono da capacidade nunca sabe que
nicho existe.

## 3. A regra que decide onde cada coisa mora

> **Catálogo que só muda com deploy → código. Estado do tenant → tabela.**

| O quê | Muda quando | Onde |
|---|---|---|
| Textos do nicho, campos do formulário, features que o nicho liga | só com deploy | código (`back/src/verticals/<key>/`) |
| Catálogo de funcionalidades por módulo | só com deploy (feature nova = código novo) | código (declarado por cada módulo) |
| Qual nicho o tenant é | no cadastro | coluna `tenant.vertical` |
| Quais features o dono ligou/desligou | quando ele clica | tabela `tenant_feature` |

Uma versão anterior deste design punha o catálogo em 5 tabelas
(`vertical`, `vertical_text`, `vertical_field`, `feature`, `vertical_feature`).
Descartada em 17/08: o benefício ("editar sem deploy") **não se realiza** — não
existe superfície de admin de plataforma no OrbixHub, então o catálogo seria
semeado por migration de qualquer jeito. O custo, esse sim, se realiza: cada texto
novo ou feature nova viraria migration aditiva nos 3 lugares em vez de um objeto
tipado com type-check e teste. Se um dia existir a tela de admin, as tabelas
voltam **de forma aditiva** — o resolvedor passa a consultar o banco antes do
código e nada do construído muda.

## 4. Schema

### 4.1 Uma tabela nova (RLS + FORCE)

```sql
CREATE TABLE IF NOT EXISTS tenant_feature (
  tenant_id   uuid NOT NULL REFERENCES tenant(id) ON DELETE CASCADE,
  feature_key text NOT NULL,                      -- 'customers.identifierLookup'
  enabled     boolean NOT NULL,
  source      text NOT NULL DEFAULT 'manual',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, feature_key)
);
```

Policy `tenant_id = current_tenant_id()`, igual às outras 29 tabelas de tenant.
`feature_key` é **texto, não FK** — o catálogo vive no código. Chave inválida é
recusada na escrita (validada contra o catálogo) e ignorada na leitura.

### 4.2 Uma coluna nova

```sql
ALTER TABLE tenant ADD COLUMN IF NOT EXISTS vertical text;
```

Nullable — `NULL` resolve para a vertical marcada como padrão (`equipamentos`).
Valor validado contra o `VerticalRegistry` na escrita.

### 4.3 Regra invariante: a linha só existe quando o dono mexeu

`tenant_feature` **não é semeada no cadastro**. Uma linha só nasce quando o dono
altera o toggle explicitamente; ausência = herda do catálogo.

É o que impede o retorno do bug do snapshot congelado (§6.2): funcionalidade nova
entra na lista da vertical e alcança todo tenant daquele nicho sem migration de
dados. O mesmo vale pro vocabulário — só o override vai pra
`tenant.settings.vocabOverrides`.

### 4.4 O que NÃO muda

- `subject` continua **uma tabela genérica**. Zero migração de dados.
- `service_order.subject_id` continua ponteiro uuid sem FK ("aponta, não invade").
- `module`, `plan`, `plan_module`, `tenant_module` continuam como estão, exceto o
  uso de `source` (§6.3).

## 5. Catálogo em código

### 5.1 Pacote de vertical

```ts
// back/src/verticals/veiculos/veiculos.vertical.ts
export const VEICULOS: VerticalPack = {
  key: 'veiculos',
  nome: 'Oficina / veículos',
  vocab: {
    'objeto.singular': 'Veículo',
    'objeto.plural': 'Veículos',
    'objeto.identificador': 'Placa',
    'os.status.entregue': 'Veículo entregue',
    'os.status.aguardando': 'Aguardando veículo',
  },
  subjectFields: [ /* placa, marca, modelo, ano, cor, km */ ],
  featuresLigadas: [
    'customers.identifierLookup',
    'customers.atributosCascata',
    'customers.fichaTecnica',
    'os.trackingLink',
  ],
};
```

`equipamentos` é o pacote padrão (`isDefault: true`), com vocabulário neutro e
`featuresLigadas` mínimo.

### 5.2 Catálogo de features

Cada módulo declara as **capacidades genéricas** que possui — nunca menciona nicho:

```ts
// customers.module.ts, onModuleInit
featureCatalog.register({
  key: 'customers.identifierLookup',
  moduleKey: 'customers',
  nome: 'Consulta por identificador',
  descricao: 'Consulta o identificador numa base externa e pré-preenche atributos.',
  defaultEnabled: false,
});
```

Quem liga a capacidade para um nicho é a vertical, via `featuresLigadas`.

## 6. Resolução

**Vocabulário:**

```
vocab(tenantId, key) =
    pack[vertical do tenant].vocab[key]
    ?? pack[vertical padrão].vocab[key]
    sobreposto por tenant.settings.vocabOverrides[key]
```

**Funcionalidade:**

```
featureLigada(tenantId, key) =
      módulo dono habilitado?   tenant_module.enabled
    ∧ disponível?               há implementação registrada no código
                                (∧ plan_feature — quando existir)
    ∧ ligada?                   tenant_feature.enabled
                                ?? pack[vertical].featuresLigadas contém key
                                ?? catalogo[key].defaultEnabled
```

O termo `disponível` não é decorativo: uma capacidade sem implementação registrada
para o nicho do tenant **não aparece nem como toggle**. É trava estrutural, não um
`if` de nicho.

## 7. Módulos e pontos de extensão

### 7.1 `back/src/verticals/` — novo módulo Nest

`VerticalsModule` provê:

- `VerticalRegistry` — packs e implementações registradas em `onModuleInit`.
- `FeatureCatalog` — capacidades declaradas por cada módulo.
- `VocabularyService` — `vocab(tenantId)` / `vocab(tenantId, key)`.
- `FeatureService` — `ligada()`, `listar()`, `alternar()`.

Lê `tenant.vertical` / `tenant.settings` via `TenancyService` e `tenant_module` via
`BillingService` — **nunca as tabelas deles** (regra 1). É dono de `tenant_feature`.

### 7.2 Pontos de extensão nos módulos genéricos

| Módulo | Ponto de extensão | Quem preenche |
|---|---|---|
| `customers` | `SubjectLookupRegistry` — substitui o `SOURCES` fechado | vertical registra `fipe.*` |
| `customers` | `SubjectIdentifierEnricher` — contrato "identificador → atributos" | vertical registra o de placa (WDAPI) |
| `os` | `vocab('os.status.*')` no lugar das strings fixas | catálogo |

Precedente existente: `CompositeSubjectHistoryProvider`
(`customers.module.ts:48-55`), onde `os` e `sale` registram suas fontes de
histórico sem o `customers` tocar nas tabelas delas.

### 7.3 Dependência de mão única

`verticals/veiculos` importa `customers` para se registrar. `customers` **nunca**
importa `verticals/veiculos`. Vertical nova = pasta nova, zero linha alterada no
genérico.

### 7.4 Movimentação de arquivos

| De | Para |
|---|---|
| `back/src/modules/customers/plates/` (7 arq.) | `back/src/verticals/veiculos/plates/` |
| `back/src/modules/customers/fipe.client.ts` | `back/src/verticals/veiculos/fipe.client.ts` |
| `front/.../presentation/vehicle_ficha_pdf.dart` | `front/lib/verticals/veiculos/` |
| `front/.../presentation/vehicle_ficha_dialog.dart` | `front/lib/verticals/veiculos/` |
| `front/.../presentation/plate_labels.dart` | `front/lib/verticals/veiculos/` |
| `front/.../presentation/brand_logo.dart` | `front/lib/verticals/veiculos/` |

## 8. O que isto resolve

### 8.1 Segundo nicho deixa de exigir fork

Hoje, cadastrar uma clínica significa que ela vê "Veículo", campo "Placa", cascata
FIPE, e recebe e-mail com "Veículo entregue". Depois: escolhe o nicho no cadastro e
o app fala a língua dela.

### 8.2 Mata o bug do snapshot congelado

Ocorrido em 08/06/2026: `updateConfig` persiste o `subjectFields` **inteiro**, então
adicionar `fonte`/`dependeDe` ao default não alcançou tenants que já tinham salvo
config — o autocomplete FIPE quebrou em 11 de 18 tenants. O paliativo atual
(`withFieldSourceDefaults`) reaplica atributos por chave em runtime. Com só o delta
persistido, o paliativo deixa de ser necessário e o problema deixa de ser possível.

### 8.3 Conserta "módulo desativado continua aparecendo"

`billing.repository.ts:96` faz `if (src && src !== 'plan') continue` e a linha 100
faz `update: { enabled: true }`. Um módulo desligado cuja linha ficou com
`source='plan'` é **religado na próxima troca de plano**. O toggle manual passa a
gravar `source='manual'`, e o reconcile o respeita.

### 8.4 Põe rédea no custo do WDAPI

`plates/` hoje está ligado para todo tenant, gated apenas pelo env global
`PLACAS_ENABLED`. Passa a ser por tenant, desligável na tela, e indisponível para
nichos sem implementação.

### 8.5 Granularidade abaixo de módulo

Tela "Módulos e funcionalidades": módulo (toggle = `tenant_module.enabled`) com as
funcionalidades aninhadas (toggle = `tenant_feature.enabled`).

### 8.6 A regra 4 da arquitetura passa a ser verdade

"Genérico, sem casca de vertical vazando" hoje é aspiração: 8 arquivos de veículo
dentro do `customers`, 2 colunas de placa na tabela genérica, strings de oficina no
`os`. Depois é fato verificável.

### 8.7 Gancho comercial pronto

`plan_feature` entra como mais um `∧` em `disponível`. Front não muda — continua
lendo `/me.features[]`.

## 9. O que isto NÃO resolve

- **Não cria admin de plataforma.** Mudar um texto de vertical continua sendo
  deploy (§3). O que muda é que passa a ser um objeto tipado em vez de um default
  cravado.
- **Não elimina as ~970 ocorrências** de termo de veículo no front. A Fase 4 cobre
  o que o usuário vê; nomes internos e arquivos gerados (`*.freezed.dart`) ficam.
- **Não mexe em plano nem preço.**
- **Não implementa a vertical câmera** — só deixa o caminho pronto.
- **Não muda `subject`** além de, opcionalmente, recolher `plate_data` para
  `attributes` (item avulso, pode ficar para depois).

## 10. Fases

Cada fase é independentemente entregável e verificável.

**Fase 0 — Migration.** `tenant_feature` + `tenant.vertical`, aditivas nos 3
lugares (`sql/auth-multitenant-schema.sql`, `prisma/migrations/`,
`schema.prisma`). Backfill: `UPDATE tenant SET vertical = 'veiculos' WHERE vertical IS NULL`.
*Critério: nada no app lê isso ainda; nenhum comportamento muda.*

**Fase 1 — `VerticalsModule` e resolvedor.** Packs `equipamentos` e `veiculos`,
catálogo de features, `VocabularyService`, `FeatureService`. `/me` ganha `vocab` e
`features`. `customers.getConfig` resolve do pack.
*Critério: o `/me` dos 6 tenants sai idêntico ao de hoje, campo a campo.*

**Fase 2 — Mover a vertical veículos.** `plates/` e `fipe.client` para
`verticals/veiculos/`; `SubjectLookupRegistry` e `SubjectIdentifierEnricher` como
pontos de extensão; `os` troca as strings por `vocab('os.status.*')`.
*Critério: `customers` sem nenhuma menção a veículo; e2e de tenant genérico não
alcança rota de placa.*

**Fase 3 — Tela de módulos e funcionalidades.** Seção no host `settings`; toggle de
módulo grava `source='manual'`; toggle de feature grava `tenant_feature`.
*Critério: desligar um módulo sobrevive a uma troca de plano.*

**Fase 4 — Front lê `vocab` e `features`.** `vocab` no `SessionState`; telas trocam
string fixa por `vocab(...)`; `front/lib/verticals/veiculos/` recebe ficha,
`brand_logo` e `plate_labels`, gated por feature. É a fase maior.
*Critério: `flutter analyze` 0 issues; testes de `gatedNavItems` estendidos.*

**Fase 5 — Seletor de nicho no cadastro.** `GET /verticals` público; seletor na
tela de registro (lista vinda do backend — regra 4).
*Critério: e2e cria tenant genérico e confirma ausência de placa, FIPE e textos de
oficina.*

> **Os 6 tenants de produção são o critério que manda em tudo.** São todos oficina e
> hoje rodam o default do código. Em nenhuma das seis fases eles podem ver
> diferença — mesmos rótulos, campos, consulta de placa e autocomplete.

## 11. Decisões descartadas (e por quê)

- **`tenant.vertical` como rótulo que nicha o tenant inteiro** — rejeitado pelo dono
  em 10/08/2026: grosso demais. A coluna desta spec **não** é aquilo: manda só no
  vocabulário; comportamento é decidido por `tenant_feature`, que é por módulo.
- **Catálogo em 5 tabelas** — descartado em 17/08 (§3): o benefício exige uma tela
  de admin que não existe; o custo de manutenção é imediato. Volta aditivamente se
  a tela existir.
- **Duas tabelas de dados (`vehicle` + `equipment`)** — descartado: exigiria
  discriminador em `os`, `sale`, `invoice` e `report`, migração das linhas dos 6
  tenants, e a 3ª vertical viraria 3ª tabela mais 3º caminho de código. O ganho de
  colunas tipadas é pequeno porque `identifier` já é a placa e já é indexado.
- **Features declaradas pelo módulo com `defaultFor: ['veiculos']`** — descartado:
  faria o módulo genérico conhecer nichos. Quem declara é a vertical.
- **Preset expandido no cadastro (copiar valores)** — descartado: é exatamente o
  mecanismo que causou o bug do snapshot congelado.
