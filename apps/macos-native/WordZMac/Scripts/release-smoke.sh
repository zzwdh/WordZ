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

first_existing_path() {
  local candidate
  for candidate in "$@"; do
    if [[ -e "$candidate" ]]; then
      echo "$candidate"
      return
    fi
  done
  return 1
}

validate_serialized_resource() {
  local path="$1"
  /usr/bin/plutil -convert xml1 -o /dev/null "$path"
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
APP_RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"
FEATURE_RESOURCE_BUNDLE="$APP_RESOURCES_DIR/WordZMac_WordZMac.bundle"
BUILD_INFO_PATH="$APP_RESOURCES_DIR/WordZMacBuildInfo.json"
EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO_PLIST")"
EXECUTABLE_PATH="$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
TOPIC_MANIFEST_PATH="$(first_existing_path \
  "$APP_RESOURCES_DIR/TopicModelManifest.json" \
  "$FEATURE_RESOURCE_BUNDLE/TopicModelManifest.json")"
TOPIC_EMBEDDING_PATH="$(first_existing_path \
  "$APP_RESOURCES_DIR/TopicLocalEmbeddingModel.json" \
  "$FEATURE_RESOURCE_BUNDLE/TopicLocalEmbeddingModel.json")"
SENTIMENT_MANIFEST_PATH="$(first_existing_path \
  "$APP_RESOURCES_DIR/Sentiment/manifest.json" \
  "$APP_RESOURCES_DIR/manifest.json" \
  "$FEATURE_RESOURCE_BUNDLE/Sentiment/manifest.json" \
  "$FEATURE_RESOURCE_BUNDLE/manifest.json")"
SENTIMENT_LEXICON_PATH="$(first_existing_path \
  "$APP_RESOURCES_DIR/Sentiment/lexicon.json" \
  "$APP_RESOURCES_DIR/lexicon.json" \
  "$FEATURE_RESOURCE_BUNDLE/Sentiment/lexicon.json" \
  "$FEATURE_RESOURCE_BUNDLE/lexicon.json")"
SENTIMENT_NEGATORS_PATH="$(first_existing_path \
  "$APP_RESOURCES_DIR/Sentiment/negators.json" \
  "$APP_RESOURCES_DIR/negators.json" \
  "$FEATURE_RESOURCE_BUNDLE/Sentiment/negators.json" \
  "$FEATURE_RESOURCE_BUNDLE/negators.json")"
SENTIMENT_CONTRASTIVES_PATH="$(first_existing_path \
  "$APP_RESOURCES_DIR/Sentiment/contrastives.json" \
  "$APP_RESOURCES_DIR/contrastives.json" \
  "$FEATURE_RESOURCE_BUNDLE/Sentiment/contrastives.json" \
  "$FEATURE_RESOURCE_BUNDLE/contrastives.json")"
SENTIMENT_INTENSIFIERS_PATH="$(first_existing_path \
  "$APP_RESOURCES_DIR/Sentiment/intensifiers.json" \
  "$APP_RESOURCES_DIR/intensifiers.json" \
  "$FEATURE_RESOURCE_BUNDLE/Sentiment/intensifiers.json" \
  "$FEATURE_RESOURCE_BUNDLE/intensifiers.json")"
SENTIMENT_REPORTING_VERBS_PATH="$(first_existing_path \
  "$APP_RESOURCES_DIR/Sentiment/reporting_verbs.json" \
  "$APP_RESOURCES_DIR/reporting_verbs.json" \
  "$FEATURE_RESOURCE_BUNDLE/Sentiment/reporting_verbs.json" \
  "$FEATURE_RESOURCE_BUNDLE/reporting_verbs.json")"
EN_LOCALIZATION_PATH="$(first_existing_path \
  "$APP_RESOURCES_DIR/en.lproj/Localizable.strings" \
  "$FEATURE_RESOURCE_BUNDLE/en.lproj/Localizable.strings")"
ZH_LOCALIZATION_PATH="$(first_existing_path \
  "$APP_RESOURCES_DIR/zh-Hans.lproj/Localizable.strings" \
  "$FEATURE_RESOURCE_BUNDLE/zh-hans.lproj/Localizable.strings")"

[[ -d "$APP_BUNDLE" ]] || { echo "missing app bundle: $APP_BUNDLE" >&2; exit 1; }
[[ -f "$INFO_PLIST" ]] || { echo "missing Info.plist: $INFO_PLIST" >&2; exit 1; }
[[ -f "$BUILD_INFO_PATH" ]] || { echo "missing build info file: $BUILD_INFO_PATH" >&2; exit 1; }
[[ -x "$EXECUTABLE_PATH" ]] || { echo "missing executable: $EXECUTABLE_PATH" >&2; exit 1; }
[[ -f "$CHECKSUMS_PATH" ]] || { echo "missing checksums file: $CHECKSUMS_PATH" >&2; exit 1; }
[[ -n "$TOPIC_MANIFEST_PATH" ]] || { echo "missing topic manifest resource" >&2; exit 1; }
[[ -n "$TOPIC_EMBEDDING_PATH" ]] || { echo "missing topic embedding resource" >&2; exit 1; }
[[ -f "$SENTIMENT_MANIFEST_PATH" ]] || { echo "missing sentiment manifest: $SENTIMENT_MANIFEST_PATH" >&2; exit 1; }
[[ -f "$SENTIMENT_LEXICON_PATH" ]] || { echo "missing sentiment lexicon: $SENTIMENT_LEXICON_PATH" >&2; exit 1; }
[[ -f "$SENTIMENT_NEGATORS_PATH" ]] || { echo "missing sentiment negators: $SENTIMENT_NEGATORS_PATH" >&2; exit 1; }
[[ -f "$SENTIMENT_CONTRASTIVES_PATH" ]] || { echo "missing sentiment contrastives: $SENTIMENT_CONTRASTIVES_PATH" >&2; exit 1; }
[[ -f "$SENTIMENT_INTENSIFIERS_PATH" ]] || { echo "missing sentiment intensifiers: $SENTIMENT_INTENSIFIERS_PATH" >&2; exit 1; }
[[ -f "$SENTIMENT_REPORTING_VERBS_PATH" ]] || { echo "missing sentiment reporting verbs: $SENTIMENT_REPORTING_VERBS_PATH" >&2; exit 1; }
[[ -f "$EN_LOCALIZATION_PATH" ]] || { echo "missing english localization: $EN_LOCALIZATION_PATH" >&2; exit 1; }
[[ -f "$ZH_LOCALIZATION_PATH" ]] || { echo "missing zh-Hans localization: $ZH_LOCALIZATION_PATH" >&2; exit 1; }
[[ -s "$EXECUTABLE_PATH" ]] || { echo "empty executable: $EXECUTABLE_PATH" >&2; exit 1; }

INFO_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
INFO_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
INFO_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$INFO_PLIST" 2>/dev/null || true)"
BUILD_INFO_VERSION="$(read_json_value "$BUILD_INFO_PATH" version)"
BUILD_INFO_ARCH="$(read_json_value "$BUILD_INFO_PATH" architecture)"
BUILD_INFO_CHANNEL="$(read_json_value "$BUILD_INFO_PATH" distributionChannel || true)"
BUILD_INFO_SHA="$(read_json_value "$BUILD_INFO_PATH" executableSHA256 || true)"

[[ "$INFO_VERSION" == "$VERSION" ]] || { echo "Info.plist version mismatch: $INFO_VERSION != $VERSION" >&2; exit 1; }
[[ "$BUILD_INFO_VERSION" == "$VERSION" ]] || { echo "build info version mismatch: $BUILD_INFO_VERSION != $VERSION" >&2; exit 1; }
[[ "$BUILD_INFO_ARCH" == "$ARCHITECTURE" ]] || { echo "build info architecture mismatch: $BUILD_INFO_ARCH != $ARCHITECTURE" >&2; exit 1; }
[[ -n "$INFO_BUILD" ]] || { echo "missing CFBundleVersion in $INFO_PLIST" >&2; exit 1; }
if [[ -n "$INFO_NAME" ]]; then
  [[ "$INFO_NAME" == "$APP_NAME" ]] || { echo "CFBundleName mismatch: $INFO_NAME != $APP_NAME" >&2; exit 1; }
fi
/usr/bin/plutil -lint "$INFO_PLIST" >/dev/null
validate_serialized_resource "$BUILD_INFO_PATH"
validate_serialized_resource "$TOPIC_MANIFEST_PATH"
validate_serialized_resource "$TOPIC_EMBEDDING_PATH"
validate_serialized_resource "$SENTIMENT_MANIFEST_PATH"
validate_serialized_resource "$SENTIMENT_LEXICON_PATH"
validate_serialized_resource "$SENTIMENT_NEGATORS_PATH"
validate_serialized_resource "$SENTIMENT_CONTRASTIVES_PATH"
validate_serialized_resource "$SENTIMENT_INTENSIFIERS_PATH"
validate_serialized_resource "$SENTIMENT_REPORTING_VERBS_PATH"
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
echo "[native-release-smoke] bundled resources: Topics/Sentiment/localizations OK"
echo "[native-release-smoke] packaged app structural smoke passed."
