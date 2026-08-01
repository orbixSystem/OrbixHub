#!/usr/bin/env bash
# Build de produção — Android (APK) e/ou macOS/web, a partir de env/prod.json.
#
#   ./scripts/build_prod.sh apk        # APK universal (instalação direta)
#   ./scripts/build_prod.sh appbundle  # .aab (Play Store)
#   ./scripts/build_prod.sh web
#   ./scripts/build_prod.sh macos
#
# Windows NÃO sai daqui: o Flutter não faz cross-compile: o app Windows precisa
# ser compilado numa máquina Windows (use scripts/build_prod.ps1).
set -euo pipefail

cd "$(dirname "$0")/.."
TARGET="${1:-apk}"
ENV_FILE="env/prod.json"

echo "▶ alvo: $TARGET · config: $ENV_FILE"
grep -q '"API_BASE_URL"' "$ENV_FILE" || { echo "✗ $ENV_FILE sem API_BASE_URL"; exit 1; }

flutter pub get
dart run build_runner build          # *.freezed.dart / *.g.dart
flutter analyze                       # 0 issues antes de empacotar
flutter test                          # suíte unitária/widget

case "$TARGET" in
  apk)       flutter build apk       --release --dart-define-from-file="$ENV_FILE" ;;
  appbundle) flutter build appbundle --release --dart-define-from-file="$ENV_FILE" ;;
  web)       flutter build web       --release --dart-define-from-file="$ENV_FILE" ;;
  macos)     flutter build macos     --release --dart-define-from-file="$ENV_FILE" ;;
  *) echo "✗ alvo desconhecido: $TARGET"; exit 1 ;;
esac

echo "✔ pronto — artefato em build/"
