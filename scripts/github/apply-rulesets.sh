#!/usr/bin/env bash
# Aplica (cria ou atualiza) os rulesets de branch do repositorio a partir dos
# JSONs versionados em .github/rulesets/.
#
#   pre-requisito: gh CLI autenticado com escopo de admin no repo
#     gh auth login
#     gh auth refresh -h github.com -s admin:org,repo
#
#   uso: ./scripts/github/apply-rulesets.sh
#
# Idempotente: se ja existe um ruleset com o mesmo "name", ele e atualizado
# via PUT em vez de duplicado.
set -euo pipefail

REPO="${REPO:-orbixSystem/OrbixHub}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

for file in "$ROOT"/.github/rulesets/*.json; do
  name="$(jq -r '.name' "$file")"
  echo "== ruleset '$name' (de $(basename "$file"))"

  existing="$(gh api "repos/$REPO/rulesets" --jq \
    ".[] | select(.name == \"$name\") | .id" || true)"

  if [ -n "$existing" ]; then
    echo "   ja existe (id $existing) -> atualizando"
    gh api -X PUT "repos/$REPO/rulesets/$existing" --input "$file" >/dev/null
  else
    echo "   criando"
    gh api -X POST "repos/$REPO/rulesets" --input "$file" >/dev/null
  fi
  echo "   ok"
done

echo
echo "rulesets ativos:"
gh api "repos/$REPO/rulesets" --jq '.[] | "  \(.name) [\(.enforcement)] -> \(.target)"'
