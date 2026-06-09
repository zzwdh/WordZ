#!/bin/zsh
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
APP_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$APP_ROOT/../../.." && pwd)

APPLY=0
INCLUDE_REPO_ROOT=0

usage() {
  cat <<EOF
usage: $0 [--apply] [--include-repo-root]

Lists local generated files that can be removed while keeping source files intact.
By default this is a dry run for the WordZMac SwiftPM project only.

Options:
  --apply              remove the listed generated files
  --include-repo-root  also include legacy Electron/Node/root test artifacts
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      APPLY=1
      ;;
    --include-repo-root)
      INCLUDE_REPO_ROOT=1
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

wordzmac_targets=(
  "$APP_ROOT/.build"
  "$APP_ROOT/.swiftpm"
  "$APP_ROOT/dist-native"
  "$APP_ROOT/.release-clang-cache"
  "$APP_ROOT/.release-home"
  "$APP_ROOT/.release-swiftpm-cache"
  "$APP_ROOT/.DS_Store"
  "$APP_ROOT/Sources/.DS_Store"
  "$APP_ROOT/Sources/WordZMac/.DS_Store"
)

repo_root_targets=(
  "$REPO_ROOT/node_modules"
  "$REPO_ROOT/dist"
  "$REPO_ROOT/dist-native"
  "$REPO_ROOT/.wordz-native-user-data"
  "$REPO_ROOT/.wordz-native-user-data-test"
  "$REPO_ROOT/.wordz-native-user-data-corpus-info-test"
  "$REPO_ROOT/.DS_Store"
  "$REPO_ROOT/apps/.DS_Store"
  "$REPO_ROOT/apps/macos-native/.DS_Store"
)

targets=("${wordzmac_targets[@]}")
if [[ "$INCLUDE_REPO_ROOT" -eq 1 ]]; then
  targets+=("${repo_root_targets[@]}")
fi

existing_targets=()
for target in "${targets[@]}"; do
  if [[ -e "$target" ]]; then
    existing_targets+=("$target")
  fi
done

if [[ "${#existing_targets[@]}" -eq 0 ]]; then
  echo "[clean-local-artifacts] no local artifacts found."
  exit 0
fi

if [[ "$APPLY" -eq 1 ]]; then
  echo "[clean-local-artifacts] removing ${#existing_targets[@]} local artifact(s)."
else
  echo "[clean-local-artifacts] dry run. Pass --apply to remove these paths."
fi

for target in "${existing_targets[@]}"; do
  size="$(/usr/bin/du -sh "$target" 2>/dev/null | /usr/bin/awk '{ print $1 }')"
  relative="$target"
  if [[ "$target" == "$APP_ROOT"* ]]; then
    relative="${target#$APP_ROOT/}"
  elif [[ "$target" == "$REPO_ROOT"* ]]; then
    relative="../../../${target#$REPO_ROOT/}"
  fi

  echo "$size  $relative"
  if [[ "$APPLY" -eq 1 ]]; then
    /bin/rm -rf "$target"
  fi
done
