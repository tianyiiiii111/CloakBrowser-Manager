#!/usr/bin/env bash
# Build macOS distributable (.dmg). Run on macOS only.
#
# Usage:
#   ./scripts/build-macos.sh              # native arch only (arm64 or x86_64)
#   ./scripts/build-macos.sh --all-archs  # Apple Silicon + Intel DMGs (CI)
#   ./scripts/build-macos.sh --package-only
#   ./scripts/build-macos.sh --arch x86_64
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(grep -E '^version\s*=' pyproject.toml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
PACKAGE_ONLY=false
ALL_ARCHS=false
REQUESTED_ARCH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --package-only|-p) PACKAGE_ONLY=true ;;
    --all-archs) ALL_ARCHS=true ;;
    --arch)
      shift
      REQUESTED_ARCH="${1:?--arch requires arm64 or x86_64}"
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "build-macos.sh must run on macOS." >&2
  exit 1
fi

native_arch() {
  case "$(uname -m)" in
    arm64) echo arm64 ;;
    x86_64) echo x86_64 ;;
    *) echo "Unsupported macOS arch: $(uname -m)" >&2; exit 1 ;;
  esac
}

PYTHON="${PYTHON:-}"
if command -v python3 &>/dev/null; then PYTHON=python3
elif command -v python &>/dev/null; then PYTHON=python
else echo "python not found" >&2; exit 1; fi

ARCHS=()
if $ALL_ARCHS; then
  ARCHS=(arm64 x86_64)
elif [[ -n "$REQUESTED_ARCH" ]]; then
  ARCHS=("$REQUESTED_ARCH")
else
  ARCHS=("$(native_arch)")
fi

for arch in "${ARCHS[@]}"; do
  if [[ "$arch" != "arm64" && "$arch" != "x86_64" ]]; then
    echo "Invalid arch: $arch (use arm64 or x86_64)" >&2
    exit 1
  fi
done

if ! $PACKAGE_ONLY; then
  echo "==> frontend"
  (cd frontend && npm ci && npm run build)

  echo "==> python"
  [[ -d .venv-build ]] || "$PYTHON" -m venv .venv-build
  # shellcheck disable=SC1091
  source .venv-build/bin/activate
  pip install -q -r packaging/requirements-desktop.txt
fi

make_dmg() {
  local arch="$1"
  local distpath="dist-${arch}"
  local workpath="build-${arch}"
  local app="${distpath}/CloakBrowser Manager.app"
  local dmg="dist/CloakBrowser-Manager-${VERSION}-${arch}.dmg"
  local staging="dist/dmg-staging-${arch}"

  if ! $PACKAGE_ONLY; then
    echo "==> pyinstaller (${arch})"
    PYINSTALLER_TARGET_ARCH="$arch" pyinstaller packaging/cloakbrowser-manager.spec \
      --noconfirm --clean \
      --distpath "$distpath" \
      --workpath "$workpath"
  fi

  [[ -d "$app" ]] || { echo "Missing $app" >&2; exit 1; }

  echo "==> dmg (${arch})"
  rm -rf "$staging" "$dmg"
  mkdir -p "$staging"
  cp -R "$app" "$staging/"
  ln -sf /Applications "$staging/Applications"
  hdiutil create -volname "CloakBrowser Manager" -srcfolder "$staging" -ov -format UDZO "$dmg"
  rm -rf "$staging"
  echo "=> $dmg"
}

for arch in "${ARCHS[@]}"; do
  make_dmg "$arch"
done
