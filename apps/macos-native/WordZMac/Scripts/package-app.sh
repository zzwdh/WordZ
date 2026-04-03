#!/bin/zsh
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
APP_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$APP_ROOT/../../.." && pwd)
DIST_DIR="${WORDZ_MAC_DIST_DIR:-$APP_ROOT/dist-native}"
APP_NAME="${WORDZ_MAC_APP_NAME:-WordZ}"
VERSION="${WORDZ_MAC_VERSION:-$(node -p "require('$REPO_ROOT/package.json').version")}"
ARCH_NAME="${WORDZ_MAC_ARCH:-$(uname -m)}"
APP_BUNDLE=$(bash "$SCRIPT_DIR/build-app.sh" | tail -n 1)
ZIP_PATH="$DIST_DIR/${APP_NAME}-${VERSION}-mac-${ARCH_NAME}.zip"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}-mac-${ARCH_NAME}.dmg"
STAGING_DIR=$(mktemp -d "${TMPDIR:-/tmp}/wordz-native-dmg.XXXXXX")

rm -f "$ZIP_PATH" "$DMG_PATH"

ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH" >/dev/null
rm -rf "$STAGING_DIR"

CHECKSUMS_AND_MANIFEST=($(zsh "$SCRIPT_DIR/release-manifest.sh" "$APP_NAME" "$VERSION" "$DIST_DIR" "$ARCH_NAME"))
CHECKSUMS_PATH="${CHECKSUMS_AND_MANIFEST[1]}"
MANIFEST_PATH="${CHECKSUMS_AND_MANIFEST[2]}"

echo "$APP_BUNDLE"
echo "$ZIP_PATH"
echo "$DMG_PATH"
echo "$CHECKSUMS_PATH"
echo "$MANIFEST_PATH"
