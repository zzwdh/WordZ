#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_OUTPUT_PATH="${ROOT_DIR}/.build/reports/sentiment-benchmark-report.json"
GENERATED_REPORT_PATH="${ROOT_DIR}/.build/reports/sentiment-benchmark-report.generated.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      REPORT_OUTPUT_PATH="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

mkdir -p "$(dirname "$REPORT_OUTPUT_PATH")"

swift test --package-path "$ROOT_DIR" --filter SentimentBenchmarkTests
swift test --package-path "$ROOT_DIR" --filter SentimentBenchmarkReportTests
cp "$GENERATED_REPORT_PATH" "$REPORT_OUTPUT_PATH"

echo "Wrote sentiment benchmark report to $REPORT_OUTPUT_PATH"
