#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

APP_NAME="AINotch Island"
EXPORT_PATH="build/release"
DMG_PATH="build/${APP_NAME}.dmg"
TMP_DMG="build/tmp-dmg.dmg"
VOLUME_NAME="$APP_NAME"

APP_PATH="$EXPORT_PATH/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH not found. Run build-release.sh first."
    exit 1
fi

echo "=== Creating DMG ==="
rm -f "$TMP_DMG" "$DMG_PATH"

hdiutil create -volname "$VOLUME_NAME" \
  -srcfolder "$APP_PATH" \
  -ov -format UDRW "$TMP_DMG"

DEVICE=$(hdiutil attach -readwrite -noverify "$TMP_DMG" | \
  awk '/Apple_HFS|APFS/ {print $1; exit}')
MOUNT_POINT="/Volumes/$VOLUME_NAME"

ln -sf /Applications "$MOUNT_POINT/Applications"

sync
sleep 1
hdiutil detach "$DEVICE"

hdiutil convert "$TMP_DMG" -format UDZO -o "$DMG_PATH"
rm -f "$TMP_DMG"

# Optional notarization — only run when AINOTCH_NOTARIZE=1 and credentials are
# available. Open-source ad-hoc builds skip this entirely.
if [ "${AINOTCH_NOTARIZE:-0}" = "1" ]; then
    echo "=== Notarizing DMG ==="
    xcrun notarytool submit "$DMG_PATH" \
      --team-id "YOUR_TEAM_ID" \
      --wait \
      --keychain-profile "notarytool-profile"
    xcrun stapler staple "$DMG_PATH"
fi

echo "=== Done ==="
echo "DMG: $DMG_PATH"
