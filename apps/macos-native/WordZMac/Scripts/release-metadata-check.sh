#!/bin/zsh
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source "$SCRIPT_DIR/release-support.sh"
NODE_BIN="$(release_support_node_bin)"

VERSION_OVERRIDE=""
NOTES_PATH_OVERRIDE=""

usage() {
  cat <<EOF
usage: $0 [--version <version>] [--notes-file <path>]

Checks the release metadata needed for shipping a macOS build:
  - package.json version
  - release notes document presence
  - release notes heading/version alignment
  - in-app release highlights presence
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      shift
      [[ $# -gt 0 ]] || usage
      VERSION_OVERRIDE="$1"
      ;;
    --notes-file)
      shift
      [[ $# -gt 0 ]] || usage
      NOTES_PATH_OVERRIDE="$1"
      ;;
    --help)
      usage
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage
      ;;
  esac
  shift
done

VERSION="${VERSION_OVERRIDE:-$(release_support_current_version)}"
PACKAGE_JSON_PATH="$(release_support_package_json_path)"
NOTES_PATH="${NOTES_PATH_OVERRIDE:-$(release_support_release_notes_path "$VERSION")}"
APP_ROOT="$(release_support_app_root)"
REPOSITORY_SLUG="$(release_support_repository_slug)"
RELEASE_PAGE_URL="$(release_support_release_page_url "$VERSION")"

[[ -f "$PACKAGE_JSON_PATH" ]] || { echo "package.json not found: $PACKAGE_JSON_PATH" >&2; exit 1; }
[[ -f "$NOTES_PATH" ]] || { echo "release notes not found: $NOTES_PATH" >&2; exit 1; }

NOTES_TITLE="$(release_support_release_title_from_notes "$NOTES_PATH")"
[[ -n "$NOTES_TITLE" ]] || { echo "release notes are missing a top-level heading: $NOTES_PATH" >&2; exit 1; }

if [[ "$NOTES_TITLE" != *"$VERSION"* ]]; then
  echo "release notes heading does not mention version $VERSION: $NOTES_TITLE" >&2
  exit 1
fi

HIGHLIGHT_COUNT="$("$NODE_BIN" -e '
const fs = require("fs");
const pkg = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const highlights = pkg.wordz && Array.isArray(pkg.wordz.releaseNotes) ? pkg.wordz.releaseNotes : [];
process.stdout.write(String(highlights.length));
' "$PACKAGE_JSON_PATH")"

if [[ "$HIGHLIGHT_COUNT" -lt 1 ]]; then
  echo "package.json is missing wordz.releaseNotes highlights." >&2
  exit 1
fi

if /usr/bin/grep -q '^> Draft' "$NOTES_PATH"; then
  echo "[release-metadata-check] warning: release notes are still marked as Draft." >&2
fi

echo "[release-metadata-check] version: $VERSION"
echo "[release-metadata-check] release notes: ${NOTES_PATH#$APP_ROOT/}"
echo "[release-metadata-check] notes heading: $NOTES_TITLE"
echo "[release-metadata-check] in-app highlights: $HIGHLIGHT_COUNT"
if [[ -n "$REPOSITORY_SLUG" ]]; then
  echo "[release-metadata-check] repository: $REPOSITORY_SLUG"
fi
if [[ -n "$RELEASE_PAGE_URL" ]]; then
  echo "[release-metadata-check] release page: $RELEASE_PAGE_URL"
fi
echo "$NOTES_PATH"
