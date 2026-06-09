#!/bin/zsh
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source "$SCRIPT_DIR/release-support.sh"
APP_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
DIST_DIR="${WORDZ_MAC_DIST_DIR:-$APP_ROOT/dist-native}"
APP_NAME="${WORDZ_MAC_APP_NAME:-WordZ}"
VERSION="$(release_support_current_version)"
ARCH_NAME="${WORDZ_MAC_ARCH:-$(uname -m)}"
APP_BUNDLE=$(bash "$SCRIPT_DIR/build-app.sh" | tail -n 1)
zsh "$SCRIPT_DIR/package-from-app.sh" "$APP_BUNDLE" "$APP_NAME" "$VERSION" "$DIST_DIR" "$ARCH_NAME"
