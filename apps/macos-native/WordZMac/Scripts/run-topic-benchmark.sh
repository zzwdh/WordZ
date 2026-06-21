#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_OUTPUT_PATH="${ROOT_DIR}/.build/reports/topic-benchmark-report.json"
GENERATED_REPORT_PATH="${ROOT_DIR}/.build/reports/topic-benchmark-report.generated.json"
BUILD_CONFIGURATION="debug"

usage() {
  cat >&2 <<'EOF'
Usage: Scripts/run-topic-benchmark.sh [--output <path>] [--release]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      REPORT_OUTPUT_PATH="$2"
      shift 2
      ;;
    --release)
      BUILD_CONFIGURATION="release"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

mkdir -p "$(dirname "$REPORT_OUTPUT_PATH")"
cd "$ROOT_DIR"

SWIFT_CONFIGURATION_ARGS=()
if [[ "$BUILD_CONFIGURATION" == "release" ]]; then
  SWIFT_CONFIGURATION_ARGS=(-c release)
fi

swift test "${SWIFT_CONFIGURATION_ARGS[@]}" --filter TopicBenchmarkTests
cp "$GENERATED_REPORT_PATH" "$REPORT_OUTPUT_PATH"

HARDWARE_SUMMARY="$(grep -m 1 '"summaryLine"' "$REPORT_OUTPUT_PATH" | sed -E 's/^[[:space:]]*"summaryLine" : "([^"]+)".*/\1/')"
if [[ -n "$HARDWARE_SUMMARY" ]]; then
  echo "Topic benchmark hardware: $HARDWARE_SUMMARY"
fi
echo "Wrote topic benchmark report to $REPORT_OUTPUT_PATH"
