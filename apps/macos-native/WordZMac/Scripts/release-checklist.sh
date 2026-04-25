#!/bin/zsh
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/release-support.sh"
APP_ROOT="$(release_support_app_root)"
DIST_DIR="$(release_support_dist_dir)"
SCRIPT_NAME="${0:t}"

RUN_METADATA=1
RUN_TESTS=1
RUN_ARCHITECTURE=1
RUN_PACKAGE=1
RUN_VERIFY=1
RUN_SMOKE=1
RUN_NOTARIZE=0
RUN_UPLOAD=0
MANIFEST_PATH=""
RELEASE_NOTES_PATH=""
UPLOAD_ARGS=()

usage() {
  cat <<EOF
usage: $SCRIPT_NAME [--skip-metadata] [--skip-tests] [--skip-architecture] [--skip-package] [--skip-verify] [--skip-smoke] [--notarize] [--upload] [--manifest <path>] [--notes-file <path>] [--repo <owner/repo>] [--tag <tag>] [--title <title>] [--draft] [--prerelease] [--clobber]

This script runs the native macOS release checklist:
  1. release-metadata-check.sh
  2. swift tests
  3. architecture-guard.sh
  4. package-app.sh
  5. verify-release.sh
  6. release-smoke.sh
  7. optional notarize-app.sh
  8. optional release-upload.sh
EOF
  exit "${1:-1}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-metadata)
      RUN_METADATA=0
      ;;
    --skip-tests)
      RUN_TESTS=0
      ;;
    --skip-architecture)
      RUN_ARCHITECTURE=0
      ;;
    --skip-package)
      RUN_PACKAGE=0
      ;;
    --skip-verify)
      RUN_VERIFY=0
      ;;
    --skip-smoke)
      RUN_SMOKE=0
      ;;
    --notarize)
      RUN_NOTARIZE=1
      ;;
    --upload)
      RUN_UPLOAD=1
      ;;
    --manifest)
      shift
      [[ $# -gt 0 ]] || usage
      MANIFEST_PATH="$1"
      ;;
    --notes-file)
      shift
      [[ $# -gt 0 ]] || usage
      RELEASE_NOTES_PATH="$1"
      ;;
    --repo|--tag|--title)
      option="$1"
      shift
      [[ $# -gt 0 ]] || usage
      UPLOAD_ARGS+=("$option" "$1")
      ;;
    --draft|--prerelease|--clobber)
      UPLOAD_ARGS+=("$1")
      ;;
    --help)
      usage 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage
      ;;
  esac
  shift
done

step() {
  echo
  echo "[native-release-checklist] $1"
}

resolve_latest_manifest() {
  release_support_resolve_latest_manifest "$DIST_DIR"
}

if [[ "$RUN_METADATA" -eq 1 ]]; then
  step "release metadata"
  if [[ -n "$RELEASE_NOTES_PATH" ]]; then
    zsh "$SCRIPT_DIR/release-metadata-check.sh" --notes-file "$RELEASE_NOTES_PATH"
  else
    zsh "$SCRIPT_DIR/release-metadata-check.sh"
  fi
fi

if [[ "$RUN_TESTS" -eq 1 ]]; then
  step "swift tests"
  swift test --package-path "$APP_ROOT"
fi

if [[ "$RUN_ARCHITECTURE" -eq 1 ]]; then
  step "architecture guard"
  zsh "$SCRIPT_DIR/architecture-guard.sh"
fi

if [[ "$RUN_PACKAGE" -eq 1 ]]; then
  step "package artifacts"
  zsh "$SCRIPT_DIR/package-app.sh"
  MANIFEST_PATH="$(resolve_latest_manifest)"
fi

if [[ -z "$MANIFEST_PATH" ]]; then
  MANIFEST_PATH="$(resolve_latest_manifest)"
fi

[[ -n "$MANIFEST_PATH" ]] || { echo "unable to resolve manifest path" >&2; exit 1; }

if [[ "$RUN_VERIFY" -eq 1 ]]; then
  step "verify release checksums"
  zsh "$SCRIPT_DIR/verify-release.sh" "$MANIFEST_PATH"
fi

if [[ "$RUN_SMOKE" -eq 1 ]]; then
  step "native packaged smoke"
  zsh "$SCRIPT_DIR/release-smoke.sh" "$MANIFEST_PATH"
fi

if [[ "$RUN_NOTARIZE" -eq 1 ]]; then
  step "notarize release artifacts"
  MANIFEST_PATH="$(zsh "$SCRIPT_DIR/notarize-app.sh" "$MANIFEST_PATH" | tail -n 1)"

  if [[ "$RUN_VERIFY" -eq 1 ]]; then
    step "verify release checksums (post-notarize)"
    zsh "$SCRIPT_DIR/verify-release.sh" "$MANIFEST_PATH"
  fi

  if [[ "$RUN_SMOKE" -eq 1 ]]; then
    step "native packaged smoke (post-notarize)"
    zsh "$SCRIPT_DIR/release-smoke.sh" "$MANIFEST_PATH"
  fi
fi

if [[ "$RUN_UPLOAD" -eq 1 ]]; then
  step "upload GitHub release assets"
  upload_command=(zsh "$SCRIPT_DIR/release-upload.sh" "$MANIFEST_PATH")
  if [[ -n "$RELEASE_NOTES_PATH" ]]; then
    upload_command+=(--notes-file "$RELEASE_NOTES_PATH")
  fi
  upload_command+=("${UPLOAD_ARGS[@]}")
  "${upload_command[@]}"
fi

echo
echo "[native-release-checklist] Completed."
echo "[native-release-checklist] Manifest: $MANIFEST_PATH"
echo "[native-release-checklist] Remaining manual steps:"
if [[ "$RUN_NOTARIZE" -eq 0 ]]; then
  echo "  [ ] Notarize with Scripts/notarize-app.sh if this build will be distributed externally."
fi
if [[ "$RUN_UPLOAD" -eq 0 ]]; then
  echo "  [ ] Upload zip/dmg/checksums/manifest to the GitHub release."
fi
echo "  [ ] Spot-check launch on a clean machine before announcing the release."
