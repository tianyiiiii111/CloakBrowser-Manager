#!/usr/bin/env bash
# Build macOS distributable (.dmg). Run on macOS only.
# Usage: ./scripts/build-macos.sh [--package-only]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(grep -E '^version\s*=' pyproject.toml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
PACKAGE_ONLY=false
[[ "${1:-}" == "--package-only" || "${1:-}" == "-p" ]] && PACKAGE_ONLY=true

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "build-macos.sh must run on macOS." >&2
  exit 1
fi

PYTHON="${PYTHON:-}"
if command -v python3 &>/dev/null; then PYTHON=python3
elif command -v python &>/dev/null; then PYTHON=python
else echo "python not found" >&2; exit 1; fi

if ! $PACKAGE_ONLY; then
  echo "==> frontend"
  (cd frontend && npm ci && npm run build)

  echo "==> python"
  [[ -d .venv-build ]] || "$PYTHON" -m venv .venv-build
  # shellcheck disable=SC1091
  source .venv-build/bin/activate
  pip install -q -r packaging/requirements-desktop.txt

  echo "==> pyinstaller"
  pyinstaller packaging/cloakbrowser-manager.spec --noconfirm --clean
fi

APP="dist/CloakBrowser Manager.app"
DMG="dist/CloakBrowser-Manager-${VERSION}.dmg"
STAGING="dist/dmg-staging"
[[ -d "$APP" ]] || { echo "Missing $APP" >&2; exit 1; }

echo "==> dmg"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -sf /Applications "$STAGING/Applications"
hdiutil create -volname "CloakBrowser Manager" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
rm -rf "$STAGING"
echo "=> $DMG"
