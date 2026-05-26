#!/bin/bash
# build-release-opensource.sh
#
# Build a redistributable .app + .dmg using only an ad-hoc signature.
# No Apple Developer ID, no notarization. Anyone can download the DMG
# and run the app, but Gatekeeper will prompt them to right-click →
# Open the first time. This is the standard distribution path for
# open-source macOS utilities.
#
# Output: build/release/AINotch Island.app and build/AINotch Island.dmg
#
# Usage:
#   ./scripts/build-release-opensource.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

SCHEME="AINotchIsland"
PROJECT="AINotchIsland.xcodeproj"
ARCHIVE_PATH="build/AINotchIsland.xcarchive"
EXPORT_PATH="build/release"
APP_NAME="AINotch Island"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"

mkdir -p build

echo "=== [1/5] Building bridge binary ==="
./Bridge/build-bridge.sh

echo ""
echo "=== [2/5] Archiving Release config (ad-hoc signing) ==="
# Strip Developer ID requirements — Release config still produces a
# proper .xcarchive, just with ad-hoc signatures everywhere.
rm -rf "$ARCHIVE_PATH"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -quiet

echo ""
echo "=== [3/5] Exporting .app from archive ==="
rm -rf "$EXPORT_PATH"
mkdir -p "$EXPORT_PATH"
# Copy directly out of the archive — exportArchive with adhoc plist
# is finicky in current Xcode and we don't need its post-processing.
cp -R "$ARCHIVE_PATH/Products/Applications/$APP_NAME.app" "$EXPORT_PATH/"

echo ""
echo "=== [4/5] Re-signing app + frameworks (ad-hoc, deep) ==="
# Xcode archives sometimes materialize framework symlinks (Versions/Current,
# top-level binary, top-level Resources) as real directories/files. Codesign
# then treats Versions/Current as its own bundle and fails with
# "sealed resource is missing". Rebuild the standard framework layout
# before signing.
if [ -d "$APP_PATH/Contents/Frameworks" ]; then
    for fw in "$APP_PATH/Contents/Frameworks"/*.framework; do
        [ -d "$fw" ] || continue
        # Pick the version dir (A, B, etc.) that isn't "Current".
        VERSION_DIR=$(ls "$fw/Versions" 2>/dev/null | grep -v '^Current$' | head -1)
        if [ -n "$VERSION_DIR" ]; then
            # Versions/Current must be a symlink, not a real dir.
            if [ -d "$fw/Versions/Current" ] && [ ! -L "$fw/Versions/Current" ]; then
                rm -rf "$fw/Versions/Current"
                ln -s "$VERSION_DIR" "$fw/Versions/Current"
            fi
            # Top-level binary: should be a symlink to Versions/Current/<binary>.
            BIN_NAME=$(basename "$fw" .framework)
            if [ -e "$fw/$BIN_NAME" ] && [ ! -L "$fw/$BIN_NAME" ]; then
                rm -rf "$fw/$BIN_NAME"
                (cd "$fw" && ln -s "Versions/Current/$BIN_NAME" "$BIN_NAME")
            fi
            # Top-level Resources: same treatment.
            if [ -e "$fw/Resources" ] && [ ! -L "$fw/Resources" ]; then
                rm -rf "$fw/Resources"
                (cd "$fw" && ln -s "Versions/Current/Resources" "Resources")
            fi
        fi
    done

    # Sign nested .app/.xpc inside any framework first (e.g. Sparkle Updater.app).
    find "$APP_PATH/Contents/Frameworks" -type d \( -name "*.app" -o -name "*.xpc" \) | while read -r sub; do
        codesign --force --sign - --deep "$sub" 2>&1 | grep -v "replacing existing signature" || true
    done

    # Then sign the frameworks themselves.
    for fw in "$APP_PATH/Contents/Frameworks"/*.framework; do
        [ -d "$fw" ] || continue
        codesign --force --sign - "$fw" 2>&1 | grep -v "replacing existing signature" || true
    done
fi
# Sign embedded helper binaries (the bridge, for example).
if [ -d "$APP_PATH/Contents/Resources" ]; then
    find "$APP_PATH/Contents/Resources" -type f -perm +111 | while read -r exe; do
        codesign --force --sign - "$exe" 2>&1 | grep -v "replacing existing signature" || true
    done
fi
codesign --force --sign - "$APP_PATH"

echo ""
echo "=== [5/5] Building DMG ==="
./scripts/build-dmg.sh

echo ""
echo "=========================================="
echo "Done. Artifacts:"
echo "  App: $APP_PATH"
echo "  DMG: build/$APP_NAME.dmg"
echo ""
echo "Distribution notes for users:"
echo "  - On first launch macOS will say the app is from an"
echo "    unidentified developer."
echo "  - Tell users to right-click the .app → Open → confirm."
echo "    From then on it launches normally."
echo "=========================================="
