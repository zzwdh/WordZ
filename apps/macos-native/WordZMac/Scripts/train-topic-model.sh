#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DATASET_PATH="$ROOT_DIR/Tests/WordZMacTests/Fixtures/Topics/topic-training-corpus-v2.json"
OUTPUT_PATH="$ROOT_DIR/Sources/WordZMac/Resources/TopicLocalEmbeddingModel.json"

swift "$ROOT_DIR/Scripts/train-topic-model.swift" \
  --dataset "$DATASET_PATH" \
  --output "$OUTPUT_PATH" \
  --version "4" \
  --revision "2026-04-local-v4"

echo "Wrote topic model resource to $OUTPUT_PATH"
