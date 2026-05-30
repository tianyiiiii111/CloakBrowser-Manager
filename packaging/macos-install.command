#!/bin/bash
# Install CloakBrowser Manager and clear Gatekeeper quarantine attributes.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$DIR/CloakBrowser Manager.app"
TARGET="/Applications/CloakBrowser Manager.app"

if [[ ! -d "$APP" ]]; then
  echo "找不到 CloakBrowser Manager.app" >&2
  exit 1
fi

echo "正在清除隔离属性…"
xattr -cr "$APP" 2>/dev/null || true

echo "正在安装到「应用程序」…"
ditto "$APP" "$TARGET"
xattr -cr "$TARGET" 2>/dev/null || true

echo "正在启动…"
open "$TARGET"
echo "安装完成，可以推出磁盘映像。"
