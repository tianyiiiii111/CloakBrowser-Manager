#!/usr/bin/env bash
# Build macOS Intel (x86_64) portable zip. Run on macOS only.
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
zip="dist/CloakBrowser-Manager-${VERSION}-${ARCH}.zip"
staging="dist/zip-staging-${ARCH}"
macos_bin="${app}/Contents/MacOS"

[[ -d "$app" ]] || { echo "Missing $app" >&2; exit 1; }

echo "$VERSION" > "${macos_bin}/version.txt"

echo "==> codesign"
chmod +x scripts/codesign-macos-app.sh
./scripts/codesign-macos-app.sh "$app"

echo "==> portable zip (${ARCH})"
rm -rf "$staging" "$zip"
mkdir -p "$staging"
ditto "$app" "$staging/CloakBrowser Manager.app"
cp packaging/macos-launch.command "$staging/CloakBrowser Manager.command"
chmod +x "$staging/CloakBrowser Manager.command"
(
  cd "$staging"
  ditto -c -k --sequesterRsrc --keepParent \
    "CloakBrowser Manager.app" \
    "CloakBrowser Manager.command" \
    "../$(basename "$zip")"
)
rm -rf "$staging"
echo "=> $zip"
echo "解压后双击 CloakBrowser Manager.app 或 CloakBrowser Manager.command（免安装，支持应用内一键更新）"

if [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
  echo "==> notarize"
  chmod +x scripts/notarize-macos-zip.sh
  ./scripts/notarize-macos-zip.sh "$zip"
fi
