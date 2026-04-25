#!/bin/zsh
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source "$SCRIPT_DIR/release-support.sh"
NODE_BIN="$(release_support_node_bin)"

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <manifest-or-dist-dir> [--repo <owner/repo>] [--tag <tag>] [--title <title>] [--notes-file <path>] [--draft] [--prerelease] [--clobber]" >&2
  exit 1
fi

MANIFEST_INPUT="$1"
shift

REPOSITORY_OVERRIDE=""
TAG_OVERRIDE=""
TITLE_OVERRIDE=""
NOTES_PATH_OVERRIDE=""
IS_DRAFT=0
IS_PRERELEASE=0
CLOBBER=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      shift
      [[ $# -gt 0 ]] || exit 1
      REPOSITORY_OVERRIDE="$1"
      ;;
    --tag)
      shift
      [[ $# -gt 0 ]] || exit 1
      TAG_OVERRIDE="$1"
      ;;
    --title)
      shift
      [[ $# -gt 0 ]] || exit 1
      TITLE_OVERRIDE="$1"
      ;;
    --notes-file)
      shift
      [[ $# -gt 0 ]] || exit 1
      NOTES_PATH_OVERRIDE="$1"
      ;;
    --draft)
      IS_DRAFT=1
      ;;
    --prerelease)
      IS_PRERELEASE=1
      ;;
    --clobber)
      CLOBBER=1
      ;;
    --help)
      echo "usage: $0 <manifest-or-dist-dir> [--repo <owner/repo>] [--tag <tag>] [--title <title>] [--notes-file <path>] [--draft] [--prerelease] [--clobber]" >&2
      exit 1
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

MANIFEST_PATH="$(release_support_resolve_manifest_path "$MANIFEST_INPUT")"
[[ -f "$MANIFEST_PATH" ]] || { echo "manifest not found: $MANIFEST_PATH" >&2; exit 1; }

DIST_DIR="$(cd "$(dirname "$MANIFEST_PATH")" && pwd)"
VERSION="$(release_support_read_manifest_value "$MANIFEST_PATH" version)"
TAG_NAME="${TAG_OVERRIDE:-$(release_support_read_manifest_value "$MANIFEST_PATH" release.tag || true)}"
TAG_NAME="${TAG_NAME:-$(release_support_release_tag "$VERSION")}"
REPOSITORY_SLUG="${REPOSITORY_OVERRIDE:-$(release_support_repository_slug)}"
[[ -n "$REPOSITORY_SLUG" ]] || { echo "unable to resolve GitHub repository slug." >&2; exit 1; }

NOTES_PATH="${NOTES_PATH_OVERRIDE:-$(release_support_release_notes_path "$VERSION")}"
[[ -f "$NOTES_PATH" ]] || { echo "release notes not found: $NOTES_PATH" >&2; exit 1; }

TITLE="${TITLE_OVERRIDE:-$(release_support_release_title_from_notes "$NOTES_PATH")}"
TITLE="${TITLE:-WordZ $VERSION}"

asset_names=("${(@f)$("$NODE_BIN" -e '
const path = require("path");
const manifest = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
for (const asset of manifest.assets || []) {
  if (asset && asset.name) console.log(asset.name);
}
if (manifest.checksumsFileName) console.log(manifest.checksumsFileName);
console.log(path.basename(process.argv[1]));
' "$MANIFEST_PATH")}")

asset_paths=()
for asset_name in "${asset_names[@]}"; do
  asset_paths+=("$(release_support_dist_child_path "$DIST_DIR" "$asset_name" "release asset")")
done

for asset_path in "${asset_paths[@]}"; do
  [[ -f "$asset_path" ]] || { echo "release asset not found: $asset_path" >&2; exit 1; }
done

if gh release view "$TAG_NAME" --repo "$REPOSITORY_SLUG" >/dev/null 2>&1; then
  upload_cmd=(gh release upload "$TAG_NAME")
  upload_cmd+=("${asset_paths[@]}")
  upload_cmd+=(--repo "$REPOSITORY_SLUG")
  if [[ "$CLOBBER" -eq 1 ]]; then
    upload_cmd+=(--clobber)
  fi
  "${upload_cmd[@]}"
else
  create_cmd=(gh release create "$TAG_NAME")
  create_cmd+=("${asset_paths[@]}")
  create_cmd+=(--repo "$REPOSITORY_SLUG" --title "$TITLE" --notes-file "$NOTES_PATH")
  if [[ "$IS_DRAFT" -eq 1 ]]; then
    create_cmd+=(--draft)
  fi
  if [[ "$IS_PRERELEASE" -eq 1 ]]; then
    create_cmd+=(--prerelease)
  fi
  "${create_cmd[@]}"
fi

echo "$TAG_NAME"
echo "$REPOSITORY_SLUG"
