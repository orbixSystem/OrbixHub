# Report: Selects ancorados + CNAE buscável via IBGE

## Fix 1 — Regime tributário / UF (select → DropdownMenu)

`DropdownButtonFormField` foi removido. Todos os campos com `field.type == 'select'`
agora usam `DropdownMenu<String>` (Material 3) via `_buildSelectDropdown()`:

- `expandedInsets: EdgeInsets.zero` → preenche a largura disponível igual aos TextFormField
- `menuHeight: 320` → altura máxima do menu
- `menuStyle: MenuStyle(backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh))` → menu opaco
- `inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(radius 10), isDense: true)` → consistente com os demais campos
- `initialSelection: _selectValues[field.key]` → pré-seleção
- `onSelected` → grava em `_selectValues[field.key]`
- `_buildPatch()` lê `_selectValues` como antes — save inalterado
- Menu abre ABAIXO (comportamento nativo do DropdownMenu M3); campo é opaco

O ViaCEP ao preencher UF continua gravando `_selectValues['uf']`; o DropdownMenu exibirá o novo valor no próximo rebuild (setState já feito pelo caller).

## Fix 2 — CNAE buscável via API IBGE

### Widget
Campo `cnae` é tratado de forma especial em `_buildFieldWidget` antes do bloco genérico de `_isTextField`. Usa `_buildCnaeField()`.

### Caching
- Variáveis de módulo `_cnaeCache` (List?) + `_cnaeLoading` (bool) — cache em memória, singleton de processo.
- `_loadCnaes()`: função top-level que chama `GET https://servicodados.ibge.gov.br/api/v2/cnae/subclasses` com um `Dio()` FRESH (sem auth bearer, sem apontar para a API interna). Carrega uma vez; rebuilds subsequentes retornam o cache imediatamente.
- `initState` dispara `_loadCnaesAsync()` que aguarda e chama `setState`.

### Estados UI
| `_cnaes` | Renderização |
|---|---|
| `null` | TextFormField desabilitado + spinner (carregando) |
| `[]` (erro) | TextFormField editável + helperText de fallback |
| lista preenchida | `DropdownMenu<String>` com `enableFilter: true`, `requestFocusOnTap: true` |

### Chamada IBGE
```
GET https://servicodados.ibge.gov.br/api/v2/cnae/subclasses
→ JSON array [ { "id": "4520001", "descricao": "...", ... } ]
```
API pública sem autenticação. CORS permissivo documentado pelo IBGE.
Nota: não foi possível confirmar CORS em browser nesta sessão (sem servidor web rodando); a API é bem documentada como pública sem restrição de origem, e o mesmo padrão foi usado com sucesso para o ViaCEP no mesmo arquivo.

### Entries do DropdownMenu
- `label: "$id - $descricao"` (ex.: `"4520001 - Serviços de manutenção e reparação mecânica…"`)
- `value: id` (código CNAE, string)
- `initialSelection`: código da empresa se encontrado na lista; `null` caso contrário
- `onSelected`: grava `_selectValues['cnae']`
- `_buildPatch()`: campo `cnae` entra no patch se `_selectValues['cnae'] != original` (lógica já existente para campos select)

### Fallback
Se `_loadCnaes()` lançar exceção, `_cnaeCache` é definido como `[]`. O widget mostra um `TextFormField` livre com `helperText` informando que a lista está indisponível — formulário continua funcional.

## Analyze / Test

```
flutter analyze → No issues found! (ran in 92.6s)
flutter test    → +67: All tests passed!
```

Nenhum teste existente quebrou. Nenhum teste novo foi criado (não havia testes de widget para `CompanyForm` especificamente; os `settings_screen_test.dart` passaram sem alteração).

## Commit

Ver hash abaixo (gerado após este report).

## Concerns

- IBGE CORS: a API pública `servicodados.ibge.gov.br` não exige autenticação e historicamente serve `Access-Control-Allow-Origin: *`, mas não foi possível confirmar com um browser nesta sessão. Se CORS falhar em produção web, `_cnaeCache` será `[]` e o fallback de texto livre será exibido automaticamente — sem crash.
- ~1.3k entradas no DropdownMenu com `enableFilter: true`: Material 3 usa um `ListView` lazy que filtra internamente. Aceitável; se for sluggish, é possível migrar para `Autocomplete<String>` com `optionsBuilder` retornando no máximo 40 matches.
- O estado inicial de `DropdownMenu` com `initialSelection` reflete o código na tela, mas o texto exibido no campo pode ficar em branco se o código salvo não estiver na lista local (ex.: CNAE inválido salvo manualmente). Isso é comportamento padrão do widget; um usuário precisaria re-selecionar.
