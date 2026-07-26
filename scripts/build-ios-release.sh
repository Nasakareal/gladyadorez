#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIREBASE_PLIST="$ROOT_DIR/ios/Runner/GoogleService-Info.plist"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Este script debe ejecutarse en macOS con Xcode instalado." >&2
  exit 1
fi

if [[ ! -f "$FIREBASE_PLIST" ]]; then
  echo "Falta ios/Runner/GoogleService-Info.plist para el bundle com.nasakareal.gladyadorez." >&2
  echo "Descárgalo desde la app iOS del proyecto Firebase gladyadorez-afiliados-1234." >&2
  exit 1
fi

cd "$ROOT_DIR"
flutter pub get
(cd ios && pod install --repo-update)
flutter analyze
flutter test
flutter build ipa \
  --release \
  --export-options-plist=ios/ExportOptions.plist

echo "IPA lista en build/ios/ipa/"
