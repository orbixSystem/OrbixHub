#!/usr/bin/env bash
# Roda o app no primeiro device de uma PLATAFORMA (android|ios|macos|...), sem
# hardcodar id de emulador (que muda por máquina). Resolve o id via
# `flutter devices --machine` e repassa os args extras pro `flutter run`.
#
# Uso: scripts/run-flutter.sh <plataforma> [args do flutter run...]
set -euo pipefail

platform="${1:-}"
if [ -z "$platform" ]; then
  echo "uso: scripts/run-flutter.sh <android|ios|macos|windows|linux> [args]" >&2
  exit 2
fi
shift

id=$(flutter devices --machine | python3 -c "
import sys, json
devs = json.load(sys.stdin)
hit = next((d['id'] for d in devs if str(d.get('targetPlatform','')).startswith('$platform')), '')
print(hit)
")

if [ -z "$id" ]; then
  echo "Nenhum device/emulador '$platform' conectado." >&2
  if [ "$platform" = "android" ]; then
    echo "Abra um emulador e rode de novo:" >&2
    echo "  flutter emulators            # lista os AVDs" >&2
    echo "  flutter emulators --launch <id>" >&2
  fi
  exit 1
fi

echo "→ rodando em '$platform' (device: $id)"
exec flutter run -d "$id" "$@"
