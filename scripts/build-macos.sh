#!/usr/bin/env bash
# Build macOS distributable (.dmg). Run on macOS only.
#
# Usage:
#   ./scripts/build-macos.sh              # native arch only
#   ./scripts/build-macos.sh --arch arm64|x86_64
#   ./scripts/build-macos.sh --all-archs  # both (needs x86_64-capable Python via Rosetta on Apple Silicon)
#   ./scripts/build-macos.sh --package-only
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

python_machine() {
  "$1" -c 'import platform; print(platform.machine().lower())'
}

# Run commands under Rosetta when host Python is arm64 but we need an x86_64 venv.
USE_ROSETTA=false

run_wrapped() {
  if $USE_ROSETTA; then
    arch -x86_64 "$@"
  else
    "$@"
  fi
}

arch_wrapper() {
  USE_ROSETTA=false
  local target_arch="$1"
  local py="$2"
  local pm
  pm="$(python_machine "$py")"
  case "$pm" in
    arm64) pm=arm64 ;;
    x86_64|amd64) pm=x86_64 ;;
    *) echo "Unsupported Python arch: $pm" >&2; return 1 ;;
  esac
  if [[ "$target_arch" == "$pm" ]]; then
    return 0
  fi
  if [[ "$(uname -m)" == "arm64" && "$target_arch" == "x86_64" ]]; then
    USE_ROSETTA=true
    return 0
  fi
  echo "Python is ${pm} but target arch is ${target_arch}. Install matching Python (CI: setup-python with architecture: x64)." >&2
  return 1
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
fi

setup_venv() {
  local arch="$1"
  local venv=".venv-build-${arch}"
  arch_wrapper "$arch" "$PYTHON"

  if [[ ! -d "$venv" ]]; then
    echo "==> python (${arch})"
    run_wrapped "$PYTHON" -m venv "$venv"
  fi
  run_wrapped "$venv/bin/pip" install -q -r packaging/requirements-desktop.txt
}

make_dmg() {
  local arch="$1"
  local venv=".venv-build-${arch}"
  local distpath="dist-${arch}"
  local workpath="build-${arch}"
  local app="${distpath}/CloakBrowser Manager.app"
  local dmg="dist/CloakBrowser-Manager-${VERSION}-${arch}.dmg"
  local staging="dist/dmg-staging-${arch}"

  if ! $PACKAGE_ONLY; then
    setup_venv "$arch"
    echo "==> pyinstaller (${arch})"
    PYINSTALLER_TARGET_ARCH="$arch" run_wrapped "$venv/bin/pyinstaller" \
      packaging/cloakbrowser-manager.spec \
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
