#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PACKAGE_PATH="${PACKAGE_PATH:-${ROOT_DIR}}"
FILTER="${1:-CompositionTests|SceneSyncPlanTests|RootContentSceneTests|EngineeringGuardrailTests|MainWorkspaceViewModelTests}"
GUARD_HOME="${ROOT_DIR}/.build/guard-home"
GUARD_CACHE="${GUARD_HOME}/.cache"
GUARD_CLANG_MODULE_CACHE="${ROOT_DIR}/.build/guard-clang-module-cache"

mkdir -p "${GUARD_CACHE}" "${GUARD_CLANG_MODULE_CACHE}"

echo "[engineering-guard] Running architecture guard..."
zsh "${ROOT_DIR}/Scripts/architecture-guard.sh"

echo "[engineering-guard] Running focused guardrail test suites..."
HOME="${GUARD_HOME}" \
XDG_CACHE_HOME="${GUARD_CACHE}" \
CLANG_MODULE_CACHE_PATH="${GUARD_CLANG_MODULE_CACHE}" \
swift test --package-path "${PACKAGE_PATH}" --filter "${FILTER}"

echo "[engineering-guard] Completed successfully."
