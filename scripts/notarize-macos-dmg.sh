#!/usr/bin/env bash
# Notarize and staple a macOS DMG (requires Apple Developer credentials).
set -euo pipefail

DMG="${1:?usage: notarize-macos-dmg.sh /path/to/file.dmg}"

: "${APPLE_ID:?APPLE_ID is required}"
: "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required}"

if [[ -z "${APPLE_APP_SPECIFIC_PASSWORD:-}" && -z "${APPLE_NOTARIZATION_PASSWORD:-}" ]]; then
  echo "Set APPLE_APP_SPECIFIC_PASSWORD or APPLE_NOTARIZATION_PASSWORD" >&2
  exit 1
fi
NOTARY_PASSWORD="${APPLE_APP_SPECIFIC_PASSWORD:-$APPLE_NOTARIZATION_PASSWORD}"

echo "==> notarytool submit $(basename "$DMG")"
xcrun notarytool submit "$DMG" \
  --apple-id "$APPLE_ID" \
  --password "$NOTARY_PASSWORD" \
  --team-id "$APPLE_TEAM_ID" \
  --wait

echo "==> stapler staple $(basename "$DMG")"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
