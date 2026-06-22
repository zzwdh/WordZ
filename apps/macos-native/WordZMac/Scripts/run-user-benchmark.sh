#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FILE_PATH=""
REPORT_OUTPUT_PATH="${ROOT_DIR}/.build/reports/user-benchmark.json"
MIN_TOPIC_SIZE="2"
RUN_TOPICS="1"
RUN_SENTIMENT="1"
RUN_KWIC="1"
SENTIMENT_UNIT="sentence"
SENTIMENT_BACKEND="lexicon"
BUILD_CONFIGURATION="debug"
REPEAT_COUNT="1"
DISABLE_SWIFTPM_SANDBOX="0"

usage() {
  cat >&2 <<'EOF'
Usage: Scripts/run-user-benchmark.sh --file <path> [--output <path>] [--min-topic-size <n>] [--sentiment-unit document|sentence] [--sentiment-backend lexicon|coreML] [--release] [--repeat <n>] [--disable-swiftpm-sandbox] [--skip-topics] [--skip-sentiment] [--skip-kwic]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)
      FILE_PATH="$2"
      shift 2
      ;;
    --output)
      REPORT_OUTPUT_PATH="$2"
      shift 2
      ;;
    --min-topic-size)
      MIN_TOPIC_SIZE="$2"
      shift 2
      ;;
    --sentiment-unit)
      SENTIMENT_UNIT="$2"
      shift 2
      ;;
    --sentiment-backend)
      SENTIMENT_BACKEND="$2"
      shift 2
      ;;
    --release)
      BUILD_CONFIGURATION="release"
      shift
      ;;
    --repeat)
      REPEAT_COUNT="$2"
      shift 2
      ;;
    --disable-swiftpm-sandbox)
      DISABLE_SWIFTPM_SANDBOX="1"
      shift
      ;;
    --skip-topics)
      RUN_TOPICS="0"
      shift
      ;;
    --skip-sentiment)
      RUN_SENTIMENT="0"
      shift
      ;;
    --skip-kwic)
      RUN_KWIC="0"
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

if [[ -z "$FILE_PATH" ]]; then
  echo "Missing required --file argument." >&2
  usage
  exit 1
fi

if [[ ! -f "$FILE_PATH" ]]; then
  echo "Benchmark file does not exist: $FILE_PATH" >&2
  exit 1
fi
FILE_PATH="$(cd "$(dirname "$FILE_PATH")" && pwd)/$(basename "$FILE_PATH")"
if [[ "$REPORT_OUTPUT_PATH" != /* ]]; then
  REPORT_OUTPUT_PATH="${ROOT_DIR}/${REPORT_OUTPUT_PATH}"
fi

mkdir -p "$(dirname "$REPORT_OUTPUT_PATH")"
cd "$ROOT_DIR"

SWIFT_CONFIGURATION_ARGS=()
if [[ "$DISABLE_SWIFTPM_SANDBOX" == "1" ]]; then
  SWIFT_CONFIGURATION_ARGS+=(--disable-sandbox)
fi
if [[ "$BUILD_CONFIGURATION" == "release" ]]; then
  SWIFT_CONFIGURATION_ARGS+=(-c release)
fi

WORDZ_USER_BENCHMARK_FILE="$FILE_PATH" \
WORDZ_USER_BENCHMARK_OUTPUT="$REPORT_OUTPUT_PATH" \
WORDZ_USER_BENCHMARK_BUILD_CONFIGURATION="$BUILD_CONFIGURATION" \
WORDZ_USER_BENCHMARK_MIN_TOPIC_SIZE="$MIN_TOPIC_SIZE" \
WORDZ_USER_BENCHMARK_RUN_TOPICS="$RUN_TOPICS" \
WORDZ_USER_BENCHMARK_RUN_SENTIMENT="$RUN_SENTIMENT" \
WORDZ_USER_BENCHMARK_RUN_KWIC="$RUN_KWIC" \
WORDZ_USER_BENCHMARK_SENTIMENT_UNIT="$SENTIMENT_UNIT" \
WORDZ_USER_BENCHMARK_SENTIMENT_BACKEND="$SENTIMENT_BACKEND" \
WORDZ_USER_BENCHMARK_REPEAT_COUNT="$REPEAT_COUNT" \
swift test "${SWIFT_CONFIGURATION_ARGS[@]}" --filter UserBenchmarkTests

echo "Wrote user benchmark report to $REPORT_OUTPUT_PATH"
