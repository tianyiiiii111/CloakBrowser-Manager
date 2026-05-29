#!/usr/bin/env bash
# Build distributable: macOS .dmg or Windows Setup .exe (run on target OS).
# Usage: ./scripts/build.sh [--package-only]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(grep -E '^version\s*=' pyproject.toml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
PACKAGE_ONLY=false
[[ "${1:-}" == "--package-only" || "${1:-}" == "-p" ]] && PACKAGE_ONLY=true

is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }
is_windows() {
  case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*|Windows_NT) return 0 ;; esac
  [[ "${OS:-}" == "Windows_NT" ]]
}

if ! is_macos && ! is_windows; then
  echo "Run on macOS (DMG) or Windows Git Bash (Setup.exe)." >&2
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
  if is_windows; then source .venv-build/Scripts/activate
  else source .venv-build/bin/activate; fi
  pip install -q -r packaging/requirements-desktop.txt

  echo "==> pyinstaller"
  pyinstaller packaging/cloakbrowser-manager.spec --noconfirm --clean
fi

if is_macos; then
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
else
  APP_DIR="dist/CloakBrowser Manager"
  EXE="${APP_DIR}/CloakBrowser Manager.exe"
  OUT="dist/CloakBrowser-Manager-${VERSION}-Setup.exe"
  [[ -f "$EXE" ]] || { echo "Missing $EXE" >&2; exit 1; }
  ISCC=""
  if command -v ISCC.exe &>/dev/null; then
    ISCC="$(command -v ISCC.exe)"
  elif command -v iscc &>/dev/null; then
    ISCC="$(command -v iscc)"
  else
    for c in \
      "/c/Program Files (x86)/Inno Setup 6/ISCC.exe" \
      "/c/Program Files/Inno Setup 6/ISCC.exe"
    do
      if [[ -f "$c" ]]; then ISCC="$c"; break; fi
    done
    if [[ -z "$ISCC" && -n "${PROGRAMFILES:-}" ]]; then
      c="${PROGRAMFILES}/Inno Setup 6/ISCC.exe"
      [[ -f "$c" ]] && ISCC="$c"
    fi
    if [[ -z "$ISCC" ]]; then
      pf86="$(cmd.exe //c "echo %PROGRAMFILES(X86)%" 2>/dev/null | tr -d '\r')"
      c="${pf86}/Inno Setup 6/ISCC.exe"
      [[ -f "$c" ]] && ISCC="$c"
    fi
  fi
  [[ -n "$ISCC" ]] || { echo "Inno Setup 6 required: https://jrsoftware.org/isinfo.php" >&2; exit 1; }
  echo "==> installer"
  # Git Bash converts /D... to a Windows path; invoke via cmd.exe to pass /D defines correctly
  iss_win="$(cygpath -w "$ROOT/packaging/windows/installer.iss")"
  iscc_win="$(cygpath -w "$ISCC")"
  cmd.exe //c "\"${iscc_win}\" /DMyAppVersion=${VERSION} \"${iss_win}\""
  [[ -f "$OUT" ]] || { echo "Build failed: $OUT" >&2; exit 1; }
  echo "=> $OUT"
fi
