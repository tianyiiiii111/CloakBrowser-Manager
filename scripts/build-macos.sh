#!/usr/bin/env bash
# Build macOS Intel (x86_64) distributable (.dmg + zip for in-app update). Run on macOS only.
#
# Usage:
#   ./scripts/build-macos.sh
#   ./scripts/build-macos.sh --package-only
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(grep -E '^version\s*=' pyproject.toml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
PACKAGE_ONLY=false
ARCH="x86_64"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --package-only|-p) PACKAGE_ONLY=true ;;
    --arch)
      shift
      ARCH="${1:?--arch requires x86_64}"
      if [[ "$ARCH" != "x86_64" ]]; then
        echo "Only x86_64 (Intel) macOS builds are supported." >&2
        exit 1
      fi
      ;;
    --all-archs)
      echo "--all-archs is no longer supported (Apple Silicon builds removed)." >&2
      exit 1
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "build-macos.sh must run on macOS." >&2
  exit 1
fi

PYTHON="${PYTHON:-}"
if command -v python3 &>/dev/null; then PYTHON=python3
elif command -v python &>/dev/null; then PYTHON=python
else echo "python not found" >&2; exit 1; fi

python_machine() {
  "$1" -c 'import platform; print(platform.machine().lower())'
}

USE_ROSETTA=false
run_wrapped() {
  if $USE_ROSETTA; then
    arch -x86_64 "$@"
  else
    "$@"
  fi
}

pm="$(python_machine "$PYTHON")"
case "$pm" in
  arm64) USE_ROSETTA=true ;;
  x86_64|amd64) USE_ROSETTA=false ;;
  *) echo "Unsupported Python arch: $pm" >&2; exit 1 ;;
esac

if ! $PACKAGE_ONLY; then
  echo "==> frontend"
  (cd frontend && npm ci && npm run build)
fi

venv=".venv-build-${ARCH}"
if ! $PACKAGE_ONLY; then
  if [[ ! -d "$venv" ]]; then
    echo "==> python (${ARCH})"
    run_wrapped "$PYTHON" -m venv "$venv"
  fi
  run_wrapped "$venv/bin/pip" install -q -r packaging/requirements-desktop.txt

  echo "==> pyinstaller (${ARCH})"
  PYINSTALLER_TARGET_ARCH="$ARCH" run_wrapped "$venv/bin/pyinstaller" \
    packaging/cloakbrowser-manager.spec \
    --noconfirm --clean \
    --distpath "dist-${ARCH}" \
    --workpath "build-${ARCH}"
fi

distpath="dist-${ARCH}"
app="${distpath}/CloakBrowser Manager.app"
dmg="dist/CloakBrowser-Manager-${VERSION}-${ARCH}.dmg"
zip="dist/CloakBrowser-Manager-${VERSION}-${ARCH}.zip"
staging="dist/dmg-staging-${ARCH}"
macos_bin="${app}/Contents/MacOS"

[[ -d "$app" ]] || { echo "Missing $app" >&2; exit 1; }

echo "$VERSION" > "${macos_bin}/version.txt"

echo "==> zip (${ARCH}, in-app update)"
rm -f "$zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"
echo "=> $zip"

echo "==> dmg (${ARCH})"
rm -rf "$staging" "$dmg"
mkdir -p "$staging"
cp -R "$app" "$staging/"
ln -sf /Applications "$staging/Applications"
hdiutil create -volname "CloakBrowser Manager" -srcfolder "$staging" -ov -format UDZO "$dmg"
rm -rf "$staging"
echo "=> $dmg"
