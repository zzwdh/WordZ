#!/bin/zsh
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

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

/bin/cat > "$MANIFEST_PATH" <<JSON
{
  "appName": "$APP_NAME",
  "version": "$VERSION",
  "architecture": "$ARCH_NAME",
  "generatedAt": "$(/bin/date -u +%Y-%m-%dT%H:%M:%SZ)",
  "appBundle": {
    "name": "$APP_NAME.app"
  },
  "assets": [
    {
      "name": "$ZIP_NAME",
      "kind": "zip",
      "size": $zip_size,
      "sha256": "$zip_sha"
    },
    {
      "name": "$DMG_NAME",
      "kind": "dmg",
      "size": $dmg_size,
      "sha256": "$dmg_sha"
    }
  ],
  "checksumsFileName": "${CHECKSUMS_PATH:t}"
}
JSON

echo "$CHECKSUMS_PATH"
echo "$MANIFEST_PATH"
