#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="${1:-${REPO_ROOT}/Sources/WordZMac}"
PACKAGE_FILE="${REPO_ROOT}/Package.swift"
FAILED=0

readonly VIEWMODEL_ROOT_DIRS=(
  Library
  Pages
  Settings
  Workspace
)

readonly VIEW_ROOT_DIRS=(
  Windows
  Workbench
  Workspace
)

readonly PACKAGE_TARGETS=(
  WordZMac
  WordZAppShell
  WordZWorkspaceFeature
  WordZLibraryFeature
  WordZWorkbenchUI
  WordZWindowing
  WordZWorkspaceCore
  WordZAnalysis
  WordZStorage
  WordZEngine
  WordZHost
  WordZExport
  WordZDiagnostics
  WordZShared
)

print_check() {
  echo "[architecture-guard] $1"
}

mark_failure() {
  echo "[architecture-guard][FAIL] $1"
  FAILED=1
}

count_root_swift_files() {
  find "$ROOT_DIR/$1" -maxdepth 1 -type f -name '*.swift' | wc -l | tr -d ' '
}

collect_root_dirs() {
  find "$ROOT_DIR/$1" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort -u
}

check_allowed_root_dirs() {
  local directory="$1"
  shift
  local expected=("$@")
  local current=()
  local unexpected=()
  local entry

  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    current+=("$entry")
  done < <(collect_root_dirs "$directory")

  for entry in "${current[@]}"; do
    if [[ ! " ${expected[*]} " =~ " ${entry} " ]]; then
      unexpected+=("$entry")
    fi
  done

  if [[ ${#unexpected[@]} -gt 0 ]]; then
    mark_failure "$directory gained unexpected first-level directories: ${unexpected[*]}"
  fi

  echo "[architecture-guard] $directory first-level dirs: ${current[*]}"
}

check_legacy_services_removed() {
  print_check "Checking legacy Services placeholder removal..."
  if [[ -d "$ROOT_DIR/Services" ]]; then
    mark_failure "Expected $ROOT_DIR/Services to be removed."
    find "$ROOT_DIR/Services" -maxdepth 2 -print
  fi
}

check_package_declares_expected_targets() {
  print_check "Checking Package.swift declares the multi-target package graph..."
  local target

  for target in "${PACKAGE_TARGETS[@]}"; do
    if ! rg -q "name: \"$target\"" "$PACKAGE_FILE"; then
      mark_failure "Expected Package.swift to declare target/product $target."
    fi
  done
}

check_root_level_boundaries() {
  print_check "Checking root-level placement boundaries..."

  local models_count
  models_count=$(count_root_swift_files "Models")
  if [[ "$models_count" -gt 0 ]]; then
    mark_failure "Models should not contain root-level Swift files. Found $models_count."
    find "$ROOT_DIR/Models" -maxdepth 1 -type f -name '*.swift'
  fi

  local viewmodels_count
  viewmodels_count=$(count_root_swift_files "ViewModels")
  if [[ "$viewmodels_count" -gt 0 ]]; then
    mark_failure "ViewModels should not contain root-level Swift files. Found $viewmodels_count."
    find "$ROOT_DIR/ViewModels" -maxdepth 1 -type f -name '*.swift'
  fi

  local views_count
  views_count=$(count_root_swift_files "Views")
  if [[ "$views_count" -gt 0 ]]; then
    mark_failure "Views should not contain root-level Swift files. Found $views_count."
    find "$ROOT_DIR/Views" -maxdepth 1 -type f -name '*.swift'
  fi

  check_allowed_root_dirs "ViewModels" "${VIEWMODEL_ROOT_DIRS[@]}"
  check_allowed_root_dirs "Views" "${VIEW_ROOT_DIRS[@]}"

  echo "[architecture-guard] Root-level counts: Models=$models_count ViewModels=$viewmodels_count Views=$views_count"
}

check_app_composition_has_no_ui_imports() {
  print_check "Checking App/Composition for UI framework imports..."
  local pattern='^import SwiftUI|^import AppKit'
  local result
  result=$(rg -n --glob '*.swift' "$pattern" "$ROOT_DIR/App/Composition" || true)

  if [[ -n "$result" ]]; then
    mark_failure "App/Composition should stay free of SwiftUI/AppKit imports."
    echo "$result"
  fi
}

check_viewmodels_do_not_import_appkit() {
  print_check "Checking ViewModels for AppKit imports..."
  local result
  result=$(rg -n --glob '*.swift' '^import AppKit' "$ROOT_DIR/ViewModels" || true)

  if [[ -n "$result" ]]; then
    mark_failure "ViewModels should stay free of AppKit imports."
    echo "$result"
  fi
}

check_composition_types_stay_inside_app() {
  print_check "Checking concrete composition types stay inside App..."
  local pattern='NativeAppContainer|NativeAppLiveComposition|HostDomainFactory|ExportDomainFactory|WorkspaceDomainFactory|StorageDomainFactory|EngineDomainFactory|DiagnosticsDomainFactory'
  local result
  result=$(find "$ROOT_DIR" -path "$ROOT_DIR/App" -prune -o -type f -name '*.swift' -print0 \
    | xargs -0 rg -n "$pattern" || true)

  if [[ -n "$result" ]]; then
    mark_failure "Concrete App/Composition types should not leak outside App."
    echo "$result"
  fi
}

check_composition_has_no_workflow_mutation() {
  print_check "Checking App/Composition stays free of workflow mutation..."
  local pattern='refreshAll\(|newWorkspace\(|restoreSavedWorkspace\(|presentWelcome\(|dismissWelcome\(|syncSceneGraph\(|selectedTab\s*=|isWelcomePresented\s*=|openSelectedCorpus\(|exportCurrent\(|checkForUpdatesNow\(|downloadLatestUpdate\(|runStats\(|runWord\(|runTokenize\(|runTopics\(|runCompare\(|runKeyword\(|runChiSquare\(|runNgram\(|runKWIC\(|runCollocate\(|runLocator\('
  local result
  result=$(rg -n "$pattern" "$ROOT_DIR/App/Composition" || true)

  if [[ -n "$result" ]]; then
    mark_failure "App/Composition should assemble dependencies, not mutate workflow state."
    echo "$result"
  fi
}

check_non_ui_domains_do_not_import_ui() {
  print_check "Checking non-UI domains for UI framework imports..."
  local pattern='^import SwiftUI|^import AppKit'
  local result
  result=$(rg -n "$pattern" \
    "$ROOT_DIR/Analysis" \
    "$ROOT_DIR/Storage" \
    "$ROOT_DIR/Engine" || true)

  if [[ -n "$result" ]]; then
    mark_failure "Found UI framework imports in non-UI domains."
    echo "$result"
  fi
}

check_workspace_does_not_reference_views() {
  print_check "Checking Workspace domain for view-layer coupling..."
  local pattern='import SwiftUI|StatsView|WordView|TokenizeView|TopicsView|CompareView|KeywordView|ChiSquareView|NgramView|KWICView|CollocateView|LocatorView|RootContentView'
  local result
  result=$(rg -n "$pattern" "$ROOT_DIR/Workspace" || true)
  if [[ -n "$result" ]]; then
    mark_failure "Workspace should not directly reference view-layer types."
    echo "$result"
  fi
}

check_workspace_avoids_concrete_host_ui_types() {
  print_check "Checking Workspace domain stays off concrete host UI types..."
  local pattern='NativeWindowDocumentController|\bNSWindow\b|\bNSPasteboard\b|\bNSOpenPanel\b|\bNSSavePanel\b|\bNSAlert\b|\bNSWorkspace\b|\bNSDocumentController\b|^import AppKit'
  local result
  result=$(rg -n "$pattern" "$ROOT_DIR/Workspace" || true)
  if [[ -n "$result" ]]; then
    mark_failure "Workspace should depend on host protocols/services, not concrete AppKit UI types."
    echo "$result"
  fi
}

check_analysis_does_not_reference_shell_types() {
  print_check "Checking Analysis domain for shell/repository coupling..."
  local pattern='MainWorkspaceViewModel|WorkspaceFlowCoordinator|WorkspaceActionDispatcher|RootContentView|NativeWorkspaceRepository|NativeHostActionService|NativeDialogServicing|QuickLookPreviewFileService|WorkspaceSceneStore|WorkspaceSceneGraphStore|WorkspaceShellViewModel'
  local result
  result=$(rg -n "$pattern" "$ROOT_DIR/Analysis" || true)
  if [[ -n "$result" ]]; then
    mark_failure "Analysis should not directly reference workspace shell types."
    echo "$result"
  fi
}

check_storage_does_not_reference_workspace_or_host_shell() {
  print_check "Checking Storage domain for workspace/host shell coupling..."
  local pattern='MainWorkspaceViewModel|WorkspaceFlowCoordinator|WorkspaceActionDispatcher|RootContentView|NativeHostActionService|NativeDialogServicing|QuickLookPreviewFileService|WorkspaceSceneStore|WorkspaceSceneGraphStore|WorkspaceShellViewModel'
  local result
  result=$(rg -n "$pattern" "$ROOT_DIR/Storage" || true)
  if [[ -n "$result" ]]; then
    mark_failure "Storage should not directly reference workspace shell or host UI services."
    echo "$result"
  fi
}

check_platform_api_boundaries() {
  print_check "Checking macOS 15+/Liquid Glass APIs stay inside the window capability layer..."
  local allowed_files=(
    "$ROOT_DIR/App/Windowing/NativePlatformCapabilities+Decorations.swift"
    "$ROOT_DIR/Views/Windows/AdaptiveWindowToolbarSupport.swift"
    "$ROOT_DIR/Views/Workspace/MainWorkspaceSplitContainer.swift"
  )
  local pattern='glassEffect|GlassEffectContainer|glassEffectID|toolbarBackgroundVisibility|toolbarVisibility|defaultWindowPlacement|windowIdealPlacement|WindowDragGesture|allowsWindowActivationEvents|searchToolbarBehavior|ToolbarSpacer|sharedBackgroundVisibility|backgroundExtensionEffect|scrollEdgeEffectStyle|topAlignedAccessoryViewControllers|automaticallyAdjustsSafeAreaInsets|NSSplitViewItemAccessoryViewController|#available\(macOS (15\.0|26\.0)'
  local find_args=("$ROOT_DIR" -type f -name '*.swift')
  local allowed_file
  for allowed_file in "${allowed_files[@]}"; do
    find_args+=( ! -path "$allowed_file" )
  done

  local result
  result=$(find "${find_args[@]}" -print0 | xargs -0 rg -n "$pattern" || true)

  if [[ -n "$result" ]]; then
    mark_failure "macOS 15+/26 window APIs should stay inside the approved capability/toolbar/accessory layers."
    echo "$result"
  fi
}

main() {
  check_package_declares_expected_targets
  check_legacy_services_removed
  check_root_level_boundaries
  check_app_composition_has_no_ui_imports
  check_viewmodels_do_not_import_appkit
  check_composition_types_stay_inside_app
  check_composition_has_no_workflow_mutation
  check_non_ui_domains_do_not_import_ui
  check_workspace_does_not_reference_views
  check_workspace_avoids_concrete_host_ui_types
  check_analysis_does_not_reference_shell_types
  check_storage_does_not_reference_workspace_or_host_shell
  check_platform_api_boundaries

  if [[ "$FAILED" -ne 0 ]]; then
    echo "[architecture-guard] Completed with failures."
    exit 1
  fi

  echo "[architecture-guard] All checks passed."
}

main "$@"
