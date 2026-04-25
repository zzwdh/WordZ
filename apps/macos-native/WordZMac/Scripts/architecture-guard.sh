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

check_file_line_limit() {
  local file_path="$1"
  local max_lines="$2"
  if [[ ! -f "$file_path" ]]; then
    mark_failure "Expected file to exist: $file_path"
    return
  fi

  local line_count
  line_count=$(wc -l < "$file_path" | tr -d ' ')
  echo "[architecture-guard] $(basename "$file_path") lines=$line_count limit=$max_lines"
  if [[ "$line_count" -gt "$max_lines" ]]; then
    mark_failure "$(basename "$file_path") exceeds $max_lines lines (found $line_count)."
  fi
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

check_engine_source_target_split() {
  print_check "Checking WordZEngine owns engine transport support..."

  local engine_root="${REPO_ROOT}/Sources/WordZEngine"
  local core_decl
  core_decl=$(sed -n '/name: "WordZWorkspaceCore"/,/path: "Sources\/WordZMac"/p' "$PACKAGE_FILE")

  if ! grep -q '"WordZEngine"' <<< "$core_decl"; then
    mark_failure "WordZWorkspaceCore should depend on WordZEngine for engine transport support."
  fi

  local expected_engine_files=(
    "$engine_root/Support/EngineContracts.swift"
    "$engine_root/Support/EngineJSONSupport.swift"
    "$engine_root/Support/EnginePaths.swift"
    "$engine_root/Support/EngineProtocolSupport.swift"
    "$engine_root/Transport/EngineClient.swift"
    "$engine_root/Transport/EngineClient+Invocation.swift"
    "$engine_root/Transport/EngineClient+Lifecycle.swift"
    "$engine_root/Transport/EngineClient+StreamHandling.swift"
  )

  local legacy_core_files=(
    "$ROOT_DIR/Engine/Support/EngineContracts.swift"
    "$ROOT_DIR/Engine/Support/EnginePaths.swift"
    "$ROOT_DIR/Engine/Support/EngineProtocolSupport.swift"
    "$ROOT_DIR/Engine/Transport/EngineClient.swift"
    "$ROOT_DIR/Engine/Transport/EngineClient+Invocation.swift"
    "$ROOT_DIR/Engine/Transport/EngineClient+Lifecycle.swift"
    "$ROOT_DIR/Engine/Transport/EngineClient+StreamHandling.swift"
  )

  local file_path
  for file_path in "${expected_engine_files[@]}"; do
    if [[ ! -f "$file_path" ]]; then
      mark_failure "Expected WordZEngine source file to exist: $file_path"
    fi
  done

  if [[ -f "$engine_root/WordZEnginePlaceholder.swift" ]]; then
    mark_failure "WordZEngine placeholder should be removed after source activation."
  fi

  for file_path in "${legacy_core_files[@]}"; do
    if [[ -f "$file_path" ]]; then
      mark_failure "Engine transport support should live in WordZEngine, not core: $file_path"
    fi
  done

  if [[ ! -f "$ROOT_DIR/Engine/Transport/EngineWorkspaceRepository.swift" ]]; then
    mark_failure "Workspace-facing engine repository adapter should remain in core for now."
  fi
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

check_hotspot_file_sizes() {
  print_check "Checking hotspot file boundaries..."
  check_file_line_limit "$ROOT_DIR/Analysis/Support/KeywordSuiteAnalysisSupport.swift" 180
  check_file_line_limit "$ROOT_DIR/Analysis/Services/Topics/TopicModelManager.swift" 160
  check_file_line_limit "$ROOT_DIR/Analysis/Services/Topics/NativeTopicEngine+PartitionSelection.swift" 220
  check_file_line_limit "$ROOT_DIR/ViewModels/Library/LibraryManagementViewModel+Scene.swift" 180
  check_file_line_limit "$ROOT_DIR/ViewModels/Pages/KeywordPageViewModel.swift" 320
  check_file_line_limit "$ROOT_DIR/ViewModels/Pages/SentimentPageViewModel.swift" 280
  check_file_line_limit "$ROOT_DIR/ViewModels/Pages/SentimentPageViewModel+Scene.swift" 400
  check_file_line_limit "$ROOT_DIR/Views/Workspace/Pages/Topics/TopicsView+ResultPanes.swift" 160
  check_file_line_limit "$ROOT_DIR/Views/Workspace/Pages/Topics/TopicsView+DetailPane.swift" 220
  check_file_line_limit "$ROOT_DIR/Views/Workspace/Pages/SentimentView+Controls.swift" 440
  check_file_line_limit "$ROOT_DIR/Views/Workspace/Pages/SentimentView+Results.swift" 340
  check_file_line_limit "$ROOT_DIR/Views/Workspace/Pages/SentimentView+Inspector.swift" 260
  check_file_line_limit "$ROOT_DIR/App/WordZMacApp.swift" 90
  check_file_line_limit "$ROOT_DIR/Models/Analysis/EvidenceWorkbenchDossierModels.swift" 40
  check_file_line_limit "$ROOT_DIR/Models/Analysis/EvidenceWorkbenchGroupingMode+Messages.swift" 700
  check_file_line_limit "$ROOT_DIR/Models/Workspace/WorkspaceFeatureRegistry.swift" 400
  check_file_line_limit "$ROOT_DIR/Models/Workspace/WorkspaceFeatureRegistry+MigratedVerticals.swift" 80
  check_file_line_limit "$ROOT_DIR/ViewModels/Workspace/EvidenceWorkbenchViewModel+Mutation.swift" 430
  check_file_line_limit "$ROOT_DIR/Workspace/Services/Topics/WorkspaceTopicsWorkflowService.swift" 220
  check_file_line_limit "$ROOT_DIR/Workspace/Services/WorkspaceFlowCoordinator.swift" 100
  check_file_line_limit "$ROOT_DIR/Workspace/Services/WorkspaceEvidenceWorkflowService.swift" 40
  check_file_line_limit "$ROOT_DIR/Workspace/Services/WorkspaceEvidenceWorkflowService+GroupMutations.swift" 520
  check_file_line_limit "$ROOT_DIR/Workspace/Services/WorkspaceEvidenceWorkflowService+Support.swift" 280
  check_file_line_limit "$ROOT_DIR/Workspace/Services/WorkspaceSentimentWorkflowService.swift" 180
  check_file_line_limit "$ROOT_DIR/Workspace/Models/WorkspaceFeaturePageBundle.swift" 30
  check_file_line_limit "$ROOT_DIR/Workspace/Models/WorkspaceFeaturePageHandles.swift" 60
  check_file_line_limit "$ROOT_DIR/Workspace/Models/WorkspaceFeatureSet.swift" 80
  check_file_line_limit "$ROOT_DIR/Workspace/Models/WorkspaceFeatureSet+Defaults.swift" 60
  check_file_line_limit "$ROOT_DIR/Workspace/Protocols/WorkspaceFeaturePageProtocols.swift" 140
  check_file_line_limit "$ROOT_DIR/Workspace/Protocols/WorkspaceFeatureWorkflowProtocols.swift" 200
  check_file_line_limit "$ROOT_DIR/Workspace/Protocols/WorkspaceFeatureWorkflowContexts.swift" 120
  check_file_line_limit "$ROOT_DIR/Workspace/Services/WorkspaceFeatureWorkflowFactory.swift" 50

  local expected_files=(
    "$ROOT_DIR/Analysis/Support/KeywordSuiteAnalysisSupport+ImportedReference.swift"
    "$ROOT_DIR/Analysis/Support/KeywordSuiteAnalysisSupport+CorpusPreparation.swift"
    "$ROOT_DIR/Analysis/Support/KeywordSuiteAnalysisSupport+Aggregation.swift"
    "$ROOT_DIR/Analysis/Support/KeywordSuiteAnalysisSupport+Scoring.swift"
    "$ROOT_DIR/Analysis/Services/Topics/TopicModelManager+ManifestSupport.swift"
    "$ROOT_DIR/Analysis/Services/Topics/TopicModelManager+EmbeddingSupport.swift"
    "$ROOT_DIR/App/WordZMacApp+FeatureWindows.swift"
    "$ROOT_DIR/Models/Workspace/WorkspaceFeatureRegistry+MigratedVerticals.swift"
    "$ROOT_DIR/ViewModels/Library/LibraryManagementViewModel+SceneNavigation.swift"
    "$ROOT_DIR/ViewModels/Library/LibraryManagementViewModel+SceneDetail.swift"
    "$ROOT_DIR/ViewModels/Library/LibraryManagementViewModel+SceneMaintenance.swift"
    "$ROOT_DIR/ViewModels/Pages/SentimentPageViewModel+Selection.swift"
    "$ROOT_DIR/ViewModels/Pages/SentimentPageViewModel+Profiles.swift"
    "$ROOT_DIR/ViewModels/Pages/SentimentPageViewModel+Actions.swift"
    "$ROOT_DIR/Views/Workspace/Pages/Topics/TopicsView+ListPane.swift"
    "$ROOT_DIR/Views/Workspace/Pages/Topics/TopicsView+SegmentsPane.swift"
    "$ROOT_DIR/Views/Workspace/Pages/Topics/TopicsView+CrossAnalysisPane.swift"
    "$ROOT_DIR/Views/Workspace/Pages/Topics/TopicsView+PaneSupport.swift"
    "$ROOT_DIR/Views/Workspace/Pages/SentimentView+Support.swift"
    "$ROOT_DIR/Models/Analysis/EvidenceWorkbenchGroupingSupport.swift"
    "$ROOT_DIR/Models/Analysis/EvidenceWorkbenchDossierDraftSupport.swift"
    "$ROOT_DIR/Models/Analysis/EvidenceMarkdownDossierSupport.swift"
    "$ROOT_DIR/ViewModels/Workspace/EvidenceWorkbenchViewModel+Selection.swift"
    "$ROOT_DIR/Workspace/Models/WorkspaceFeaturePageBundle.swift"
    "$ROOT_DIR/Workspace/Models/WorkspaceFeaturePageHandles.swift"
    "$ROOT_DIR/Workspace/Models/WorkspaceFeatureSet+Defaults.swift"
    "$ROOT_DIR/Workspace/Models/WorkspaceFeatureSet+WorkspaceBinding.swift"
    "$ROOT_DIR/Workspace/Protocols/WorkspaceFeaturePageProtocols.swift"
    "$ROOT_DIR/Workspace/Protocols/WorkspaceFeatureWorkflowProtocols.swift"
    "$ROOT_DIR/Workspace/Protocols/WorkspaceFeatureWorkflowContexts.swift"
    "$ROOT_DIR/Workspace/Services/WorkspaceFeatureWorkflowFactory.swift"
    "$ROOT_DIR/Workspace/Services/Topics/WorkspaceTopicsWorkflowService+CompareTopics.swift"
    "$ROOT_DIR/Workspace/Services/Topics/WorkspaceTopicsWorkflowService+TopicsSentiment.swift"
    "$ROOT_DIR/Workspace/Services/WorkspaceEvidenceWorkflowService+Capture.swift"
    "$ROOT_DIR/Workspace/Services/WorkspaceEvidenceWorkflowService+ItemMutations.swift"
    "$ROOT_DIR/Workspace/Services/WorkspaceEvidenceWorkflowService+Export.swift"
    "$ROOT_DIR/Workspace/Services/WorkspaceEvidenceWorkflowService+Support.swift"
    "$ROOT_DIR/Workspace/Services/WorkspaceSentimentWorkflowService+Exports.swift"
    "$ROOT_DIR/Workspace/Services/WorkspaceSentimentWorkflowService+LexiconBundles.swift"
  )

  local file_path
  for file_path in "${expected_files[@]}"; do
    if [[ ! -f "$file_path" ]]; then
      mark_failure "Expected hotspot companion file to exist: $file_path"
    fi
  done
}

check_feature_workflow_protocolization() {
  print_check "Checking feature workflow injection boundaries..."

  local protocol_file="$ROOT_DIR/Workspace/Protocols/WorkspaceFeatureWorkflowProtocols.swift"
  local page_protocol_file="$ROOT_DIR/Workspace/Protocols/WorkspaceFeaturePageProtocols.swift"
  local context_file="$ROOT_DIR/Workspace/Protocols/WorkspaceFeatureWorkflowContexts.swift"
  local feature_handles_file="$ROOT_DIR/Workspace/Models/WorkspaceFeaturePageHandles.swift"
  local feature_set_file="$ROOT_DIR/Workspace/Models/WorkspaceFeatureSet.swift"
  local feature_binding_file="$ROOT_DIR/Workspace/Models/WorkspaceFeatureSet+WorkspaceBinding.swift"
  local factory_file="$ROOT_DIR/Workspace/Services/WorkspaceFeatureWorkflowFactory.swift"
  local flow_coordinator_file="$ROOT_DIR/Workspace/Services/WorkspaceFlowCoordinator.swift"
  local coordinator_factory_file="$ROOT_DIR/Workspace/Services/WorkspaceCoordinatorFactory.swift"
  local main_workspace_file="$ROOT_DIR/ViewModels/Workspace/MainWorkspaceViewModel.swift"
  local sentiment_runs_file="$ROOT_DIR/Workspace/Services/WorkspaceFlowCoordinator+SentimentRuns.swift"
  local cross_analysis_file="$ROOT_DIR/Workspace/Services/WorkspaceFlowCoordinator+CrossAnalysisDrilldown.swift"
  local evidence_file="$ROOT_DIR/Workspace/Services/WorkspaceFlowCoordinator+EvidenceWorkbench.swift"
  local topic_runs_file="$ROOT_DIR/Workspace/Services/Topics/WorkspaceFlowCoordinator+TopicRuns.swift"
  local topics_service_glob="$ROOT_DIR/Workspace/Services/Topics/WorkspaceTopicsWorkflowService"
  local sentiment_service_glob="$ROOT_DIR/Workspace/Services/WorkspaceSentimentWorkflowService"
  local evidence_service_glob="$ROOT_DIR/Workspace/Services/WorkspaceEvidenceWorkflowService"
  local concrete_pattern='WorkspaceSentimentWorkflowService\(|WorkspaceTopicsWorkflowService\(|WorkspaceEvidenceWorkflowService\('
  local concrete_page_pattern='TopicsPageViewModel|SentimentPageViewModel|EvidenceWorkbenchViewModel'

  if [[ ! -f "$protocol_file" ]]; then
    mark_failure "Expected feature workflow protocol file to exist: $protocol_file"
  fi

  if [[ ! -f "$page_protocol_file" ]]; then
    mark_failure "Expected feature page protocol file to exist: $page_protocol_file"
  fi

  if [[ ! -f "$context_file" ]]; then
    mark_failure "Expected feature workflow context file to exist: $context_file"
  fi

  if [[ ! -f "$feature_handles_file" ]]; then
    mark_failure "Expected workspace feature page handles file to exist: $feature_handles_file"
  fi

  if [[ ! -f "$feature_set_file" ]]; then
    mark_failure "Expected workspace feature set file to exist: $feature_set_file"
  fi

  if [[ ! -f "$feature_binding_file" ]]; then
    mark_failure "Expected workspace feature binding file to exist: $feature_binding_file"
  fi

  if [[ ! -f "$factory_file" ]]; then
    mark_failure "Expected feature workflow factory file to exist: $factory_file"
  fi

  if ! rg -q 'WorkspaceSentimentWorkflowContext|WorkspaceTopicsWorkflowContext|WorkspaceEvidenceWorkflowContext' "$protocol_file"; then
    mark_failure "Feature workflow protocols should depend on feature-specific workflow contexts."
  fi

  if ! rg -q 'WorkspaceTopicsPageState|WorkspaceSentimentPageState|WorkspaceEvidenceWorkbenchState' "$page_protocol_file"; then
    mark_failure "Feature page protocols should define the workflow-facing page state abstractions."
  fi

  if ! rg -q 'WorkspaceTopicsPageState|WorkspaceSentimentPageState|WorkspaceEvidenceWorkbenchState' "$feature_handles_file"; then
    mark_failure "WorkspaceFeaturePageHandles should store protocol-backed page handles for migrated features."
  fi

  if ! rg -q 'WorkspaceTopicsPageState|WorkspaceSentimentPageState|WorkspaceEvidenceWorkbenchState' "$feature_set_file"; then
    mark_failure "WorkspaceFeatureSet should store feature page abstractions instead of concrete page view models."
  fi

  if rg -n "$concrete_page_pattern" "$feature_set_file" >/dev/null; then
    mark_failure "WorkspaceFeatureSet should not directly depend on concrete Topics/Sentiment/Evidence page view models."
  fi

  if ! rg -q 'WorkspaceFeaturePageHandles' "$main_workspace_file"; then
    mark_failure "MainWorkspaceViewModel should route migrated feature pages through WorkspaceFeaturePageHandles."
  fi

  if rg -n '@Published var (topics|sentiment|evidenceWorkbench): (TopicsPageViewModel|SentimentPageViewModel|EvidenceWorkbenchViewModel)' "$main_workspace_file" >/dev/null; then
    mark_failure "MainWorkspaceViewModel should not directly store published concrete Topics/Sentiment/Evidence page view models."
  fi

  if ! rg -q 'workspace\.featurePages\.(topics|sentiment|evidenceWorkbench)' "$feature_binding_file"; then
    mark_failure "WorkspaceFeatureSet binding should read migrated feature pages from MainWorkspaceViewModel.featurePages."
  fi

  if ! rg -q 'WorkspaceFeatureWorkflowFactory' "$flow_coordinator_file"; then
    mark_failure "WorkspaceFlowCoordinator should resolve workflows through WorkspaceFeatureWorkflowFactory."
  fi

  if ! rg -q 'WorkspaceSentimentWorkflowServing|WorkspaceTopicsWorkflowServing|WorkspaceEvidenceWorkflowServing' "$flow_coordinator_file"; then
    mark_failure "WorkspaceFlowCoordinator should depend on feature workflow protocols."
  fi

  local result
  result=$(rg -n "$concrete_pattern" "$flow_coordinator_file" "$coordinator_factory_file" || true)
  if [[ -n "$result" ]]; then
    mark_failure "Flow/coordinator factories should not instantiate concrete feature workflows directly."
    echo "$result"
  fi

  if ! rg -q 'sentimentWorkflowContext' "$sentiment_runs_file"; then
    mark_failure "Sentiment flow coordinator should project WorkspaceFeatureSet into WorkspaceSentimentWorkflowContext."
  fi

  if ! rg -q 'topicsWorkflowContext' "$cross_analysis_file" "$topic_runs_file"; then
    mark_failure "Topics flow coordinator routes should project WorkspaceFeatureSet into WorkspaceTopicsWorkflowContext."
  fi

  if ! rg -q 'evidenceWorkflowContext' "$evidence_file"; then
    mark_failure "Evidence flow coordinator should project WorkspaceFeatureSet into WorkspaceEvidenceWorkflowContext."
  fi

  result=$(rg -n "$concrete_page_pattern" \
    "${topics_service_glob}"*.swift \
    "${sentiment_service_glob}"*.swift \
    "${evidence_service_glob}"*.swift || true)
  if [[ -n "$result" ]]; then
    mark_failure "Feature workflow services should depend on feature page protocols instead of concrete page view models."
    echo "$result"
  fi
}

check_workspace_feature_module_activation() {
  print_check "Checking WordZWorkspaceFeature activation markers..."

  local feature_root="${REPO_ROOT}/Sources/WordZWorkspaceFeature"
  local feature_module_file="${feature_root}/WordZWorkspaceFeatureModule.swift"
  local feature_page_factory_file="${feature_root}/WorkspaceFeaturePageFactory.swift"
  local legacy_placeholder_file="${feature_root}/WordZWorkspaceFeaturePlaceholder.swift"
  local app_shell_file="${REPO_ROOT}/Sources/WordZAppShell/WordZAppShellApp.swift"
  local app_container_file="$ROOT_DIR/App/Composition/NativeAppContainer.swift"

  if [[ ! -f "$feature_module_file" ]]; then
    mark_failure "Expected activated workspace feature module file to exist: $feature_module_file"
  fi

  if [[ -f "$legacy_placeholder_file" ]]; then
    mark_failure "Workspace feature placeholder should be removed after activation: $legacy_placeholder_file"
  fi

  if [[ ! -f "$feature_page_factory_file" ]]; then
    mark_failure "Activated workspace feature module should provide a production feature page factory: $feature_page_factory_file"
  fi

  if ! rg -q '^import WordZWorkspaceFeature$' "$app_shell_file"; then
    mark_failure "App shell should import WordZWorkspaceFeature once the module is activated."
  fi

  if ! rg -q 'WordZWorkspaceFeatureModule\.activationSummary' "$app_shell_file"; then
    mark_failure "App shell should touch the workspace feature activation marker during bootstrap."
  fi

  if ! rg -q 'WordZWorkspaceFeaturePageFactory\.makePageBundle' "$app_shell_file"; then
    mark_failure "App shell should inject feature page construction through WordZWorkspaceFeaturePageFactory."
  fi

  if rg -n 'TopicsPageViewModel\(|SentimentPageViewModel\(|EvidenceWorkbenchViewModel\(' "$app_container_file" >/dev/null; then
    mark_failure "NativeAppContainer should not directly construct migrated Topics/Sentiment/Evidence feature pages."
  fi

  if ! rg -q 'WorkspaceFeaturePageHandles\(bundle: featurePages\)' "$app_container_file"; then
    mark_failure "NativeAppContainer should bridge injected feature page bundles through WorkspaceFeaturePageHandles."
  fi

  if [[ -f "$ROOT_DIR/Workspace/Services/WorkspaceAnalysisWorkflowService+SentimentExports.swift" ]]; then
    mark_failure "Legacy shared sentiment export workflow file should not exist: $ROOT_DIR/Workspace/Services/WorkspaceAnalysisWorkflowService+SentimentExports.swift"
  fi

  if [[ -f "$ROOT_DIR/Workspace/Services/WorkspaceAnalysisWorkflowService+SentimentLexiconBundles.swift" ]]; then
    mark_failure "Legacy shared sentiment lexicon workflow file should not exist: $ROOT_DIR/Workspace/Services/WorkspaceAnalysisWorkflowService+SentimentLexiconBundles.swift"
  fi
}

check_migrated_feature_registry_companions() {
  print_check "Checking migrated feature registry and window companions..."

  local registry_file="$ROOT_DIR/Models/Workspace/WorkspaceFeatureRegistry.swift"
  local registry_companion_file="$ROOT_DIR/Models/Workspace/WorkspaceFeatureRegistry+MigratedVerticals.swift"
  local app_file="$ROOT_DIR/App/WordZMacApp.swift"
  local app_feature_windows_file="$ROOT_DIR/App/WordZMacApp+FeatureWindows.swift"

  if [[ ! -f "$registry_companion_file" ]]; then
    mark_failure "Expected migrated workspace feature registry companion file to exist: $registry_companion_file"
  fi

  if [[ ! -f "$app_feature_windows_file" ]]; then
    mark_failure "Expected feature window companion file to exist: $app_feature_windows_file"
  fi

  if ! rg -q 'topicsDescriptor\(\)|sentimentDescriptor\(\)' "$registry_file"; then
    mark_failure "WorkspaceFeatureRegistry should route Topics/Sentiment descriptors through migrated companion builders."
  fi

  if rg -n 'TopicsView\(|SentimentView\(' "$registry_file" >/dev/null; then
    mark_failure "WorkspaceFeatureRegistry should not inline Topics/Sentiment view assembly after migrated companion extraction."
  fi

  if ! rg -q 'TopicsView\(|SentimentView\(' "$registry_companion_file"; then
    mark_failure "Migrated registry companion should own Topics/Sentiment view assembly."
  fi

  if ! rg -q 'evidenceWorkbenchWindow\(' "$app_file"; then
    mark_failure "WordZCoreAppScenes should route evidence workbench scene assembly through the feature window companion."
  fi

  if ! rg -q 'EvidenceWorkbenchWindowView' "$app_feature_windows_file"; then
    mark_failure "Feature window companion should own evidence workbench window assembly."
  fi
}

check_topics_feature_layout() {
  print_check "Checking Topics feature directories stay consolidated..."

  local expected_files=(
    "$ROOT_DIR/Analysis/Builders/Topics/TopicsSceneBuilder.swift"
    "$ROOT_DIR/Analysis/Services/Topics/NativeTopicEngine.swift"
    "$ROOT_DIR/Analysis/Services/Topics/TopicModelManager.swift"
    "$ROOT_DIR/Analysis/Support/Topics/TopicFilterSupport.swift"
    "$ROOT_DIR/Models/Analysis/Topics/TopicAnalysisModels.swift"
    "$ROOT_DIR/Models/Scene/Topics/TopicsSceneModel.swift"
    "$ROOT_DIR/Models/Actions/Topics/TopicsPageAction.swift"
    "$ROOT_DIR/ViewModels/Pages/Topics/TopicsPageViewModel.swift"
    "$ROOT_DIR/Views/Workspace/Pages/Topics/TopicsView.swift"
    "$ROOT_DIR/Workspace/Services/Topics/NativeWorkspaceRepository+TopicAnalysis.swift"
    "$ROOT_DIR/Workspace/Services/Topics/WorkspaceActionDispatcher+TopicsActions.swift"
    "$ROOT_DIR/Workspace/Services/Topics/WorkspaceTopicsWorkflowService.swift"
  )

  local legacy_files=(
    "$ROOT_DIR/Analysis/Builders/TopicsSceneBuilder.swift"
    "$ROOT_DIR/Analysis/Services/NativeTopicEngine.swift"
    "$ROOT_DIR/Analysis/Services/TopicModelManager.swift"
    "$ROOT_DIR/Analysis/Support/TopicFilterSupport.swift"
    "$ROOT_DIR/Models/Analysis/TopicAnalysisModels.swift"
    "$ROOT_DIR/Models/Scene/TopicsSceneModel.swift"
    "$ROOT_DIR/Models/Actions/TopicsPageAction.swift"
    "$ROOT_DIR/ViewModels/Pages/TopicsPageViewModel.swift"
    "$ROOT_DIR/Views/Workspace/Pages/TopicsView.swift"
    "$ROOT_DIR/Workspace/Services/NativeWorkspaceRepository+TopicAnalysis.swift"
    "$ROOT_DIR/Workspace/Services/WorkspaceActionDispatcher+TopicsActions.swift"
    "$ROOT_DIR/Workspace/Services/WorkspaceFlowCoordinator+TopicRuns.swift"
    "$ROOT_DIR/Workspace/Services/WorkspaceAnalysisWorkflowService+CompareTopics.swift"
    "$ROOT_DIR/Workspace/Services/WorkspaceAnalysisWorkflowService+TopicsSentiment.swift"
  )

  local file_path
  for file_path in "${expected_files[@]}"; do
    if [[ ! -f "$file_path" ]]; then
      mark_failure "Expected Topics feature file to exist: $file_path"
    fi
  done

  for file_path in "${legacy_files[@]}"; do
    if [[ -f "$file_path" ]]; then
      mark_failure "Legacy Topics file should not exist at flat path: $file_path"
    fi
  done
}

main() {
  check_package_declares_expected_targets
  check_engine_source_target_split
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
  check_topics_feature_layout
  check_workspace_feature_module_activation
  check_migrated_feature_registry_companions
  check_feature_workflow_protocolization
  check_hotspot_file_sizes

  if [[ "$FAILED" -ne 0 ]]; then
    echo "[architecture-guard] Completed with failures."
    exit 1
  fi

  echo "[architecture-guard] All checks passed."
}

main "$@"
