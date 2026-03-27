#!/bin/zsh
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <artifact-path>" >&2
  exit 1
fi

ARTIFACT_PATH="$1"
NOTARY_PROFILE="${WORDZ_MAC_NOTARY_PROFILE:-}"

if [[ -z "$NOTARY_PROFILE" ]]; then
  echo "WORDZ_MAC_NOTARY_PROFILE is required." >&2
  exit 1
fi

xcrun notarytool submit "$ARTIFACT_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

if [[ -d "$ARTIFACT_PATH" && "${ARTIFACT_PATH##*.}" == "app" ]]; then
  xcrun stapler staple "$ARTIFACT_PATH"
elif [[ -f "$ARTIFACT_PATH" ]]; then
  xcrun stapler staple "$ARTIFACT_PATH" || true
fi

echo "$ARTIFACT_PATH"
