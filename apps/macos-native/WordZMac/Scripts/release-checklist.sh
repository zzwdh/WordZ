#!/bin/zsh
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/release-support.sh"
APP_ROOT="$(release_support_app_root)"
DIST_DIR="$(release_support_dist_dir)"
SCRIPT_NAME="${0:t}"
DISABLE_SWIFTPM_SANDBOX="${WORDZ_MAC_DISABLE_SWIFTPM_SANDBOX:-0}"
SKIP_DMG="${WORDZ_MAC_SKIP_DMG:-0}"
LOCAL_HOME="${WORDZ_MAC_LOCAL_HOME:-$APP_ROOT/.release-home}"
LOCAL_CLANG_CACHE="${WORDZ_MAC_LOCAL_CLANG_CACHE:-$APP_ROOT/.release-clang-cache}"
LOCAL_SWIFTPM_CACHE="${WORDZ_MAC_LOCAL_SWIFTPM_CACHE:-$APP_ROOT/.release-swiftpm-cache}"

RUN_METADATA=1
RUN_TESTS=1
RUN_UI_PERFORMANCE=1
RUN_API_GATES=1
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
usage: $SCRIPT_NAME [--skip-metadata] [--skip-tests] [--skip-ui-performance] [--skip-api-gates] [--skip-architecture] [--skip-package] [--skip-verify] [--skip-smoke] [--disable-swiftpm-sandbox] [--skip-dmg] [--notarize] [--upload] [--manifest <path>] [--notes-file <path>] [--repo <owner/repo>] [--tag <tag>] [--title <title>] [--draft] [--prerelease] [--clobber]

This script runs the native macOS release checklist:
  1. release-metadata-check.sh
  2. swift tests
  3. 1.4 UI performance gate
  4. 1.4 API privacy/recovery gates
  5. architecture-guard.sh
  6. package-app.sh
  7. verify-release.sh
  8. release-smoke.sh
  9. optional notarize-app.sh
  10. optional release-upload.sh
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
    --skip-ui-performance)
      RUN_UI_PERFORMANCE=0
      ;;
    --skip-api-gates)
      RUN_API_GATES=0
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
    --disable-swiftpm-sandbox)
      DISABLE_SWIFTPM_SANDBOX=1
      ;;
    --skip-dmg)
      SKIP_DMG=1
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

if [[ "$SKIP_DMG" == "1" && ( "$RUN_NOTARIZE" -eq 1 || "$RUN_UPLOAD" -eq 1 ) ]]; then
  echo "--skip-dmg is only for local preflight packaging; do not combine it with --notarize or --upload." >&2
  exit 1
fi

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
  mkdir -p "$LOCAL_HOME" "$LOCAL_CLANG_CACHE" "$LOCAL_SWIFTPM_CACHE"
  swift_test_args=(--package-path "$APP_ROOT")
  if [[ "$DISABLE_SWIFTPM_SANDBOX" == "1" ]]; then
    swift_test_args+=(--disable-sandbox)
  fi
  HOME="$LOCAL_HOME" CLANG_MODULE_CACHE_PATH="$LOCAL_CLANG_CACHE" SWIFTPM_MODULECACHE_OVERRIDE="$LOCAL_SWIFTPM_CACHE" \
  swift test "${swift_test_args[@]}"
fi

if [[ "$RUN_UI_PERFORMANCE" -eq 1 ]]; then
  step "1.4 UI performance gate"
  release_gate_args=(--release)
  if [[ "$DISABLE_SWIFTPM_SANDBOX" == "1" ]]; then
    release_gate_args+=(--disable-swiftpm-sandbox)
  fi
  zsh "$SCRIPT_DIR/run-1.4-ui-performance-check.sh" "${release_gate_args[@]}"
fi

if [[ "$RUN_API_GATES" -eq 1 ]]; then
  step "1.4 API privacy gate"
  release_gate_args=(--release)
  if [[ "$DISABLE_SWIFTPM_SANDBOX" == "1" ]]; then
    release_gate_args+=(--disable-swiftpm-sandbox)
  fi
  zsh "$SCRIPT_DIR/run-1.4-api-privacy-check.sh" "${release_gate_args[@]}"

  step "1.4 API recovery gate"
  zsh "$SCRIPT_DIR/run-1.4-api-recovery-check.sh" "${release_gate_args[@]}"
fi

if [[ "$RUN_ARCHITECTURE" -eq 1 ]]; then
  step "architecture guard"
  zsh "$SCRIPT_DIR/architecture-guard.sh"
fi

if [[ "$RUN_PACKAGE" -eq 1 ]]; then
  step "package artifacts"
  WORDZ_MAC_DISABLE_SWIFTPM_SANDBOX="$DISABLE_SWIFTPM_SANDBOX" WORDZ_MAC_SKIP_DMG="$SKIP_DMG" zsh "$SCRIPT_DIR/package-app.sh"
  MANIFEST_PATH="$(resolve_latest_manifest)"
fi

NEEDS_MANIFEST=0
if [[ "$RUN_VERIFY" -eq 1 || "$RUN_SMOKE" -eq 1 || "$RUN_NOTARIZE" -eq 1 || "$RUN_UPLOAD" -eq 1 ]]; then
  NEEDS_MANIFEST=1
fi

if [[ "$NEEDS_MANIFEST" -eq 1 ]]; then
  if [[ -z "$MANIFEST_PATH" ]]; then
    MANIFEST_PATH="$(resolve_latest_manifest)"
  fi

  [[ -n "$MANIFEST_PATH" ]] || { echo "unable to resolve manifest path" >&2; exit 1; }
fi

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
if [[ -n "$MANIFEST_PATH" ]]; then
  echo "[native-release-checklist] Manifest: $MANIFEST_PATH"
else
  echo "[native-release-checklist] Manifest: not required for the selected steps."
fi
echo "[native-release-checklist] Remaining manual steps:"
if [[ "$RUN_PACKAGE" -eq 0 ]]; then
  echo "  [ ] Run package artifacts with Scripts/package-app.sh on the release machine."
elif [[ "$SKIP_DMG" == "1" ]]; then
  echo "  [ ] Re-run package artifacts without --skip-dmg on a machine where hdiutil create succeeds."
fi
if [[ "$RUN_NOTARIZE" -eq 0 ]]; then
  echo "  [ ] Notarize with Scripts/notarize-app.sh if this build will be distributed externally."
fi
if [[ "$RUN_UPLOAD" -eq 0 ]]; then
  echo "  [ ] Upload zip/dmg/pkg/checksums/manifest to the GitHub release."
fi
echo "  [ ] Spot-check launch on a clean machine before announcing the release."
