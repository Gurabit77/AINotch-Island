#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

TEAM_ID="YOUR_TEAM_ID"
SCHEME="AINotchIsland"
PROJECT="AINotchIsland.xcodeproj"
ARCHIVE_PATH="build/AINotchIsland.xcarchive"
EXPORT_PATH="build/release"

echo "=== Building bridge binary ==="
./Bridge/build-bridge.sh

echo "=== Archiving with Release config ==="
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  DEVELOPMENT_TEAM="$TEAM_ID"

echo "=== Exporting archive ==="
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist scripts/ExportOptions.plist

APP_PATH="$EXPORT_PATH/AINotch Island.app"

echo "=== Notarizing ==="
xcrun notarytool submit "$APP_PATH" \
  --team-id "$TEAM_ID" \
  --wait \
  --keychain-profile "notarytool-profile"

echo "=== Stapling ==="
xcrun stapler staple "$APP_PATH"

echo "=== Done ==="
echo "Release app: $APP_PATH"
