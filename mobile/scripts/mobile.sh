#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

FLAVOR="${2:-dev}"
ENV_FILE="env/${FLAVOR}.json"
[[ -f "$ENV_FILE" ]] || { echo "[ERR] $ENV_FILE topilmadi"; exit 1; }

case "${1:-web}" in
  run)
    flutter pub get
    flutter run --flavor "$FLAVOR" --dart-define-from-file="$ENV_FILE"
    ;;
  web)
    flutter pub get
    flutter run -d chrome --web-port 8090 --dart-define-from-file="$ENV_FILE"
    ;;
  test)
    flutter analyze
    flutter test
    ;;
  apk)
    flutter pub get
    flutter build apk --release --dart-define-from-file="$ENV_FILE" \
      --split-per-abi --obfuscate --split-debug-info="build/symbols/${FLAVOR}"
    ;;
  ios)
    flutter pub get
    flutter build ios --release --no-codesign --dart-define-from-file="$ENV_FILE"
    ;;
  windows)
    flutter pub get
    flutter build windows --release --dart-define-from-file="$ENV_FILE"
    ;;
  macos)
    flutter pub get
    flutter build macos --release --dart-define-from-file="$ENV_FILE"
    ;;
  linux)
    flutter pub get
    flutter build linux --release --dart-define-from-file="$ENV_FILE"
    ;;
  clean)
    flutter clean && flutter pub get
    ;;
  *)
    echo "Ishlatish: $0 {run|web|test|apk|ios|windows|macos|linux|clean} [dev|prod]"
    exit 2
    ;;
esac
