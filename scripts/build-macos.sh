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

echo "==> codesign"
chmod +x scripts/codesign-macos-app.sh
./scripts/codesign-macos-app.sh "$app"

echo "==> zip (${ARCH}, in-app update)"
rm -f "$zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"
echo "=> $zip"

echo "==> dmg (${ARCH})"
rm -rf "$staging" "$dmg"
mkdir -p "$staging"
ditto "$app" "$staging/CloakBrowser Manager.app"
cp packaging/macos-install.command "$staging/Install.command"
chmod +x "$staging/Install.command"
cat > "$staging/安装说明.txt" <<'EOF'
若拖入「应用程序」后提示「已损坏，无法打开」，这是 macOS 对未签名应用的安全拦截（并非文件损坏）。

推荐安装方式：
1. 双击本磁盘中的 Install.command
2. 若仍被拦截：在「终端」执行
   xattr -cr "/Applications/CloakBrowser Manager.app"
   open "/Applications/CloakBrowser Manager.app"

也可右键应用 →「打开」→ 确认打开（仅首次需要）。
EOF
ln -sf /Applications "$staging/Applications"
hdiutil create -volname "CloakBrowser Manager" -srcfolder "$staging" -ov -format UDZO "$dmg"
rm -rf "$staging"
echo "=> $dmg"

if [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
  echo "==> notarize"
  chmod +x scripts/notarize-macos-dmg.sh
  ./scripts/notarize-macos-dmg.sh "$dmg"
fi
