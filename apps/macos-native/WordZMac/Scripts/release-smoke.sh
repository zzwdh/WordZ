#!/bin/zsh
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

usage() {
  echo "usage: $0 [<manifest-or-dist-dir>]" >&2
  exit 1
}

resolve_manifest_path() {
  local input_path="${1:-}"
  if [[ -z "$input_path" ]]; then
    local dist_dir="$(cd "$(dirname "$0")/.." && pwd)/dist-native"
    input_path="$dist_dir"
  fi

  if [[ -d "$input_path" ]]; then
    local latest_manifest
    latest_manifest="$(/bin/ls -t "$input_path"/*.manifest.json 2>/dev/null | /usr/bin/head -n 1)"
    if [[ -z "$latest_manifest" ]]; then
      echo "no manifest found in $input_path" >&2
      exit 1
    fi
    echo "$latest_manifest"
    return
  fi

  if [[ "$input_path" == *.checksums.txt ]]; then
    echo "${input_path%.checksums.txt}.manifest.json"
    return
  fi

  echo "$input_path"
}

read_json_value() {
  local path="$1"
  local key="$2"
  /usr/bin/plutil -extract "$key" raw -o - "$path" 2>/dev/null
}

if [[ "${1:-}" == "--help" ]]; then
  usage
fi

MANIFEST_PATH="$(resolve_manifest_path "${1:-}")"
if [[ ! -f "$MANIFEST_PATH" ]]; then
  echo "manifest not found: $MANIFEST_PATH" >&2
  exit 1
fi

DIST_DIR="$(cd "$(dirname "$MANIFEST_PATH")" && pwd)"
APP_NAME="$(read_json_value "$MANIFEST_PATH" appName)"
VERSION="$(read_json_value "$MANIFEST_PATH" version)"
ARCHITECTURE="$(read_json_value "$MANIFEST_PATH" architecture)"
CHECKSUMS_NAME="$(read_json_value "$MANIFEST_PATH" checksumsFileName || true)"
if [[ -z "$CHECKSUMS_NAME" ]]; then
  LEGACY_CHECKSUMS_PATH="$(read_json_value "$MANIFEST_PATH" checksumsPath || true)"
  CHECKSUMS_NAME="${LEGACY_CHECKSUMS_PATH:t}"
fi
[[ -n "$CHECKSUMS_NAME" ]] || CHECKSUMS_NAME="${MANIFEST_PATH:t:r:r}.checksums.txt"
APP_BUNDLE_NAME="$(read_json_value "$MANIFEST_PATH" appBundle.name || true)"
[[ -n "$APP_BUNDLE_NAME" ]] || APP_BUNDLE_NAME="$APP_NAME.app"
CHECKSUMS_PATH="$DIST_DIR/$CHECKSUMS_NAME"
APP_BUNDLE="$DIST_DIR/$APP_BUNDLE_NAME"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
BUILD_INFO_PATH="$APP_BUNDLE/Contents/Resources/WordZMacBuildInfo.json"
EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO_PLIST")"
EXECUTABLE_PATH="$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

[[ -d "$APP_BUNDLE" ]] || { echo "missing app bundle: $APP_BUNDLE" >&2; exit 1; }
[[ -f "$INFO_PLIST" ]] || { echo "missing Info.plist: $INFO_PLIST" >&2; exit 1; }
[[ -f "$BUILD_INFO_PATH" ]] || { echo "missing build info file: $BUILD_INFO_PATH" >&2; exit 1; }
[[ -x "$EXECUTABLE_PATH" ]] || { echo "missing executable: $EXECUTABLE_PATH" >&2; exit 1; }
[[ -f "$CHECKSUMS_PATH" ]] || { echo "missing checksums file: $CHECKSUMS_PATH" >&2; exit 1; }

INFO_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
INFO_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
BUILD_INFO_VERSION="$(read_json_value "$BUILD_INFO_PATH" version)"
BUILD_INFO_ARCH="$(read_json_value "$BUILD_INFO_PATH" architecture)"
BUILD_INFO_CHANNEL="$(read_json_value "$BUILD_INFO_PATH" distributionChannel || true)"
BUILD_INFO_SHA="$(read_json_value "$BUILD_INFO_PATH" executableSHA256 || true)"

[[ "$INFO_VERSION" == "$VERSION" ]] || { echo "Info.plist version mismatch: $INFO_VERSION != $VERSION" >&2; exit 1; }
[[ "$BUILD_INFO_VERSION" == "$VERSION" ]] || { echo "build info version mismatch: $BUILD_INFO_VERSION != $VERSION" >&2; exit 1; }
[[ "$BUILD_INFO_ARCH" == "$ARCHITECTURE" ]] || { echo "build info architecture mismatch: $BUILD_INFO_ARCH != $ARCHITECTURE" >&2; exit 1; }
[[ -n "$INFO_BUILD" ]] || { echo "missing CFBundleVersion in $INFO_PLIST" >&2; exit 1; }
echo "[native-release-smoke] app bundle: $APP_BUNDLE"
echo "[native-release-smoke] version: $VERSION"
echo "[native-release-smoke] build: $INFO_BUILD"
echo "[native-release-smoke] architecture: $ARCHITECTURE"
if [[ -n "$BUILD_INFO_CHANNEL" ]]; then
  echo "[native-release-smoke] distribution channel: $BUILD_INFO_CHANNEL"
else
  echo "[native-release-smoke] distribution channel: missing (legacy build info)"
fi
if [[ -n "$BUILD_INFO_SHA" ]]; then
  echo "[native-release-smoke] executable sha256: $BUILD_INFO_SHA"
else
  echo "[native-release-smoke] executable sha256: missing (legacy build info)"
fi
echo "[native-release-smoke] build info: OK"
echo "[native-release-smoke] packaged app structural smoke passed."
