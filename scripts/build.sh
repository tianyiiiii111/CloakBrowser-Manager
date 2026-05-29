#!/usr/bin/env bash
# Dispatch to platform build script.
# Usage: ./scripts/build.sh [--package-only]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

case "$(uname -s)" in
  Darwin)
    exec "$SCRIPT_DIR/build-macos.sh" "$@"
    ;;
  MINGW*|MSYS*|CYGWIN*)
    args=()
    [[ "${1:-}" == "--package-only" || "${1:-}" == "-p" ]] && args+=(-PackageOnly)
    exec pwsh -NoProfile -File "$SCRIPT_DIR/build-windows.ps1" "${args[@]}"
    ;;
  *)
    if [[ "${OS:-}" == "Windows_NT" ]]; then
      args=()
      [[ "${1:-}" == "--package-only" || "${1:-}" == "-p" ]] && args+=(-PackageOnly)
      exec pwsh -NoProfile -File "$SCRIPT_DIR/build-windows.ps1" "${args[@]}"
    fi
    echo "Use build-macos.sh on macOS or build-windows.ps1 on Windows." >&2
    exit 1
    ;;
esac
