#!/bin/zsh
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <manifest-or-checksums-path>" >&2
  exit 1
fi

INPUT_PATH="$1"
if [[ ! -f "$INPUT_PATH" ]]; then
  echo "file not found: $INPUT_PATH" >&2
  exit 1
fi

if [[ "$INPUT_PATH" == *.manifest.json ]]; then
  CHECKSUMS_PATH="${INPUT_PATH%.manifest.json}.checksums.txt"
else
  CHECKSUMS_PATH="$INPUT_PATH"
fi

if [[ ! -f "$CHECKSUMS_PATH" ]]; then
  echo "checksums file not found: $CHECKSUMS_PATH" >&2
  exit 1
fi

DIST_DIR="$(cd "$(dirname "$CHECKSUMS_PATH")" && pwd)"
CHECKSUMS_NAME="${CHECKSUMS_PATH##*/}"

while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" ]] && continue
  expected_sha="${line%% *}"
  file_name="${line##* }"
  target_path="$DIST_DIR/$file_name"
  if [[ ! -f "$target_path" ]]; then
    echo "missing artifact: $target_path" >&2
    exit 1
  fi
  actual_sha="$(/usr/bin/shasum -a 256 "$target_path" | /usr/bin/awk '{print $1}')"
  if [[ "$actual_sha" != "$expected_sha" ]]; then
    echo "checksum mismatch: $file_name" >&2
    echo "expected: $expected_sha" >&2
    echo "actual:   $actual_sha" >&2
    exit 1
  fi
  echo "verified: $file_name"
done < "$CHECKSUMS_PATH"

echo "Verified release artifacts in $DIST_DIR"
