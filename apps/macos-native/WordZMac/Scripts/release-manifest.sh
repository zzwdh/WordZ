#!/bin/zsh
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source "$SCRIPT_DIR/release-support.sh"

if [[ $# -lt 3 ]]; then
  echo "usage: $0 <app-name> <version> <dist-dir> [arch]" >&2
  exit 1
fi

APP_NAME="$1"
VERSION="$2"
DIST_DIR="$3"
ARCH_NAME="${4:-$(uname -m)}"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
ZIP_NAME="${APP_NAME}-${VERSION}-mac-${ARCH_NAME}.zip"
DMG_NAME="${APP_NAME}-${VERSION}-mac-${ARCH_NAME}.dmg"
PKG_NAME="${APP_NAME}-${VERSION}-mac-${ARCH_NAME}.pkg"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"
DMG_PATH="$DIST_DIR/$DMG_NAME"
PKG_PATH="$DIST_DIR/$PKG_NAME"
CHECKSUMS_PATH="$DIST_DIR/${APP_NAME}-${VERSION}-mac-${ARCH_NAME}.checksums.txt"
MANIFEST_PATH="$DIST_DIR/${APP_NAME}-${VERSION}-mac-${ARCH_NAME}.manifest.json"
APP_ROOT="$(release_support_app_root)"
RELEASE_NOTES_PATH="$(release_support_release_notes_path "$VERSION")"
RELEASE_HIGHLIGHTS_PATH="$(release_support_release_highlights_path)"
RELEASE_NOTES_EXISTS=0
if [[ -f "$RELEASE_NOTES_PATH" ]]; then
  RELEASE_NOTES_EXISTS=1
fi
RELEASE_NOTES_RELATIVE_PATH="${RELEASE_NOTES_PATH#$APP_ROOT/}"
RELEASE_TAG="$(release_support_release_tag "$VERSION")"
RELEASE_PAGE_URL="$(release_support_release_page_url "$VERSION")"
REPOSITORY_SLUG="$(release_support_repository_slug)"
RELEASE_CHANNEL="$(release_support_release_channel)"
RELEASE_HIGHLIGHTS_JSON="$(release_support_release_highlights_json "$RELEASE_HIGHLIGHTS_PATH")"
NOTARIZED_APP="${WORDZ_MAC_NOTARIZED_APP:-0}"
NOTARIZED_DMG="${WORDZ_MAC_NOTARIZED_DMG:-0}"
NOTARIZED_PKG="${WORDZ_MAC_NOTARIZED_PKG:-0}"
SKIP_DMG="${WORDZ_MAC_SKIP_DMG:-0}"
DMG_INCLUDED=1

required_artifact_paths=("$APP_BUNDLE" "$ZIP_PATH" "$PKG_PATH")
if [[ "$SKIP_DMG" == "1" ]]; then
  DMG_INCLUDED=0
else
  required_artifact_paths+=("$DMG_PATH")
fi

for artifact_path in "${required_artifact_paths[@]}"; do
  if [[ ! -e "$artifact_path" ]]; then
    echo "missing release artifact: $artifact_path" >&2
    exit 1
  fi
done

zip_sha="$(/usr/bin/shasum -a 256 "$ZIP_PATH" | /usr/bin/awk '{print $1}')"
pkg_sha="$(/usr/bin/shasum -a 256 "$PKG_PATH" | /usr/bin/awk '{print $1}')"
zip_size="$(/usr/bin/stat -f %z "$ZIP_PATH")"
pkg_size="$(/usr/bin/stat -f %z "$PKG_PATH")"
if [[ "$DMG_INCLUDED" -eq 1 ]]; then
  dmg_sha="$(/usr/bin/shasum -a 256 "$DMG_PATH" | /usr/bin/awk '{print $1}')"
  dmg_size="$(/usr/bin/stat -f %z "$DMG_PATH")"
fi

{
  print -r -- "$zip_sha  $ZIP_NAME"
  if [[ "$DMG_INCLUDED" -eq 1 ]]; then
    print -r -- "$dmg_sha  $DMG_NAME"
  fi
  print -r -- "$pkg_sha  $PKG_NAME"
} > "$CHECKSUMS_PATH"

/bin/cat > "$MANIFEST_PATH" <<JSON
{
  "appName": "$(release_support_json_escape "$APP_NAME")",
  "version": "$(release_support_json_escape "$VERSION")",
  "architecture": "$(release_support_json_escape "$ARCH_NAME")",
  "generatedAt": "$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)",
  "release": {
    "channel": "$(release_support_json_escape "$RELEASE_CHANNEL")",
    "tag": "$(release_support_json_escape "$RELEASE_TAG")",
    "repository": "$(release_support_json_escape "$REPOSITORY_SLUG")",
    "releasePageURL": "$(release_support_json_escape "$RELEASE_PAGE_URL")",
    "dmgIncluded": $([[ "$DMG_INCLUDED" -eq 1 ]] && echo true || echo false),
    "notesAvailable": $([[ "$RELEASE_NOTES_EXISTS" -eq 1 ]] && echo true || echo false),
    "notesPath": "$([[ "$RELEASE_NOTES_EXISTS" -eq 1 ]] && release_support_json_escape "$RELEASE_NOTES_RELATIVE_PATH")",
    "highlights": $RELEASE_HIGHLIGHTS_JSON
  },
  "appBundle": {
    "name": "$(release_support_json_escape "$APP_NAME").app",
    "notarized": $([[ "$NOTARIZED_APP" == "1" ]] && echo true || echo false)
  },
  "assets": [
    {
      "name": "$(release_support_json_escape "$ZIP_NAME")",
      "kind": "zip",
      "size": $zip_size,
      "sha256": "$(release_support_json_escape "$zip_sha")",
      "containsStapledApp": $([[ "$NOTARIZED_APP" == "1" ]] && echo true || echo false)
    }
JSON
if [[ "$DMG_INCLUDED" -eq 1 ]]; then
  /bin/cat >> "$MANIFEST_PATH" <<JSON
    ,
    {
      "name": "$(release_support_json_escape "$DMG_NAME")",
      "kind": "dmg",
      "size": $dmg_size,
      "sha256": "$(release_support_json_escape "$dmg_sha")",
      "notarized": $([[ "$NOTARIZED_DMG" == "1" ]] && echo true || echo false)
    }
JSON
fi
/bin/cat >> "$MANIFEST_PATH" <<JSON
    ,
    {
      "name": "$(release_support_json_escape "$PKG_NAME")",
      "kind": "pkg",
      "size": $pkg_size,
      "sha256": "$(release_support_json_escape "$pkg_sha")",
      "containsStapledApp": $([[ "$NOTARIZED_APP" == "1" ]] && echo true || echo false),
      "notarized": $([[ "$NOTARIZED_PKG" == "1" ]] && echo true || echo false)
    }
  ],
  "checksumsFileName": "$(release_support_json_escape "${CHECKSUMS_PATH:t}")"
}
JSON

echo "$CHECKSUMS_PATH"
echo "$MANIFEST_PATH"
