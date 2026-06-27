# Autocomplete de marca/modelo no cadastro de veículo — Design

> Data: 2026-06-08 · Branch: `feat/customers-subjects` (ou nova `feat/subject-lookup-fipe`)
> Status: aprovado (brainstorming) · Próximo: plano de implementação (writing-plans)

## Problema

No cadastro de veículo (subject do módulo `customers`), os campos `marca`, `modelo`
e `ano` são digitados 100% à mão. Queremos que, ao digitar a **marca**, apareçam as
marcas existentes; e que, escolhida a marca (ex.: Ford), o campo **modelo** ofereça os
modelos daquela marca. O **ano** permanece manual.

## Tensão de arquitetura (e como resolvemos)

O formulário de subject é **genérico e dirigido por config** (regra de ouro #4): os
campos vêm de `subjectFields` em `tenant_module.settings`, não hardcoded. "Marca de
carro → modelo da Ford" é, por natureza, **casca do vertical oficina**. Logo:

- O **motor** é genérico: um campo pode declarar uma *fonte* de autocomplete e uma
  *dependência* (cascata). Qualquer vertical futuro pode usar o mesmo mecanismo.
- A **FIPE** é apenas **um provider registrado** (a casca de carro), isolado num
  arquivo. Petshop/salão não declaram esses campos e nunca tocam a FIPE.

## Decisões (do brainstorming)

| Tema | Decisão |
|------|---------|
| Fonte de dados | API FIPE pública, **via proxy no backend** com cache Redis |
| Provider FIPE inicial | **Parallelum v2** (`fipe.parallelum.com.br/api/v2`), trocável por abstração |
| Encaixe no form | **Campo genérico com `fonte` plugável** (não caso especial de "carro") |
| Comportamento | **Sugestão não-obrigatória** (texto livre permitido) |
| Cascata | **marca → modelo**; **ano fica manual** |
| Dado persistido | Continua **texto** em `attributes` (FIPE é só assistente de digitação) |

## Arquitetura

### 1. Conceito genérico — `SubjectFieldConfig` (aditivo, sem migration de tabela)

`subjectFields` vive em `tenant_module.settings['clientes_veiculos']` (jsonb), então
estender o shape **não** requer migration de banco. Campos novos, ambos opcionais:

```ts
export interface SubjectFieldConfig {
  chave: string;
  rotulo: string;
  tipo: SubjectFieldType;      // 'text' | 'number' (inalterado)
  obrigatorio: boolean;
  fonte?: string;             // NOVO — ex.: 'fipe.marcas' | 'fipe.modelos'. Ausente = campo normal.
  dependeDe?: string;         // NOVO — chave de outro campo (ex.: modelo dependeDe 'marca').
}
```

`DEFAULT_CUSTOMERS_CONFIG` (defaults da oficina) passa a marcar:
- `marca`: `fonte: 'fipe.marcas'`
- `modelo`: `fonte: 'fipe.modelos', dependeDe: 'marca'`
- `ano`: inalterado (number, manual)

`mergeCustomersConfig` deve preservar os novos campos (já faz merge raso de
`subjectFields` como array — ok; garantir que o array default novo seja usado quando
o tenant não tiver override).

### 2. Backend (módulo `customers`)

**a) Registry de fontes (genérico).** Mapa `fonte (string) → provider`. O controller
resolve a fonte pedida e delega. Fonte desconhecida → 404/400 padrão.

**b) `FipeProvider` (casca de carro, isolada).** Implementa duas fontes:
- `fipe.marcas` → lista de marcas `[{ value: nome, label: nome, meta: { codigo } }]`
- `fipe.modelos` (param `marca` = código FIPE) → modelos daquela marca

Filtragem por `q` (texto digitado) pode ser server-side (contains, case-insensitive)
sobre a lista cacheada.

**c) `FipeClient` (abstração trocável).** Faz a chamada HTTP à FIPE pública
(Parallelum v2: `/cars/brands`, `/cars/brands/{brandId}/models`). Implementação real +
fake pra testes. Trocar de provider (BrasilAPI etc.) = nova impl, sem mexer no resto.

**d) Endpoint genérico:**
```
GET /customers/lookups/:fonte?marca=<codigo>&q=<texto>
→ 200 [{ value, label, meta? }]
```
- Guards: `JwtAuthGuard` + `@RequiresModule('customers')` + `ModuleAccessGuard`.
- Não é dado tenant-scoped (é referência pública), mas fica atrás de auth/módulo.
- **Cache Redis** por `fonte + marca` (TTL ~24h). A lista cacheada é filtrada por `q`.
- **Chamada externa fora de qualquer transação de banco** (regra #5). É lookup puro —
  nenhuma escrita, nenhuma `withTenantTx`.
- **Degradação graciosa:** FIPE indisponível/timeout → log + retorna `[]` (ou cache
  velho, se houver). O campo continua editável como texto livre; cadastro nunca trava.

### 3. Frontend (`features/customers`)

**a) Modelos (freezed).** `SubjectFieldConfig` ganha `fonte`/`dependeDe`
(nullable). Regenerar `*.freezed.dart`/`*.g.dart`.

**b) Repository.** Novo método na **interface do domain**:
```dart
Future<List<LookupOption>> lookup(String fonte, {String? marca, String? q});
```
- Impl dio (chama `/customers/lookups/...`) + impl fake (listas estáticas pra teste).
- **UI nunca fala com a FIPE direto** (regra #8) — sempre via repository.
- `LookupOption { String value; String label; Map<String,dynamic>? meta; }`.

**c) `SubjectFormDialog`.** Campo com `fonte` renderiza um `Autocomplete`
(texto livre + sugestões) em vez de `TextFormField` puro:
- Ao digitar, debounce e chama `repo.lookup(fonte, marca: <codSelecionado>, q: texto)`.
- Selecionar uma opção de **marca** guarda o `meta['codigo']` em memória (state do
  dialog) pra alimentar o lookup de **modelo**.
- Trocar/limpar a marca **limpa o campo modelo** e o código guardado.
- Marca digitada fora da lista (sem código) → modelo sem sugestões, mas ainda editável.
- O valor salvo continua sendo o **texto** em `attributes` — nenhum código FIPE
  persiste no banco.

### 4. Dados / histórico

Persistência inalterada: `attributes['marca'] = 'Ford'`, `attributes['modelo'] = 'Ka'`.
FIPE é só assistente de digitação. Snapshot histórico (regra #2) não muda.

## Fluxo de dados

```
Form (campo marca, fonte=fipe.marcas)
  → repo.lookup('fipe.marcas', q='for')
    → GET /customers/lookups/fipe.marcas?q=for   [auth + módulo]
      → cache Redis hit? devolve filtrado
      → miss → FipeClient.brands() → cacheia 24h → filtra por q
  ← [{value:'Ford', meta:{codigo:'22'}}, ...]
Usuário escolhe Ford → dialog guarda codigo=22
Form (campo modelo, fonte=fipe.modelos, dependeDe=marca)
  → repo.lookup('fipe.modelos', marca='22', q='ka')
    → GET /customers/lookups/fipe.modelos?marca=22&q=ka
  ← [{value:'Ka', ...}, {value:'Ka Sedan', ...}]
```

## Tratamento de erro

- FIPE down/timeout → endpoint devolve `[]` (degradação graciosa); campo segue como
  texto livre. Erro logado, nunca propagado como 500 que trave o form.
- Fonte desconhecida → erro padrão `{ statusCode, error, message }`.
- Sem módulo `customers` / sem auth → 403/401 (guards).

## Testes

**Backend:**
- Unit: registry resolve fonte; `FipeProvider` com `FipeClient` fake (marcas/modelos);
  filtro por `q`; degradação quando o client lança.
- e2e: `GET /customers/lookups/:fonte` exige auth + módulo; retorna shape correto;
  cache (segunda chamada não bate no client). **Sem I/O externo real** (client fake/mock).

**Frontend:**
- Widget: campo com `fonte` mostra sugestões; selecionar marca habilita modelos;
  trocar marca limpa modelo; texto livre fora da lista é aceito e salvo.
- Repo fake cobre os dois cenários.

## Não-objetivos (YAGNI)

- Ano via FIPE (fica manual).
- Seleção estrita / validação contra catálogo (sugestão é não-obrigatória).
- Persistir código FIPE, valor de tabela (preço), tipo de combustível.
- Motos/caminhões (só carros por ora; o provider permite estender depois).
- Job de seed/cache warmup (cache lazy on-demand basta).

## Regras de ouro tocadas

- #4 genérico: motor genérico, FIPE como provider isolado. ✓
- #5 segurança: chamada externa fora de transação; degradação graciosa. ✓
- #8 front: UI só via repository. ✓
- #9 migrations: nenhuma migration de tabela (config é jsonb); shape evoluído nos 3
  lugares só onde a config é tipada (back config + front model). ✓
