#!/bin/zsh
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$APP_ROOT/../../.." && pwd)"
DIST_DIR="${WORDZ_MAC_DIST_DIR:-$APP_ROOT/dist-native}"

RUN_TESTS=1
RUN_PACKAGE=1
RUN_VERIFY=1
RUN_SMOKE=1
MANIFEST_PATH=""

usage() {
  cat <<EOF
usage: $0 [--skip-tests] [--skip-package] [--skip-verify] [--skip-smoke] [--manifest <path>]

This script runs the native macOS release checklist:
  1. swift tests
  2. package-app.sh
  3. verify-release.sh
  4. release-smoke.sh
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-tests)
      RUN_TESTS=0
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
    --manifest)
      shift
      [[ $# -gt 0 ]] || usage
      MANIFEST_PATH="$1"
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

step() {
  echo
  echo "[native-release-checklist] $1"
}

resolve_latest_manifest() {
  /bin/ls -t "$DIST_DIR"/*.manifest.json 2>/dev/null | /usr/bin/head -n 1
}

if [[ "$RUN_TESTS" -eq 1 ]]; then
  step "swift tests"
  swift test --package-path "$APP_ROOT"
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

echo
echo "[native-release-checklist] Completed."
echo "[native-release-checklist] Manifest: $MANIFEST_PATH"
echo "[native-release-checklist] Remaining manual steps:"
echo "  [ ] Notarize with Scripts/notarize-app.sh if this build will be distributed externally."
echo "  [ ] Upload zip/dmg/checksums/manifest to the GitHub release."
echo "  [ ] Spot-check launch on a clean machine before announcing the release."
