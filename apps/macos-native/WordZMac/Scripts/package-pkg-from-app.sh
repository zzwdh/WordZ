#!/bin/zsh
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

if [[ $# -lt 4 ]]; then
  echo "usage: $0 <app-bundle> <app-name> <version> <dist-dir> [arch]" >&2
  exit 1
fi

APP_BUNDLE="$1"
APP_NAME="$2"
VERSION="$3"
DIST_DIR="$4"
ARCH_NAME="${5:-$(uname -m)}"
PKG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}-mac-${ARCH_NAME}.pkg"
PKG_TEMP_PATH="$DIST_DIR/.${APP_NAME}-${VERSION}-mac-${ARCH_NAME}.pkg"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
APP_IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST" 2>/dev/null || true)"
PKG_IDENTIFIER="${WORDZ_MAC_PKG_IDENTIFIER:-${APP_IDENTIFIER:-com.zzwdh.wordz.native}.pkg}"
PKG_INSTALL_LOCATION="${WORDZ_MAC_PKG_INSTALL_LOCATION:-/Applications}"
PKG_SIGN_IDENTITY="${WORDZ_MAC_INSTALLER_SIGN_IDENTITY:-}"

[[ -d "$APP_BUNDLE" ]] || { echo "app bundle not found: $APP_BUNDLE" >&2; exit 1; }
[[ -f "$INFO_PLIST" ]] || { echo "Info.plist not found: $INFO_PLIST" >&2; exit 1; }
mkdir -p "$DIST_DIR"
rm -f "$PKG_TEMP_PATH"

pkgbuild_args=(
  --component "$APP_BUNDLE"
  --install-location "$PKG_INSTALL_LOCATION"
  --identifier "$PKG_IDENTIFIER"
  --version "$VERSION"
)
if [[ -n "$PKG_SIGN_IDENTITY" ]]; then
  pkgbuild_args+=(--sign "$PKG_SIGN_IDENTITY")
fi
pkgbuild "${pkgbuild_args[@]}" "$PKG_TEMP_PATH" >/dev/null
mv -f "$PKG_TEMP_PATH" "$PKG_PATH"

echo "$PKG_PATH"
