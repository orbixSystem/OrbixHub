# Processo de Git: branch `qa` como portão para produção

**Data:** 2026-08-02
**Status:** aprovado
**Escopo:** workflows do GitHub Actions, rulesets do repositório `orbixSystem/OrbixHub`, `CLAUDE.md`

---

## 1. Problema

Hoje `main` é a default branch e **todo push nela dispara deploy em produção**
([`.github/workflows/deploy.yml`](../../../.github/workflows/deploy.yml) roda em
`push: branches: [main]` → build GHCR + Flutter web → EC2 via Tailscale). Não existe
nenhuma proteção no repositório: um `git push origin main` acidental — de uma pessoa
ou de um agente — vai direto pra prod.

Falta um estágio de integração onde o código é reunido e validado antes de virar
release.

## 2. Solução

Uma branch `qa` entre o trabalho e a produção. `main` deixa de ser um lugar onde
alguém escreve e passa a ser **apenas o resultado de um merge vindo da `qa`**.

### 2.1 Modelo de branches

| Branch | Papel | Como recebe commits |
|---|---|---|
| `main` | produção. Todo push = deploy. | **exclusivamente** merge de PR cuja origem é `qa` |
| `qa` | integração. Roda CI; validação manual acontece aqui. | merge de PRs de `feat/*` / `fix/*` (ou push direto, permitido) |
| `feat/*`, `fix/*` | trabalho em andamento | livre |

`qa` é criada a partir de `main` e no momento zero as duas são idênticas.
A **default branch do repositório passa a ser `qa`**, para que PRs novos já abram com
base correta e clones novos caiam na branch de trabalho. `deploy.yml` não é afetado:
ele referencia `main` explicitamente.

### 2.2 Fluxo normal

1. `git switch qa && git pull && git switch -c feat/x` — toda branch nova nasce da `qa`.
2. PR `feat/x` → `qa`. CI verde → merge.
3. Validação do que está na `qa`.
4. PR `qa` → `main`, mergeado como **merge commit** (não squash, não rebase). O merge
   dispara o deploy.
5. `qa` é ressincronizada com `main` por fast-forward — automatizado (§3.4).

**Não há caminho de exceção.** Hotfix também entra pela `qa`. A decisão é deliberada:
um atalho documentado vira o caminho padrão em pouco tempo. Para emergências, o
`deploy.yml` já aceita `workflow_dispatch`, permitindo redeploy de uma imagem anterior.

### 2.3 Por que merge commit no passo 4

Com merge commit, o head da `qa` vira ancestral do commit de merge em `main`. Logo
`git merge --ff-only main` a partir da `qa` sempre funciona e as duas branches voltam
a ser idênticas sem force-push.

Squash e rebase criam commits novos, sem esse elo de ancestralidade: a `qa` divergiria
de `main` a cada release e a ressincronização exigiria force-push. Por isso o passo 4
exige merge commit, e o `sync-qa` (§3.4) falha em vez de forçar quando o fast-forward
não é possível.

## 3. Mudanças no repositório

### 3.1 `ci.yml` — rodar também na `qa`

```yaml
on:
  push: { branches: [main, qa] }
  pull_request:

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
```

O resto do arquivo não muda. O `concurrency` evita runs empilhados no mesmo ref.

### 3.2 `deploy.yml` — inalterado

Continua em `push: [main]` + `workflow_dispatch`. A garantia nova não vem do gatilho e
sim do ruleset: `main` só muda por PR vindo da `qa`.

### 3.3 `pr-guard.yml` (novo) — quem aplica a regra

Rulesets do GitHub não sabem restringir a **origem** de um PR, só o destino. Este
workflow é o que efetivamente impede um PR `feat/x` → `main`:

```yaml
name: PR guard
on:
  pull_request:
    branches: [main]

jobs:
  qa-only:
    name: PR para main deve vir da qa
    runs-on: ubuntu-latest
    steps:
      - name: Verifica a branch de origem
        run: |
          if [ "${{ github.head_ref }}" != "qa" ]; then
            echo "::error::PR para main só é aceito a partir da branch qa (origem: ${{ github.head_ref }})."
            exit 1
          fi
          echo "origem OK: qa"
```

Roda apenas em PRs com base `main`, então não pesa no fluxo do dia a dia.

### 3.4 `sync-qa.yml` (novo) — ressincronização automática

Depois de um push na `main`, traz a `qa` de volta ao mesmo commit por fast-forward.
Elimina o passo manual que seria esquecido.

```yaml
name: Sync qa
on:
  push:
    branches: [main]

permissions:
  contents: write

concurrency:
  group: sync-qa
  cancel-in-progress: false

jobs:
  ff:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - name: Fast-forward da qa
        run: |
          set -euo pipefail
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          if ! git ls-remote --exit-code --heads origin qa >/dev/null; then
            echo "qa não existe; criando a partir de main"
            git push origin "HEAD:refs/heads/qa"
            exit 0
          fi
          git fetch origin qa
          if git merge-base --is-ancestor origin/qa "$GITHUB_SHA"; then
            git push origin "$GITHUB_SHA:refs/heads/qa"
            echo "qa fast-forward para $GITHUB_SHA"
          else
            echo "::error::qa não é ancestral de main; ressincronize à mão. \
            Provável causa: o PR qa→main foi mergeado com squash ou rebase."
            exit 1
          fi
```

O push é feito com o `GITHUB_TOKEN` padrão, que **não** dispara novos workflows — logo
não há loop de CI na `qa` após o sync.

### 3.5 Rulesets

Aplicados via `gh api` e versionados em `.github/rulesets/*.json` para poderem ser
reaplicados. O repositório é público, então rulesets estão disponíveis no plano free.

**`main`:**
- `deletion` e `non_fast_forward` — sem deleção, sem force-push.
- `pull_request` com `required_approving_review_count: 0`. Zero é intencional: hoje há
  um único aprovador e o GitHub não permite aprovar o próprio PR. Sobe para 1 quando o
  time crescer.
- `required_status_checks` com `strict_required_status_checks_policy: true`, exigindo
  os contextos `back` (de `ci.yml`) e `PR para main deve vir da qa` (de `pr-guard.yml`).

Sem `bypass_actors`: a regra vale inclusive para admin. É esse o ponto.

**`qa`:**
- `deletion` e `non_fast_forward` apenas.

Deliberadamente **não** exige PR: permite push direto quando conveniente e permite o
fast-forward do `sync-qa` sem precisar de bypass. A trava dura fica na `main`.

## 4. Documentação

- **`CLAUDE.md` §10** hoje instrui *"trabalhe em `feat/...`. Não commite direto na
  `main`/`master` sem pedir"*. Passa a descrever o fluxo da `qa`, incluindo a base das
  branches novas e a regra do merge commit. Sem isso, agentes que leem o `CLAUDE.md`
  continuarão abrindo PR para `main`.
- Memória `repo-branch-main.md` ("base todo PR nela") é atualizada para refletir a `qa`.

## 5. Fora de escopo

- Ambiente de QA implantado (segunda EC2, subdomínio, banco separado). A `qa` roda CI;
  validação é local.
- Limpeza das ~18 branches locais antigas.
- Migrar o trabalho em andamento em `feat/offline-sync`.
- Exigir aprovação de review nos PRs.

## 6. Verificação

O processo é aceito quando, com o setup aplicado:

1. `git push origin main` a partir de um clone é **rejeitado** pelo servidor.
2. Um PR `feat/x` → `main` mostra o check `PR para main deve vir da qa` **falhando** e
   o botão de merge bloqueado.
3. Um PR `qa` → `main` com CI verde é mergeável, e o merge dispara `Deploy prod`.
4. Após esse merge, o run de `Sync qa` termina verde e `origin/qa == origin/main`.
5. Push na `qa` dispara o workflow `CI`.

Os itens 3 e 4 só podem ser confirmados num release real; os demais são verificáveis
imediatamente após o setup.
