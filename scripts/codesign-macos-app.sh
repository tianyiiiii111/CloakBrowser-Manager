#!/usr/bin/env bash
# Sign a macOS .app bundle (ad-hoc by default, or Developer ID when configured).
set -euo pipefail

APP="${1:?usage: codesign-macos-app.sh /path/to/App.app}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENTITLEMENTS="${ROOT}/packaging/macos.entitlements"

IDENTITY="${MACOS_CODESIGN_IDENTITY:--}"
SIGN_OPTS=(--force --sign "$IDENTITY" --timestamp=none)

if [[ "$IDENTITY" != "-" ]]; then
  SIGN_OPTS+=(--options runtime --entitlements "$ENTITLEMENTS")
fi

echo "==> codesign ($IDENTITY): $(basename "$APP")"

while IFS= read -r -d '' item; do
  /usr/bin/codesign "${SIGN_OPTS[@]}" "$item" 2>/dev/null || true
done < <(find "$APP" -type f \( -perm -111 -o -name '*.dylib' -o -name '*.so' \) -print0)

/usr/bin/codesign "${SIGN_OPTS[@]}" --deep "$APP"
/usr/bin/codesign --verify --deep --verbose=2 "$APP"
