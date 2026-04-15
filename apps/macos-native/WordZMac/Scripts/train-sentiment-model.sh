#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATASET_DIR="$ROOT_DIR/Tests/WordZMacTests/Fixtures/Sentiment"
DATASET_PATH="$DATASET_DIR/sentiment-gold-v2.json"
MANIFEST_PATH="$DATASET_DIR/sentiment-gold-v2-manifest.json"
RESOURCE_DIR="$ROOT_DIR/Sources/WordZMac/Resources/Sentiment"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wordz-sentiment-train.XXXXXX")"
MODEL_PATH="$TEMP_DIR/SentimentTriClassifier.mlmodel"

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

swift "$ROOT_DIR/Scripts/generate-sentiment-gold.swift" \
  --output "$DATASET_PATH" \
  --manifest "$MANIFEST_PATH"

swift "$ROOT_DIR/Scripts/train-sentiment-model.swift" \
  --dataset "$DATASET_PATH" \
  --output "$MODEL_PATH" \
  --version "2.0" \
  --algorithm "embedding-logreg"

rm -rf "$RESOURCE_DIR/SentimentTriClassifier.mlmodelc"
xcrun coremlcompiler compile "$MODEL_PATH" "$RESOURCE_DIR" >/dev/null

echo "Compiled sentiment model into $RESOURCE_DIR/SentimentTriClassifier.mlmodelc"
