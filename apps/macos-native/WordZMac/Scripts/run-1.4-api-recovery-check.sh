#!/bin/zsh
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
BUILD_CONFIGURATION="release"
DISABLE_SWIFTPM_SANDBOX="${WORDZ_MAC_DISABLE_SWIFTPM_SANDBOX:-0}"
LOCAL_HOME="${WORDZ_MAC_LOCAL_HOME:-$ROOT_DIR/.release-home}"
LOCAL_CLANG_CACHE="${WORDZ_MAC_LOCAL_CLANG_CACHE:-$ROOT_DIR/.release-clang-cache}"
LOCAL_SWIFTPM_CACHE="${WORDZ_MAC_LOCAL_SWIFTPM_CACHE:-$ROOT_DIR/.release-swiftpm-cache}"

usage() {
  cat >&2 <<'USAGE'
usage: run-1.4-api-recovery-check.sh [--debug|--release] [--disable-swiftpm-sandbox]

Runs the focused 1.4.0 API recovery gate:
- disabled API access does not run network-backed actions
- API credential, rate limit, offline, and cancellation failures keep local analysis available
- API failure messages avoid raw credential/query-token leakage
USAGE
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)
      BUILD_CONFIGURATION="debug"
      shift
      ;;
    --release)
      BUILD_CONFIGURATION="release"
      shift
      ;;
    --disable-swiftpm-sandbox)
      DISABLE_SWIFTPM_SANDBOX="1"
      shift
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage
      ;;
  esac
done

SWIFT_TEST_ARGS=(--package-path "$ROOT_DIR")
if [[ "$BUILD_CONFIGURATION" == "release" ]]; then
  SWIFT_TEST_ARGS+=(-c release)
fi
if [[ "$DISABLE_SWIFTPM_SANDBOX" == "1" ]]; then
  SWIFT_TEST_ARGS+=(--disable-sandbox)
fi

mkdir -p "$LOCAL_HOME" "$LOCAL_CLANG_CACHE" "$LOCAL_SWIFTPM_CACHE"

echo "[1.4-api-recovery] configuration: $BUILD_CONFIGURATION"
HOME="$LOCAL_HOME" CLANG_MODULE_CACHE_PATH="$LOCAL_CLANG_CACHE" SWIFTPM_MODULECACHE_OVERRIDE="$LOCAL_SWIFTPM_CACHE" \
swift test "${SWIFT_TEST_ARGS[@]}" \
  --filter MainWorkspaceViewModelTests/testCheckForUpdatesDoesNotCallServiceWhenAPIIsDisabled \
  --filter MainWorkspaceViewModelTests/testAPIConnectionCheckDoesNotRunWhenAPIIsDisabled \
  --filter WorkspaceFailurePathTests/testAPIConnectionCredentialFailureShowsRecoveryWithoutLeakingToken \
  --filter WorkspaceFailurePathTests/testAPIConnectionRateLimitFailureKeepsLocalAnalysisRecovery \
  --filter WorkspaceFailurePathTests/testAPIConnectionOfflineFailureRedactsCredentialAndQueryTokens \
  --filter WorkspaceFailurePathTests/testCancelledAPIConnectionDoesNotProduceIssueBanner \
  --filter WorkspaceFailurePathTests/testUpdateFailureProducesRetryableIssueBanner \
  --filter WorkspaceFailurePathTests/testCancelledUpdateCheckDoesNotProduceIssueBanner

echo "[1.4-api-recovery] API failure recovery gate passed."
