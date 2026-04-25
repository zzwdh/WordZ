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
zsh "$SCRIPT_DIR/package-from-app.sh" "$APP_BUNDLE" "$APP_NAME" "$VERSION" "$DIST_DIR" "$ARCH_NAME"
