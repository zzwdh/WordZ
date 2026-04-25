#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATASET_DIR="$ROOT_DIR/Tests/WordZMacTests/Fixtures/Sentiment"
DEFAULT_RESOURCE_DIR="$ROOT_DIR/Sources/WordZMac/Resources/Sentiment"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wordz-sentiment-train.XXXXXX")"

DATASET_PROFILE="mixed-baseline"
DATASET_PATH=""
DATASET_MANIFEST_PATH=""
RESOURCE_DIR="$DEFAULT_RESOURCE_DIR"
EVALUATION_OUTPUT_PATH=""
MODEL_MANIFEST_EXPORT_PATH=""
SYNC_BUNDLED_MODEL=""
SKIP_BENCHMARKS=0

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dataset-profile)
      DATASET_PROFILE="$2"
      shift 2
      ;;
    --dataset-path)
      DATASET_PATH="$2"
      shift 2
      ;;
    --dataset-manifest-path)
      DATASET_MANIFEST_PATH="$2"
      shift 2
      ;;
    --resource-dir)
      RESOURCE_DIR="$2"
      shift 2
      ;;
    --evaluation-output)
      EVALUATION_OUTPUT_PATH="$2"
      shift 2
      ;;
    --model-manifest-output)
      MODEL_MANIFEST_EXPORT_PATH="$2"
      shift 2
      ;;
    --sync-bundled-model)
      SYNC_BUNDLED_MODEL="1"
      shift
      ;;
    --no-sync-bundled-model)
      SYNC_BUNDLED_MODEL="0"
      shift
      ;;
    --skip-benchmarks)
      SKIP_BENCHMARKS="1"
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

MODEL_PATH="$TEMP_DIR/SentimentTriClassifier.mlmodel"
MANIFEST_OUTPUT_PATH="$TEMP_DIR/SentimentModelManifest.json"

case "$DATASET_PROFILE" in
  mixed-baseline)
    [[ -n "$DATASET_PATH" ]] || DATASET_PATH="$DATASET_DIR/sentiment-gold-v2.json"
    [[ -n "$DATASET_MANIFEST_PATH" ]] || DATASET_MANIFEST_PATH="$DATASET_DIR/sentiment-gold-v2-manifest.json"
    [[ -n "$EVALUATION_OUTPUT_PATH" ]] || EVALUATION_OUTPUT_PATH="$DATASET_DIR/sentiment-model-evaluation-mixed-baseline.json"
    [[ -n "$SYNC_BUNDLED_MODEL" ]] || SYNC_BUNDLED_MODEL="1"
    DATASET_VERSION="v2"
    DATASET_NOTES="Templated English-tuned starter gold pack for benchmark/calibration. Replace or augment with manually adjudicated corpus examples for production evaluation."
    MODEL_VERSION="2"
    EVALUATION_TARGET="mixed-baseline"
    GENERATE_ARGS=(
      --output "$DATASET_PATH"
      --manifest "$DATASET_MANIFEST_PATH"
      --version "$DATASET_VERSION"
      --notes "$DATASET_NOTES"
    )
    ;;
  news-focused)
    [[ -n "$DATASET_PATH" ]] || DATASET_PATH="$DATASET_DIR/sentiment-gold-v3.json"
    [[ -n "$DATASET_MANIFEST_PATH" ]] || DATASET_MANIFEST_PATH="$DATASET_DIR/sentiment-gold-v3-manifest.json"
    [[ -n "$EVALUATION_OUTPUT_PATH" ]] || EVALUATION_OUTPUT_PATH="$DATASET_DIR/sentiment-model-evaluation-news-focused.json"
    [[ -n "$SYNC_BUNDLED_MODEL" ]] || SYNC_BUNDLED_MODEL="0"
    DATASET_VERSION="v3"
    DATASET_NOTES="Manually adjudicated English news-oriented benchmark focused on procedural neutrality, quoted language, reported speech, commentary, and stance framing."
    MODEL_VERSION="2"
    EVALUATION_TARGET="news-focused"
    GENERATE_ARGS=(
      --input "$DATASET_PATH"
      --manifest "$DATASET_MANIFEST_PATH"
      --version "$DATASET_VERSION"
      --notes "$DATASET_NOTES"
    )
    ;;
  *)
    echo "Unsupported dataset profile: $DATASET_PROFILE" >&2
    exit 1
    ;;
esac

swift "$ROOT_DIR/Scripts/generate-sentiment-gold.swift" "${GENERATE_ARGS[@]}"

swift "$ROOT_DIR/Scripts/train-sentiment-model.swift" \
  --dataset "$DATASET_PATH" \
  --output "$MODEL_PATH" \
  --version "$MODEL_VERSION" \
  --algorithm "embedding-logreg" \
  --dataset-profile "$DATASET_PROFILE" \
  --evaluation-target "$EVALUATION_TARGET" \
  --provider-id "bundled-coreml-sentiment" \
  --model-resource "SentimentTriClassifier" \
  --manifest-out "$MANIFEST_OUTPUT_PATH" \
  --evaluation-out "$EVALUATION_OUTPUT_PATH" \
  --confidence-floor "0.55" \
  --margin-floor "0.12" \
  --max-characters "1600"

if [[ -n "$MODEL_MANIFEST_EXPORT_PATH" ]]; then
  mkdir -p "$(dirname "$MODEL_MANIFEST_EXPORT_PATH")"
  cp "$MANIFEST_OUTPUT_PATH" "$MODEL_MANIFEST_EXPORT_PATH"
fi

if [[ "$SYNC_BUNDLED_MODEL" == "1" ]]; then
  rm -rf "$RESOURCE_DIR/SentimentTriClassifier.mlmodelc"
  xcrun coremlcompiler compile "$MODEL_PATH" "$RESOURCE_DIR" >/dev/null
  cp "$MANIFEST_OUTPUT_PATH" "$RESOURCE_DIR/SentimentModelManifest.json"
  echo "Updated manifest at $RESOURCE_DIR/SentimentModelManifest.json"
  echo "Compiled sentiment model into $RESOURCE_DIR/SentimentTriClassifier.mlmodelc"
else
  echo "Skipped bundled model sync for dataset profile $DATASET_PROFILE"
fi

if [[ "$SKIP_BENCHMARKS" != "1" ]]; then
  swift test --package-path "$ROOT_DIR" --filter SentimentBenchmarkTests
fi

echo "Wrote evaluation report to $EVALUATION_OUTPUT_PATH"
