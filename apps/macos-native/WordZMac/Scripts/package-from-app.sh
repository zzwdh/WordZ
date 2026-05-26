#!/bin/zsh
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

if [[ $# -lt 4 ]]; then
  echo "usage: $0 <app-bundle> <app-name> <version> <dist-dir> [arch]" >&2
  exit 1
fi

APP_BUNDLE="$1"
APP_NAME="$2"
VERSION="$3"
DIST_DIR="$4"
ARCH_NAME="${5:-$(uname -m)}"
ZIP_PATH="$DIST_DIR/${APP_NAME}-${VERSION}-mac-${ARCH_NAME}.zip"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}-mac-${ARCH_NAME}.dmg"
ZIP_TEMP_PATH="$DIST_DIR/.${APP_NAME}-${VERSION}-mac-${ARCH_NAME}.zip"
DMG_TEMP_PATH="$DIST_DIR/.${APP_NAME}-${VERSION}-mac-${ARCH_NAME}.dmg"
PKG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}-mac-${ARCH_NAME}.pkg"
STAGING_DIR=$(mktemp -d "${TMPDIR:-/tmp}/wordz-native-dmg.XXXXXX")

cleanup() {
  rm -rf "$STAGING_DIR"
  rm -f "$ZIP_TEMP_PATH" "$DMG_TEMP_PATH"
}
trap cleanup EXIT

[[ -d "$APP_BUNDLE" ]] || { echo "app bundle not found: $APP_BUNDLE" >&2; exit 1; }
mkdir -p "$DIST_DIR"
rm -f "$ZIP_TEMP_PATH" "$DMG_TEMP_PATH"

ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_TEMP_PATH"
mv -f "$ZIP_TEMP_PATH" "$ZIP_PATH"

PKG_PATH="$(zsh "$SCRIPT_DIR/package-pkg-from-app.sh" "$APP_BUNDLE" "$APP_NAME" "$VERSION" "$DIST_DIR" "$ARCH_NAME" | tail -n 1)"

cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_TEMP_PATH" >/dev/null
mv -f "$DMG_TEMP_PATH" "$DMG_PATH"

CHECKSUMS_AND_MANIFEST=("${(@f)$(zsh "$SCRIPT_DIR/release-manifest.sh" "$APP_NAME" "$VERSION" "$DIST_DIR" "$ARCH_NAME")}")
CHECKSUMS_PATH="${CHECKSUMS_AND_MANIFEST[1]}"
MANIFEST_PATH="${CHECKSUMS_AND_MANIFEST[2]}"

echo "$APP_BUNDLE"
echo "$ZIP_PATH"
echo "$DMG_PATH"
echo "$PKG_PATH"
echo "$CHECKSUMS_PATH"
echo "$MANIFEST_PATH"
