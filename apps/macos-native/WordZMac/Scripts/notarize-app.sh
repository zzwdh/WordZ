#!/bin/zsh
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source "$SCRIPT_DIR/release-support.sh"

usage() {
  echo "usage: $0 <artifact-path|manifest-path|dist-dir>" >&2
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

INPUT_PATH="$1"
NOTARY_PROFILE="${WORDZ_MAC_NOTARY_PROFILE:-}"

if [[ -z "$NOTARY_PROFILE" ]]; then
  echo "WORDZ_MAC_NOTARY_PROFILE is required." >&2
  exit 1
fi

submit_and_staple() {
  local artifact_path="$1"

  xcrun notarytool submit "$artifact_path" --keychain-profile "$NOTARY_PROFILE" --wait

  if [[ -d "$artifact_path" && "${artifact_path##*.}" == "app" ]]; then
    xcrun stapler staple "$artifact_path"
  elif [[ -f "$artifact_path" && "$artifact_path" == *.dmg ]]; then
    xcrun stapler staple "$artifact_path"
  elif [[ -f "$artifact_path" ]]; then
    xcrun stapler staple "$artifact_path" || true
  fi
}

if [[ -e "$INPUT_PATH" && ( "$INPUT_PATH" == *.app || "$INPUT_PATH" == *.dmg || "$INPUT_PATH" == *.zip ) ]]; then
  submit_and_staple "$INPUT_PATH"
  echo "$INPUT_PATH"
  exit 0
fi

MANIFEST_PATH="$(release_support_resolve_manifest_path "$INPUT_PATH")"
[[ -f "$MANIFEST_PATH" ]] || { echo "manifest not found: $MANIFEST_PATH" >&2; exit 1; }

DIST_DIR="$(cd "$(dirname "$MANIFEST_PATH")" && pwd)"
APP_NAME="$(release_support_read_manifest_value "$MANIFEST_PATH" appName)"
VERSION="$(release_support_read_manifest_value "$MANIFEST_PATH" version)"
ARCH_NAME="$(release_support_read_manifest_value "$MANIFEST_PATH" architecture)"
APP_BUNDLE_NAME="$(release_support_read_manifest_value "$MANIFEST_PATH" appBundle.name)"

[[ -n "$APP_NAME" ]] || { echo "manifest missing appName: $MANIFEST_PATH" >&2; exit 1; }
[[ -n "$VERSION" ]] || { echo "manifest missing version: $MANIFEST_PATH" >&2; exit 1; }
[[ -n "$ARCH_NAME" ]] || { echo "manifest missing architecture: $MANIFEST_PATH" >&2; exit 1; }
[[ -n "$APP_BUNDLE_NAME" ]] || { echo "manifest missing appBundle.name: $MANIFEST_PATH" >&2; exit 1; }

APP_BUNDLE="$(release_support_dist_child_path "$DIST_DIR" "$APP_BUNDLE_NAME" "app bundle")"
[[ -d "$APP_BUNDLE" ]] || { echo "app bundle not found: $APP_BUNDLE" >&2; exit 1; }

submit_and_staple "$APP_BUNDLE"

PACKAGE_OUTPUTS=("${(@f)$(zsh "$SCRIPT_DIR/package-from-app.sh" "$APP_BUNDLE" "$APP_NAME" "$VERSION" "$DIST_DIR" "$ARCH_NAME")}")
APP_BUNDLE="${PACKAGE_OUTPUTS[1]}"
ZIP_PATH="${PACKAGE_OUTPUTS[2]}"
DMG_PATH="${PACKAGE_OUTPUTS[3]}"
CHECKSUMS_PATH="${PACKAGE_OUTPUTS[4]}"
MANIFEST_PATH="${PACKAGE_OUTPUTS[5]}"

submit_and_staple "$DMG_PATH"

REFRESHED_OUTPUTS=("${(@f)$(WORDZ_MAC_NOTARIZED_APP=1 WORDZ_MAC_NOTARIZED_DMG=1 zsh "$SCRIPT_DIR/release-manifest.sh" "$APP_NAME" "$VERSION" "$DIST_DIR" "$ARCH_NAME")}")
CHECKSUMS_PATH="${REFRESHED_OUTPUTS[1]}"
MANIFEST_PATH="${REFRESHED_OUTPUTS[2]}"

echo "$APP_BUNDLE"
echo "$ZIP_PATH"
echo "$DMG_PATH"
echo "$CHECKSUMS_PATH"
echo "$MANIFEST_PATH"
