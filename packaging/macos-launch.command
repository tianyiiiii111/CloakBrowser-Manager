#!/bin/bash
# Portable launcher: clear quarantine (if any) and open the app. No installation.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$DIR/CloakBrowser Manager.app"

if [[ ! -d "$APP" ]]; then
  osascript -e 'display alert "找不到 CloakBrowser Manager.app" as critical'
  exit 1
fi

xattr -cr "$APP" 2>/dev/null || true
open "$APP"
