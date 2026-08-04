# Despesas: offline, detalhe e integração com Relatórios — plano de execução

> **Status:** plano aprovado, execução iniciada. Escrito para sobreviver a troca de
> contexto/sessão: contém o que já foi descoberto, os pontos de encaixe exatos e as
> armadilhas que já custaram tempo. Comece lendo "Estado atual" e "Armadilhas".
>
> Branch: `branch-do-inacio`. Último commit relevante: `45a652b`.

## Escopo

Três frentes, nesta ordem de dependência:

1. **Offline** (§1) — o módulo `expenses` é a única feature do app fora da camada
   offline. É a mais estrutural: mexe em contrato, sync e banco local.
2. **Detalhe da despesa** (§2) — abrir a conta e ver tudo (incluindo o lançamento
   de caixa que ela gerou), mais o caminho de volta do caixa para a despesa.
3. **Relatórios** (§3) — despesas no catálogo de relatórios.

Fora de escopo aqui (já pedido, item separado): deixar CLARO no cadastro a
diferença entre despesa fixa (recorrente) e avulsa — hoje é o switch `_repete`
escondido em `expense_form_dialog.dart:191`.

## Estado atual (verificado, não suposto)

O módulo veio da `qa` (PR #43, `feat/expenses`) e **já tem mais do que parece**:

| Peça | Onde | Situação |
|---|---|---|
| Tabelas | `back/prisma/migrations/0039_despesas/` | `expense`, `expense_category`, `expense_recurrence` — RLS+FORCE |
| Recorrência | `expenses/expense-recurrence.job.ts` | job gera as contas da regra |
| Baixa espelhada no caixa | `expenses.service.ts` (`pay`/`unpay`) | chama o service público do caixa; guarda `cash_entry_id` |
| Endpoints | `expenses.controller.ts` | `GET /expenses?ano&mes`, `categories` (GET/POST/PATCH), `PATCH /:id`, `POST /:id/pay`, `POST /:id/unpay`, `DELETE /:id` |
| Status derivado | `front/.../domain/expense_status.dart` | `vencido/venceHoje/venceEmBreve/aPagar/pago` — **não é coluna** |
| Cor por status | `front/.../presentation/expense_visuals.dart` | vencido → `neu.danger` (vermelho) já existe |
| Ordenação por urgência + busca | `front/.../domain/expense_ordering.dart` | puro e testado (14 testes) |
| Ações na linha | `expenses_screen.dart` (`_abrirAcoes`) | editar / duplicar / excluir |
| Criar categoria | `presentation/category_form_dialog.dart` | com prévia; chaves de ícone derivadas do mapa |

**O módulo `expenses` está semeado** (`module.key = 'expenses'`, `is_core=false`) e
habilitado no tenant de dev. Permissões: `finance.read` / `finance.write`.

---

## §1 Offline

### Por que é a mais estrutural

Todo o resto do app é offline-first via decorator (`LocalFirstBase`), e `expenses`
é a única exceção — a tela fala com `ExpensesRepositoryImpl` (dio puro). Sem rede,
ela não degrada: falha.

### CORREÇÃO IMPORTANTE — o backend JÁ ESTÁ PRONTO

Verificado no código (não suponha o contrário):

- `ExpensesService.listChangedSince` **existe** (`expenses.service.ts:509`), com
  whitelist de `expense` / `expense_category` / `expense_recurrence`;
- `PULL_ROUTES` **já registra** `expense` e `expense_category`
  (`sync.registry.ts:180`), permissão `finance.read`;
- `SYNC_OPS` **já tem** `expense.create`, `expense.update`, `expense.pay`,
  `expense.unpay`, `expense.cancel` (`sync.registry.ts:508+`);
- as três tabelas já têm `updated_at` **e** índice `(tenant_id, updated_at)` —
  quem escreveu a migration 0039 desenhou para o sync.

**Logo: NÃO há trabalho de backend em §1.** Quem escreveu o módulo na `qa` deixou
o backend offline-ready e paramos de um lado só.

Dois detalhes ainda a confirmar no backend (leitura, provavelmente já ok):
- `expense_recurrence` está em `PULL_ROUTES`? (o service permite, o registry pode
  não expor — se faltar, é uma linha);
- `expense.pay` no replay é idempotente? Ela cria `cash_entry` via
  `cashier.registrarSaidaDeDespesa`; replay do mesmo `clientMutationId` não pode
  gerar dois lançamentos. O `sync` já deduplica por mutation id, então o risco é
  baixo — mas vale um teste.

### Passos — SÓ FRONT

1. **`LocalFirstExpensesRepository`** em `front/lib/features/expenses/data/`,
   estendendo `LocalFirstBase` e implementando `ExpensesRepository`. Molde:
   `local_first_cashier_repository.dart`.
   - entidades locais: `'expense'`, `'expense_category'`, `'expense_recurrence'`;
   - `listarMes` offline: `rows('expense')` filtrando por mês em memória
     (`due_date` é data — comparar por dia civil, ver `expense_status.dart`), e
     recompor `ExpensesMonth` (itens + categorias + totais). **Os totais são
     calculados pelo servidor hoje** — offline precisam ser derivados aqui; extrair
     uma função PURA para isso e testá-la;
   - escritas → `enqueue(entidade, op, payload)` + `putRow(...)`, com as MESMAS
     chaves de op do registry (`expense.create`, `expense.pay`, …);
   - `marcarPaga`/`desmarcarPaga`: **não** criar o `cash_entry` no espelho local —
     ele chega pelo pull depois do replay. Comentar isso no código, porque a
     tentação de criar é grande e duplicaria o lançamento.

2. **`SyncEngine.entities`** (`core/offline/sync_engine.dart`): somar
   `'expense'`, `'expense_category'`, `'expense_recurrence'` e corrigir o número
   no doc-comment ("as N entidades replicadas").

3. **`describeMutation`** (`core/offline/widgets/pending_changes_panel.dart`):
   rótulos PT-BR para as entidades novas, senão o painel de pendências mostra a
   chave crua.

4. **`di.dart`**: envolver `ExpensesRepositoryImpl` no decorator, como o cashier.

### Como provar
- Unit do repo local-first (molde: `test/local_first_cashier_test.dart`).
- Contra a API: `GET /sync/changes?entity=expense&limit=10` devolvendo linhas, e
  `POST /sync/push` com `expense.create` → `applied`, e replay do MESMO
  `clientMutationId` → `applied` sem duplicar.

---

## §2 Detalhe da despesa (+ volta do caixa)

### O que a tela de detalhe mostra

Espelhar o que o detalhe da VENDA já faz (`sale_detail_dialog.dart` é o molde,
inclusive o rodapé de ações por intenção):

- descrição, valor previsto, vencimento, categoria (chip com ícone/cor), situação;
- **se paga:** quando, por qual forma, `paid_amount` (pode divergir do previsto —
  juros/desconto) e **o lançamento do caixa** que ela gerou;
- **se recorrente:** a regra que a originou ("todo dia 10, mensal");
- ações: marcar/desmarcar paga, editar, duplicar, excluir, e **exportar PDF**.

### Pontos de encaixe

- `Expense.cashEntryId` **já existe** no modelo do front (só o id — regra 1). Para
  mostrar o lançamento, pedir ao caixa via o repositório dele
  (`CashierRepository`), nunca lendo tabela alheia.
- **Caixa → despesa:** em `cashier_screen.dart` (`_EntryTile`) e
  `cashier_timeline_list.dart` (`_lancamento`) já existe o padrão de clique por
  origem — hoje trata `saleKind == 'sale'` (diálogo) e `'os'` (navega). Falta o
  caso da despesa. **Problema a resolver primeiro:** o `cash_entry` da baixa
  aponta para a despesa? Verificar se o `pay` grava algo em `sale_kind`/`sale_id`
  ou se a ligação existe só no sentido despesa→lançamento. Se for só num sentido,
  o caminho de volta exige uma coluna nova (migration aditiva nos 3 lugares) OU
  uma busca por `cash_entry_id` no módulo de despesas — **preferir a segunda**,
  que não mexe em schema: `GET /expenses?cashEntryId=…` ou um método no service.
- PDF: reusar `core/pdf/document_company.dart` + `pdf_theme.dart`
  (`pdfCompanyHeader`, `pdfSectionBand`, `pdfSignatureLine`) e
  `core/export/file_download.dart` (`downloadBytes`). O gerador deve ser função
  PURA recebendo `DocumentCompany` (logo já em bytes) — ver `sale_pdf.dart`.

---

## §3 Relatórios

`report` é módulo contratável com catálogo próprio
(`front/lib/features/report/`, backend `back/src/modules/report/`). Padrão: cada
relatório tem endpoint + CSV + PDF.

**Decisão de produto pendente (perguntar):** qual relatório de despesas? As opções
que agregam valor:
1. **Despesas por categoria no período** — para onde vai o dinheiro (pizza/barras);
2. **Contas a pagar em aberto** — fila de vencimento, com total vencido;
3. **Pago vs. previsto por mês** — evolução, para orçamento.

Recomendação: (1) primeiro (é o que responde "onde estou gastando"), depois (2).

**Regra 1 vale aqui:** o `report` NÃO lê as tabelas de despesa. Precisa de um
método no `ExpensesService` público (ex.: `summaryByCategory(tenantId, from, to)`)
e o report o consome — como já faz com o caixa.

---

## Armadilhas (já custaram tempo nesta sessão)

1. **`ref` depois de `await` em provider `autoDispose`** → "Cannot use ref after
   dispose". E `late final` atribuído no `build` → `LateInitializationError` se um
   método chegar antes. Padrão correto: **getter com cache** (ver
   `cashier_providers.dart:48`).
2. **Flag de "ocupado" resetado só no `catch`** → spinner eterno no caminho de
   sucesso. Foi o load infinito das despesas. Sempre `finally`.
3. **`invalidate` num FutureProvider troca a lista por spinner.** Usar
   `skipLoadingOnReload: true` no `when`, senão cada escrita parece travamento.
4. **`jsonb_set` não cria níveis intermediários** — para mexer em
   `tenant_module.settings`, usar merge de objeto (`||`). Ver migration 0037.
5. **Chave estrutural do sync não pode ter o mesmo nome de campo do DTO** — apaga
   o roteamento na 2ª validação. `structuralCollisions()` no spec guarda isso.
6. **Travessão (U+2014) não é desenhado** pela Helvetica embutida do PDF: sai
   sumido. Usar hífen. Acentos passam (WinAnsi).
7. **Logo corrompido derruba a geração do PDF inteiro** — validar magic bytes ao
   baixar (`bytesParecemImagem`).
8. **Layout responsivo por `LayoutBuilder`, não `MediaQuery`** — medir a tela
   dentro de um diálogo estreito escolhe o layout errado e estoura a linha.
9. **Nunca `rebase` neste repo.** `CLAUDE.md` §10 proíbe: quebra a ancestralidade
   e o workflow `sync-qa` falha de propósito. Integrar com **merge**.
10. **A `qa` anda rápido.** Refazer `git fetch` antes de mergear — já aconteceu de
    a branch avançar entre o fetch e o merge.

## Conflito de produto a comunicar

A cerimônia de **abrir/fechar caixa foi REMOVIDA** por decisão do dono
(`92dfa27`). O commit `6a1464e` da `qa` assumia o contrário e tinha movido a
**sangria** para dentro dessa cerimônia. No merge, a remoção prevaleceu e a
sangria ficou só no diálogo de lançamento. **Quem escreveu `6a1464e` deve ser
avisado** — a decisão dele foi desfeita deliberadamente, não por acidente.

## Verificação (rodar sempre antes de "pronto")

```
npm run back:test        # 411 testes
npm run back:lint        # 0 warnings
cd back && npx tsc --noEmit -p tsconfig.json
cd front && flutter analyze && flutter test    # 732 testes
```

Backend local: `cd back && npm run build && PORT=4400 node dist/src/main.js`
(o script é `build`, **não** `back:build` — este não existe).
