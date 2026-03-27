#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
APP_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$APP_ROOT/../../.." && pwd)
DIST_DIR="${WORDZ_MAC_DIST_DIR:-$REPO_ROOT/dist-native}"
APP_NAME="${WORDZ_MAC_APP_NAME:-WordZ}"
BUNDLE_ID="${WORDZ_MAC_BUNDLE_ID:-com.zzwdh.wordz.native}"
VERSION="${WORDZ_MAC_VERSION:-$(node -p "require('$REPO_ROOT/package.json').version")}"
BUILD_NUMBER="${WORDZ_MAC_BUILD_NUMBER:-$(date +%Y%m%d%H%M%S)}"
ARCH_NAME="${WORDZ_MAC_ARCH:-$(uname -m)}"
SWIFT_PRODUCT="${WORDZ_MAC_SWIFT_PRODUCT:-WordZMac}"
SIGN_IDENTITY="${WORDZ_MAC_SIGN_IDENTITY:-}"
ENTITLEMENTS_PATH="${WORDZ_MAC_ENTITLEMENTS_PATH:-$REPO_ROOT/build/entitlements.mac.plist}"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
LOCAL_HOME="${WORDZ_MAC_LOCAL_HOME:-$APP_ROOT/.release-home}"
LOCAL_CLANG_CACHE="${WORDZ_MAC_LOCAL_CLANG_CACHE:-$APP_ROOT/.release-clang-cache}"
LOCAL_SWIFTPM_CACHE="${WORDZ_MAC_LOCAL_SWIFTPM_CACHE:-$APP_ROOT/.release-swiftpm-cache}"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
CONTENTS_DIR="$APP_BUNDLE/Contents"
BUILD_INFO_PATH="$RESOURCES_DIR/WordZMacBuildInfo.json"

mkdir -p "$DIST_DIR"
mkdir -p "$LOCAL_HOME" "$LOCAL_CLANG_CACHE" "$LOCAL_SWIFTPM_CACHE"
rm -rf "$APP_BUNDLE"

HOME="$LOCAL_HOME" CLANG_MODULE_CACHE_PATH="$LOCAL_CLANG_CACHE" SWIFTPM_MODULECACHE_OVERRIDE="$LOCAL_SWIFTPM_CACHE" \
swift build --package-path "$APP_ROOT" -c release --product "$SWIFT_PRODUCT"

BIN_PATH=$(
  HOME="$LOCAL_HOME" CLANG_MODULE_CACHE_PATH="$LOCAL_CLANG_CACHE" SWIFTPM_MODULECACHE_OVERRIDE="$LOCAL_SWIFTPM_CACHE" \
  swift build --package-path "$APP_ROOT" -c release --product "$SWIFT_PRODUCT" --show-bin-path
)
EXECUTABLE_PATH="$BIN_PATH/$SWIFT_PRODUCT"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR/WordZMacScripts"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$SWIFT_PRODUCT"
chmod +x "$MACOS_DIR/$SWIFT_PRODUCT"

if [[ -f "$REPO_ROOT/build/icon.icns" ]]; then
  cp "$REPO_ROOT/build/icon.icns" "$RESOURCES_DIR/$APP_NAME.icns"
fi

cp "$APP_ROOT/Scripts/export-xlsx.mjs" "$RESOURCES_DIR/WordZMacScripts/export-xlsx.mjs"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$SWIFT_PRODUCT</string>
  <key>CFBundleIconFile</key>
  <string>$APP_NAME.icns</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 邹羽轩</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeExtensions</key>
      <array><string>txt</string></array>
      <key>CFBundleTypeName</key>
      <string>WordZ Text Corpus</string>
      <key>CFBundleTypeRole</key>
      <string>Editor</string>
    </dict>
    <dict>
      <key>CFBundleTypeExtensions</key>
      <array><string>docx</string></array>
      <key>CFBundleTypeName</key>
      <string>WordZ DOCX Corpus</string>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
    </dict>
    <dict>
      <key>CFBundleTypeExtensions</key>
      <array><string>pdf</string></array>
      <key>CFBundleTypeName</key>
      <string>WordZ PDF Corpus</string>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
    </dict>
  </array>
</dict>
</plist>
PLIST

cat > "$BUILD_INFO_PATH" <<JSON
{
  "appName": "$APP_NAME",
  "bundleIdentifier": "$BUNDLE_ID",
  "version": "$VERSION",
  "buildNumber": "$BUILD_NUMBER",
  "architecture": "$ARCH_NAME",
  "builtAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSON

if [[ -n "$SIGN_IDENTITY" ]]; then
  if [[ -f "$ENTITLEMENTS_PATH" ]]; then
    codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp --entitlements "$ENTITLEMENTS_PATH" "$APP_BUNDLE"
  else
    codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp "$APP_BUNDLE"
  fi
elif [[ "${WORDZ_MAC_ADHOC_SIGN:-1}" != "0" ]]; then
  codesign --force --sign - "$APP_BUNDLE"
fi

echo "$APP_BUNDLE"
