#!/bin/zsh
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source "$SCRIPT_DIR/release-support.sh"

VERSION_OVERRIDE=""
NOTES_PATH_OVERRIDE=""
HIGHLIGHTS_PATH_OVERRIDE=""

usage() {
  cat <<EOF
usage: $0 [--version <version>] [--notes-file <path>] [--highlights-file <path>]

Checks the release metadata needed for shipping a macOS build:
  - local VERSION
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
    --highlights-file)
      shift
      [[ $# -gt 0 ]] || usage
      HIGHLIGHTS_PATH_OVERRIDE="$1"
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
VERSION_PATH="$(release_support_version_path)"
NOTES_PATH="${NOTES_PATH_OVERRIDE:-$(release_support_release_notes_path "$VERSION")}"
HIGHLIGHTS_PATH="${HIGHLIGHTS_PATH_OVERRIDE:-$(release_support_release_highlights_path)}"
APP_ROOT="$(release_support_app_root)"
REPOSITORY_SLUG="$(release_support_repository_slug)"
RELEASE_PAGE_URL="$(release_support_release_page_url "$VERSION")"

[[ -f "$VERSION_PATH" || -n "${WORDZ_MAC_VERSION:-}" ]] || { echo "VERSION not found: $VERSION_PATH" >&2; exit 1; }
[[ -f "$NOTES_PATH" ]] || { echo "release notes not found: $NOTES_PATH" >&2; exit 1; }
[[ -f "$HIGHLIGHTS_PATH" ]] || { echo "release highlights not found: $HIGHLIGHTS_PATH" >&2; exit 1; }

NOTES_TITLE="$(release_support_release_title_from_notes "$NOTES_PATH")"
[[ -n "$NOTES_TITLE" ]] || { echo "release notes are missing a top-level heading: $NOTES_PATH" >&2; exit 1; }

if [[ "$NOTES_TITLE" != *"$VERSION"* ]]; then
  echo "release notes heading does not mention version $VERSION: $NOTES_TITLE" >&2
  exit 1
fi

HIGHLIGHT_COUNT="$(release_support_release_highlight_count "$HIGHLIGHTS_PATH")"

if [[ "$HIGHLIGHT_COUNT" -lt 1 ]]; then
  echo "release highlights file is empty: $HIGHLIGHTS_PATH" >&2
  exit 1
fi

if /usr/bin/grep -q '^> Draft' "$NOTES_PATH"; then
  echo "[release-metadata-check] warning: release notes are still marked as Draft." >&2
fi

echo "[release-metadata-check] version: $VERSION"
echo "[release-metadata-check] release notes: ${NOTES_PATH#$APP_ROOT/}"
echo "[release-metadata-check] notes heading: $NOTES_TITLE"
echo "[release-metadata-check] in-app highlights: $HIGHLIGHT_COUNT"
echo "[release-metadata-check] highlights: ${HIGHLIGHTS_PATH#$APP_ROOT/}"
if [[ -n "$REPOSITORY_SLUG" ]]; then
  echo "[release-metadata-check] repository: $REPOSITORY_SLUG"
fi
if [[ -n "$RELEASE_PAGE_URL" ]]; then
  echo "[release-metadata-check] release page: $RELEASE_PAGE_URL"
fi
echo "$NOTES_PATH"
