#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${ROOT_DIR}/.build/reports/1.4.0"
USER_FILE=""
USER_REPEAT_COUNT="3"
RUN_TOPIC="1"
RUN_SENTIMENT="1"
RUN_USER="0"
RUN_FIXED_USER_FIXTURE="1"
RUN_REFERENCE_USER_FIXTURE="1"
RUN_LIBRARY_BASELINE="1"
BASELINE_BUILD_CONFIGURATION="debug"
USER_BUILD_CONFIGURATION="debug"

usage() {
  cat >&2 <<'EOF'
Usage: Scripts/run-1.4-performance-baseline.sh [--output-dir <path>] [--user-file <path>] [--user-repeat <n>] [--release] [--release-user] [--skip-topic] [--skip-sentiment] [--skip-fixed-user] [--skip-reference-user] [--skip-library]

Runs the fixed 1.4.0 baseline reports:
  - topic benchmark report
  - sentiment benchmark report
  - fixed small user fixture benchmark report
  - bundled reference corpus benchmark report
  - Library open/refresh/search/import baseline report
  - optional external user corpus benchmark report

Use --release to run fixed reports through release SwiftPM tests and mark the
manifest as release. Use --release-user when only the optional external user
corpus should use release mode.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --user-file)
      USER_FILE="$2"
      RUN_USER="1"
      shift 2
      ;;
    --user-repeat)
      USER_REPEAT_COUNT="$2"
      shift 2
      ;;
    --release)
      BASELINE_BUILD_CONFIGURATION="release"
      USER_BUILD_CONFIGURATION="release"
      shift
      ;;
    --release-user)
      USER_BUILD_CONFIGURATION="release"
      shift
      ;;
    --skip-topic)
      RUN_TOPIC="0"
      shift
      ;;
    --skip-sentiment)
      RUN_SENTIMENT="0"
      shift
      ;;
    --skip-fixed-user)
      RUN_FIXED_USER_FIXTURE="0"
      shift
      ;;
    --skip-reference-user)
      RUN_REFERENCE_USER_FIXTURE="0"
      shift
      ;;
    --skip-library)
      RUN_LIBRARY_BASELINE="0"
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

if [[ "$OUTPUT_DIR" != /* ]]; then
  OUTPUT_DIR="${ROOT_DIR}/${OUTPUT_DIR}"
fi

mkdir -p "$OUTPUT_DIR"

TOPIC_REPORT="${OUTPUT_DIR}/topic-benchmark-report.json"
SENTIMENT_REPORT="${OUTPUT_DIR}/sentiment-benchmark-report.json"
FIXED_USER_REPORT="${OUTPUT_DIR}/user-benchmark.json"
REFERENCE_USER_REPORT="${OUTPUT_DIR}/user-benchmark-reference.json"
LIBRARY_REPORT="${OUTPUT_DIR}/library-baseline.json"
USER_REPORT="${OUTPUT_DIR}/user-benchmark-external.json"
MANIFEST_PATH="${OUTPUT_DIR}/baseline-manifest.json"

if [[ "$RUN_TOPIC" == "1" ]]; then
  TOPIC_ARGS=(--output "$TOPIC_REPORT")
  if [[ "$BASELINE_BUILD_CONFIGURATION" == "release" ]]; then
    TOPIC_ARGS+=(--release)
  fi
  zsh "${ROOT_DIR}/Scripts/run-topic-benchmark.sh" "${TOPIC_ARGS[@]}"
else
  echo "Skipped topic benchmark."
fi

if [[ "$RUN_SENTIMENT" == "1" ]]; then
  SENTIMENT_ARGS=(--output "$SENTIMENT_REPORT")
  if [[ "$BASELINE_BUILD_CONFIGURATION" == "release" ]]; then
    SENTIMENT_ARGS+=(--release)
  fi
  zsh "${ROOT_DIR}/Scripts/run-sentiment-benchmark.sh" "${SENTIMENT_ARGS[@]}"
else
  echo "Skipped sentiment benchmark."
fi

SWIFT_CONFIGURATION_ARGS=()
if [[ "$BASELINE_BUILD_CONFIGURATION" == "release" ]]; then
  SWIFT_CONFIGURATION_ARGS=(-c release)
fi

if [[ "$RUN_FIXED_USER_FIXTURE" == "1" ]]; then
  cd "$ROOT_DIR"
  WORDZ_1_4_BASELINE_BUILD_CONFIGURATION="$BASELINE_BUILD_CONFIGURATION" \
  WORDZ_1_4_BASELINE_OUTPUT_DIR="$OUTPUT_DIR" \
    swift test "${SWIFT_CONFIGURATION_ARGS[@]}" --filter UserBenchmarkTests/testRunFixedFixtureBenchmarkForRoadmapBaseline
else
  echo "Skipped fixed user fixture benchmark."
fi

if [[ "$RUN_REFERENCE_USER_FIXTURE" == "1" ]]; then
  cd "$ROOT_DIR"
  WORDZ_1_4_BASELINE_BUILD_CONFIGURATION="$BASELINE_BUILD_CONFIGURATION" \
  WORDZ_1_4_BASELINE_OUTPUT_DIR="$OUTPUT_DIR" \
    swift test "${SWIFT_CONFIGURATION_ARGS[@]}" --filter UserBenchmarkTests/testRunReferenceCorpusFixtureBenchmarkForRoadmapBaseline
else
  echo "Skipped reference corpus fixture benchmark."
fi

if [[ "$RUN_LIBRARY_BASELINE" == "1" ]]; then
  cd "$ROOT_DIR"
  WORDZ_1_4_LIBRARY_BASELINE_BUILD_CONFIGURATION="$BASELINE_BUILD_CONFIGURATION" \
  WORDZ_1_4_BASELINE_OUTPUT_DIR="$OUTPUT_DIR" \
    swift test "${SWIFT_CONFIGURATION_ARGS[@]}" --filter LibraryPerformanceBaselineTests/testRunLibraryPerformanceBaselineForRoadmap
else
  echo "Skipped Library baseline benchmark."
fi

if [[ "$RUN_USER" == "1" ]]; then
  USER_ARGS=(--file "$USER_FILE" --output "$USER_REPORT" --repeat "$USER_REPEAT_COUNT")
  if [[ "$USER_BUILD_CONFIGURATION" == "release" ]]; then
    USER_ARGS+=(--release)
  fi
  zsh "${ROOT_DIR}/Scripts/run-user-benchmark.sh" "${USER_ARGS[@]}"
else
  echo "Skipped user corpus benchmark. Pass --user-file <path> to include it."
fi

GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
cat > "$MANIFEST_PATH" <<EOF
{
  "schemaVersion": 1,
  "generatedAt": "$GENERATED_AT",
  "outputDirectory": "$OUTPUT_DIR",
  "reports": {
    "topic": {
      "enabled": $([[ "$RUN_TOPIC" == "1" ]] && echo true || echo false),
      "path": "$TOPIC_REPORT",
      "buildConfiguration": "$BASELINE_BUILD_CONFIGURATION"
    },
    "sentiment": {
      "enabled": $([[ "$RUN_SENTIMENT" == "1" ]] && echo true || echo false),
      "path": "$SENTIMENT_REPORT",
      "buildConfiguration": "$BASELINE_BUILD_CONFIGURATION"
    },
    "fixedUserFixture": {
      "enabled": $([[ "$RUN_FIXED_USER_FIXTURE" == "1" ]] && echo true || echo false),
      "path": "$FIXED_USER_REPORT",
      "repeatCount": 3,
      "buildConfiguration": "$BASELINE_BUILD_CONFIGURATION"
    },
    "referenceUserFixture": {
      "enabled": $([[ "$RUN_REFERENCE_USER_FIXTURE" == "1" ]] && echo true || echo false),
      "path": "$REFERENCE_USER_REPORT",
      "repeatCount": 3,
      "buildConfiguration": "$BASELINE_BUILD_CONFIGURATION"
    },
    "libraryBaseline": {
      "enabled": $([[ "$RUN_LIBRARY_BASELINE" == "1" ]] && echo true || echo false),
      "path": "$LIBRARY_REPORT",
      "repeatCount": ${WORDZ_1_4_LIBRARY_BASELINE_REPEAT_COUNT:-3},
      "buildConfiguration": "$BASELINE_BUILD_CONFIGURATION"
    },
    "userCorpus": {
      "enabled": $([[ "$RUN_USER" == "1" ]] && echo true || echo false),
      "path": "$USER_REPORT",
      "repeatCount": $USER_REPEAT_COUNT,
      "buildConfiguration": "$USER_BUILD_CONFIGURATION"
    }
  }
}
EOF

echo "Wrote 1.4.0 baseline manifest to $MANIFEST_PATH"
