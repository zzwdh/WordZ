#!/bin/zsh
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source "$SCRIPT_DIR/release-support.sh"
NODE_BIN="$(release_support_node_bin)"

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
ZIP_PATH="$DIST_DIR/$ZIP_NAME"
DMG_PATH="$DIST_DIR/$DMG_NAME"
CHECKSUMS_PATH="$DIST_DIR/${APP_NAME}-${VERSION}-mac-${ARCH_NAME}.checksums.txt"
MANIFEST_PATH="$DIST_DIR/${APP_NAME}-${VERSION}-mac-${ARCH_NAME}.manifest.json"
PACKAGE_JSON_PATH="$(release_support_package_json_path)"
APP_ROOT="$(release_support_app_root)"
RELEASE_NOTES_PATH="$(release_support_release_notes_path "$VERSION")"
RELEASE_NOTES_EXISTS=0
if [[ -f "$RELEASE_NOTES_PATH" ]]; then
  RELEASE_NOTES_EXISTS=1
fi
RELEASE_NOTES_RELATIVE_PATH="${RELEASE_NOTES_PATH#$APP_ROOT/}"
RELEASE_TAG="$(release_support_release_tag "$VERSION")"
RELEASE_PAGE_URL="$(release_support_release_page_url "$VERSION")"
REPOSITORY_SLUG="$(release_support_repository_slug)"
NOTARIZED_APP="${WORDZ_MAC_NOTARIZED_APP:-0}"
NOTARIZED_DMG="${WORDZ_MAC_NOTARIZED_DMG:-0}"
RELEASE_CHANNEL="$(
  "$NODE_BIN" -e '
const fs = require("fs");
const pkg = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
process.stdout.write((pkg.wordz && pkg.wordz.release && pkg.wordz.release.channel) || "stable");
' "$PACKAGE_JSON_PATH"
)"

for path in "$APP_BUNDLE" "$ZIP_PATH" "$DMG_PATH"; do
  if [[ ! -e "$path" ]]; then
    echo "missing release artifact: $path" >&2
    exit 1
  fi
done

zip_sha="$(/usr/bin/shasum -a 256 "$ZIP_PATH" | /usr/bin/awk '{print $1}')"
dmg_sha="$(/usr/bin/shasum -a 256 "$DMG_PATH" | /usr/bin/awk '{print $1}')"
zip_size="$(/usr/bin/stat -f %z "$ZIP_PATH")"
dmg_size="$(/usr/bin/stat -f %z "$DMG_PATH")"

/bin/cat > "$CHECKSUMS_PATH" <<EOF
$zip_sha  $ZIP_NAME
$dmg_sha  $DMG_NAME
EOF

APP_NAME="$APP_NAME" \
VERSION="$VERSION" \
ARCH_NAME="$ARCH_NAME" \
ZIP_NAME="$ZIP_NAME" \
ZIP_SIZE="$zip_size" \
ZIP_SHA="$zip_sha" \
DMG_NAME="$DMG_NAME" \
DMG_SIZE="$dmg_size" \
DMG_SHA="$dmg_sha" \
CHECKSUMS_FILE_NAME="${CHECKSUMS_PATH:t}" \
MANIFEST_PATH="$MANIFEST_PATH" \
PACKAGE_JSON_PATH="$PACKAGE_JSON_PATH" \
RELEASE_TAG="$RELEASE_TAG" \
RELEASE_CHANNEL="$RELEASE_CHANNEL" \
RELEASE_NOTES_EXISTS="$RELEASE_NOTES_EXISTS" \
RELEASE_NOTES_RELATIVE_PATH="$RELEASE_NOTES_RELATIVE_PATH" \
RELEASE_PAGE_URL="$RELEASE_PAGE_URL" \
REPOSITORY_SLUG="$REPOSITORY_SLUG" \
NOTARIZED_APP="$NOTARIZED_APP" \
NOTARIZED_DMG="$NOTARIZED_DMG" \
"$NODE_BIN" -e '
const fs = require("fs");
const path = require("path");

const pkg = JSON.parse(fs.readFileSync(process.env.PACKAGE_JSON_PATH, "utf8"));
const highlights = pkg.wordz && Array.isArray(pkg.wordz.releaseNotes) ? pkg.wordz.releaseNotes : [];

const manifest = {
  appName: process.env.APP_NAME,
  version: process.env.VERSION,
  architecture: process.env.ARCH_NAME,
  generatedAt: new Date().toISOString(),
  release: {
    channel: process.env.RELEASE_CHANNEL || "stable",
    tag: process.env.RELEASE_TAG,
    repository: process.env.REPOSITORY_SLUG || "",
    releasePageURL: process.env.RELEASE_PAGE_URL || "",
    notesAvailable: process.env.RELEASE_NOTES_EXISTS === "1",
    notesPath: process.env.RELEASE_NOTES_EXISTS === "1" ? process.env.RELEASE_NOTES_RELATIVE_PATH : "",
    highlights
  },
  appBundle: {
    name: process.env.APP_NAME + ".app",
    notarized: process.env.NOTARIZED_APP === "1"
  },
  assets: [
    {
      name: process.env.ZIP_NAME,
      kind: "zip",
      size: Number(process.env.ZIP_SIZE),
      sha256: process.env.ZIP_SHA,
      containsStapledApp: process.env.NOTARIZED_APP === "1"
    },
    {
      name: process.env.DMG_NAME,
      kind: "dmg",
      size: Number(process.env.DMG_SIZE),
      sha256: process.env.DMG_SHA,
      notarized: process.env.NOTARIZED_DMG === "1"
    }
  ],
  checksumsFileName: process.env.CHECKSUMS_FILE_NAME
};

fs.writeFileSync(process.env.MANIFEST_PATH, JSON.stringify(manifest, null, 2) + "\n");
'

echo "$CHECKSUMS_PATH"
echo "$MANIFEST_PATH"
