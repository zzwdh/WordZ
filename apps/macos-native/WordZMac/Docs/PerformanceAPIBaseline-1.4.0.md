# WordZ 1.4.0 Performance/API Baseline

## Current Status

Updated: 2026-06-23

This file tracks the concrete 1.4.0 work that supports the roadmap theme: performance optimization and API call stabilization.

## API Foundation

Status: first implementation, the narrow manual API pilot, release API privacy/export gate, and release API recovery gate have landed; focused validation is green.

Implemented:

- `NativeAPIClient` in `WordZHost`
- request IDs
- per-request timeouts
- bounded API concurrency
- retry policy with retryable HTTP status codes
- `Retry-After` handling
- HTTP response metadata
- ETag response access
- unified HTTP and transport errors
- queued and in-flight cancellation normalization
- sensitive header redaction
- diagnostics bundle support for redacted API request metadata
- migration of GitHub release update checks onto the shared API client
- user-facing API access switch in Settings
- Keychain-backed API credential store with save/clear actions
- Keychain credential read path for user-triggered API calls
- user-triggered API connection check through the shared API client
- user-triggered API connection check fixed as the 1.4.0 narrow manual API pilot
- saved API request timeout and max concurrency settings with conservative bounds
- API credential status in Settings without persisting the secret in host preferences
- update check and update download gating when API access is disabled
- live update-check service factory receives the current saved API timeout and max concurrency settings
- pilot request observations carried from the Host layer into diagnostics export as redacted metadata only
- pilot diagnostics strip query strings and sensitive headers, and do not include request bodies or corpus text
- API connection failure recovery messages now use redacted, user-facing status text in both Settings and issue banners
- release checklist runs the 1.4 UI performance, API privacy, and API recovery gates before packaging

Current API contract:

- API calls are optional infrastructure and must not block local corpus analysis.
- User-facing features should not call `URLSession` directly when the request belongs to app-level API behavior.
- API errors must preserve enough detail for recovery while avoiding raw credentials or sensitive payloads in logs.
- API work must be cancellable through Swift task cancellation.
- When API access is disabled, local analysis remains available and network-backed update checks/downloads do not run.
- API failure recovery UI must preserve local-analysis availability messaging and must not echo saved credentials, bearer tokens, or query API tokens.

Validated tests:

- `NativeUpdateServiceTests.testCheckForUpdatesUsesUnifiedAPIHeaders`
- `NativeUpdateServiceTests.testNativeAPIClientRetriesRateLimitedRequest`
- `NativeUpdateServiceTests.testNativeAPIClientCancelsInFlightRequestWithoutWrappingAsTransportError`
- `NativeUpdateServiceTests.testNativeAPIClientCancelsQueuedRequestAndKeepsLaterRequestsRunning`
- `NativeUpdateServiceTests.testNativeAPIClientRedactsSensitiveHeaders`
- `NativeUpdateServiceTests.testNativeAPIConnectionTestServiceUsesUnifiedClientAndCredentialHeader`
- `MainWorkspaceViewModelTests.testCheckForUpdatesDoesNotCallServiceWhenAPIIsDisabled`
- `MainWorkspaceViewModelTests.testCheckForUpdatesUsesCurrentAPIRequestPolicyFactory`
- `MainWorkspaceViewModelTests.testAPICredentialActionsUseCredentialStoreWithoutPersistingSecretInPreferences`
- `MainWorkspaceViewModelTests.testAPIConnectionCheckUsesSavedCredentialAndUpdatesSettingsScene`
- `MainWorkspaceViewModelTests.testAPIConnectionCheckAddsRedactedPilotMetadataToDiagnostics`
- `MainWorkspaceViewModelTests.testAPIConnectionCheckDoesNotRunWhenAPIIsDisabled`
- `WorkspaceFailurePathTests.testAPIConnectionCredentialFailureShowsRecoveryWithoutLeakingToken`
- `WorkspaceFailurePathTests.testAPIConnectionRateLimitFailureKeepsLocalAnalysisRecovery`
- `WorkspaceFailurePathTests.testAPIConnectionOfflineFailureRedactsCredentialAndQueryTokens`
- `WorkspaceFailurePathTests.testCancelledAPIConnectionDoesNotProduceIssueBanner`
- `WorkspaceFailurePathTests.testUpdateFailureProducesRetryableIssueBanner`
- `WorkspaceFailurePathTests.testCancelledUpdateCheckDoesNotProduceIssueBanner`
- `NativeDiagnosticsBundleServiceTests.testBuildBundleWritesArchiveWithRuntimeAndPersistedState`
- `NativeHostPreferencesStoreTests.testStoreRoundTripsSnapshotAndRecordsRecentDocuments`
- `SettingsTests.testSettingsViewModelAppliesSnapshotAndExportsValues`
- `SettingsTests.testAPIRequestPolicyClampsToConservativeBounds`
- existing update parsing, HTTP failure, and download failure tests

Latest focused validation:

```sh
swift test --filter NativeUpdateServiceTests --filter SettingsTests --filter NativeHostPreferencesStoreTests --filter MainWorkspaceViewModelTests/testCheckForUpdatesUsesCurrentAPIRequestPolicyFactory --filter MainWorkspaceViewModelTests/testCheckForUpdatesDoesNotCallServiceWhenAPIIsDisabled --filter MainWorkspaceViewModelTests/testAPICredentialActionsUseCredentialStoreWithoutPersistingSecretInPreferences --filter MainWorkspaceViewModelTests/testAPIConnectionCheckUsesSavedCredentialAndUpdatesSettingsScene --filter MainWorkspaceViewModelTests/testAPIConnectionCheckAddsRedactedPilotMetadataToDiagnostics --filter MainWorkspaceViewModelTests/testAPIConnectionCheckDoesNotRunWhenAPIIsDisabled
```

Result: 28 focused API/update/settings tests, 0 failures. The latest run also included `MainWorkspaceViewModelTests.testAPIConnectionCheckAddsRedactedPilotMetadataToDiagnostics`.

Latest release API privacy/export validation:

- Date: 2026-06-23

```sh
zsh Scripts/run-1.4-api-privacy-check.sh --release --disable-swiftpm-sandbox
```

Result: 3 release API privacy/export tests, 0 failures. The gate verifies saved credential headers through the unified connection client, redacted pilot request metadata in diagnostics payloads, and a real diagnostics zip export that strips API keys, authorization values, trace tokens, query tokens, and sample corpus text.

Latest release API recovery validation:

- Date: 2026-06-23

```sh
zsh Scripts/run-1.4-api-recovery-check.sh --release --disable-swiftpm-sandbox
```

Result: 8 release API recovery tests, 0 failures. The gate verifies API-off update/connection behavior, 401 credential recovery, 429 rate-limit recovery, offline transport recovery, API cancellation handling, update failure retry banners, and token redaction in failure UI.

## Performance Baseline

Status: fixed-machine algorithm, small fixture, bundled reference-corpus, Library/import baseline, first Library refresh optimization, first Topics result-assembly optimization, first Library import/index shard-write optimization, full user-triggered analysis latest-result concurrency protection, and release-mode aggregate baseline captured.

Existing foundation:

- runtime budget policy exists for analysis tasks
- user-triggered analysis runs now share the managed latest-result path across KWIC, Compare, Topics, Sentiment, Plot, Ngram, Cluster, Collocate, Stats, Word, Tokenize, ChiSquare, and Locator
- large result scene boundary tests exist
- previous topic benchmark work established the expected before/after quality comparison pattern
- `Scripts/run-1.4-performance-baseline.sh` now aggregates fixed topic, sentiment, fixed user fixture, bundled reference-corpus fixture, Library/import, and optional external user corpus reports
- `Scripts/run-1.4-performance-baseline.sh --release` runs the fixed reports through release SwiftPM tests and records `buildConfiguration: "release"` in the manifest
- `Scripts/run-1.4-performance-baseline.sh --disable-swiftpm-sandbox` lets the same aggregate run complete inside already-sandboxed automation environments that block SwiftPM's nested `sandbox-exec`
- `Scripts/run-1.4-ui-performance-check.sh --release` runs the large-result UI performance gate before packaging

Latest large-result UI performance gate:

- Date: 2026-06-23
- Change: added an explicit large-result interaction dispatch P95 budget of 50 ms, covering representative Stats, KWIC, Sentiment, and Topics interactions without counting asynchronous scene-build completion as input-blocking time.
- Debug command: `zsh Scripts/run-1.4-ui-performance-check.sh --debug --disable-swiftpm-sandbox`
- Release command: `zsh Scripts/run-1.4-ui-performance-check.sh --release --disable-swiftpm-sandbox`
- Result: 20 PerformanceBoundary tests, 0 failures. Coverage includes page-size fallback, interaction dispatch P95 budget, partial visible-row table reloads, selection-only table updates, keyboard/copy activation, and latest-scene preservation after rapid paging, sorting, filtering, selection, and column changes.
- Release checklist: `Scripts/release-checklist.sh` now runs this UI performance gate before API gates and packaging.

Latest aggregate fixed run:

- Date: 2026-06-16
- Generated at: 2026-06-16T15:42:30Z
- Output directory: `.build/reports/1.4.0`
- Hardware summary: `appleSilicon`, Metal available, ANE available, 10 active processors, 24576 MB memory, low power off, thermal nominal.
- Topic exact fixture: `three-theme-exact-300`, 4217.0 ms, purity 1.000, theme recall 1.000, 3 clusters.
- Topic approximate fixture: `three-theme-approx-450`, 2802.0 ms, purity 1.000, theme recall 1.000, 3 clusters.
- Sentiment mixed baseline: `sentiment-gold-v2`, 72 examples, accuracy 0.833, macro F1 0.834, neutral false positive rate 0.229.
- Sentiment news-focused baseline: `sentiment-gold-v3`, 18 examples, accuracy 0.944, macro F1 0.944, neutral false positive rate 0.000.
- Large-result UI boundary suite: 19 tests passed at the time of this aggregate run, covering rapid paging, sorting, filtering, column visibility, visible-row reloads, and latest-scene application across major analysis pages. The latest standalone UI gate now covers 20 tests with an added P95 interaction-dispatch budget.
- Fixed user fixture repeat baseline: `user-benchmark-sample.txt`, 3/3 successful runs, 827 characters, 4 lines.
- Fixed user fixture total duration: p50 44.8 ms, p95 78.9 ms, min 42.8 ms, max 82.7 ms.
- Fixed user fixture stage durations:
  - Topics: p50 32.2 ms, p95 32.7 ms.
  - Sentiment: p50 5.7 ms, p95 9.9 ms.
  - KWIC smoke: p50 0.6 ms, p95 0.6 ms.
- Bundled reference corpus repeat baseline: `reference-benchmark-corpus.txt`, generated from 12 bundled ToRCH2014 segmented files, 3/3 successful runs, 38,952 characters, 181 lines.
- Bundled reference corpus total duration: p50 4229.1 ms, p95 4335.7 ms.
- Bundled reference corpus stage durations:
  - Topics: p50 3501.1 ms, p95 3630.5 ms, 345 segments, 238 clustered segments, 13 clusters, `approximateRefined`.
  - Sentiment: p50 348.1 ms, p95 355.1 ms, 505 rows.
  - Parse document: latest run 302.3 ms.
  - KWIC smoke: p50 15.2 ms, p95 15.3 ms, 178 rows.
- Library/import repeat baseline: `library-baseline.json`, 3/3 successful runs.
- Library/import input:
  - Real import/index: 24 generated TXT files, 1,200 characters each, 28,800 generated characters total.
  - Synthetic Library scene: 1,200 corpora, 32 folders, 24 corpus sets.
- Library/import stage durations:
  - Store initialization: p50 15.7 ms, p95 16.3 ms.
  - Import/index: p50 418.7 ms, p95 446.8 ms, 24 imported corpora per run, 0 skipped.
  - `listLibrary`: p50 0.1 ms, p95 0.2 ms.
  - `listLibrary` search: p50 1.0 ms, p95 1.2 ms.
  - Library scene open: p50 123.3 ms, p95 153.1 ms.
  - Library scene refresh after duplicate-snapshot guard: p50 0.001 ms, p95 0.003 ms.
  - Library scene search: p50 28.9 ms, p95 29.5 ms.
  - Library folder switch: p50 3.8 ms, p95 3.9 ms.
  - Library selection update: p50 12.0 ms, p95 12.4 ms.
- Current slowest measured paths from the bundled reference corpus:
  1. Topics, p95 3630.5 ms.
  2. Library import/index, p95 446.8 ms.
  3. Sentiment, p95 355.1 ms.
  4. Parse document, latest run 302.3 ms.

Previous aggregate release run:

- Date: 2026-06-21
- Generated at: 2026-06-21T10:20:09Z
- Command: `zsh Scripts/run-1.4-performance-baseline.sh --release --output-dir .build/reports/1.4.0-release`
- Output directory: `.build/reports/1.4.0-release`
- Manifest: all fixed reports record `buildConfiguration: "release"`; optional external user corpus was skipped.
- Topic exact fixture: `three-theme-exact-300`, 499.4 ms, purity 1.000, theme recall 1.000, 3 clusters.
- Topic approximate fixture: `three-theme-approx-450`, 492.0 ms, purity 1.000, theme recall 1.000, 3 clusters.
- Fixed user fixture total duration: p50 30.0 ms, p95 55.2 ms.
- Fixed user fixture stage durations:
  - Topics: p95 22.1 ms.
  - Sentiment: p95 7.0 ms.
- Bundled reference corpus total duration: p50 1231.0 ms, p95 1263.7 ms.
- Bundled reference corpus stage durations:
  - Topics: p95 847.4 ms.
  - Sentiment: p95 79.5 ms.
  - KWIC smoke: p95 8.6 ms.
- Bundled reference corpus Topics quality fields stayed stable: `approximateRefined`, 13 clusters, 238 clustered segments, 107 outliers, 345 total segments, warning count 1, `bundled-local-embedding`.
- Library/import release baseline: `library-baseline.json`, 3/3 successful runs.
- Library/import stage durations:
  - Import/index: p50 399.1 ms, p95 426.1 ms.
  - Library scene open: p50 109.9 ms, p95 118.3 ms.
  - Library scene refresh after duplicate-snapshot guard: p50 0.002 ms, p95 0.028 ms.
  - Library scene search: p50 26.1 ms, p95 27.7 ms.
  - Library selection update: p95 10.0 ms.
- This was the last full release aggregate before the Library shard-write optimization.

Latest aggregate release run:

- Date: 2026-06-22
- Generated at: 2026-06-22T02:33:48Z
- Command: `HOME=/tmp/wordz-swiftpm-home CLANG_MODULE_CACHE_PATH=/tmp/wordz-clang-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/wordz-swiftpm-module-cache zsh Scripts/run-1.4-performance-baseline.sh --release --disable-swiftpm-sandbox --output-dir .build/reports/1.4.0-release-post-library`
- Output directory: `.build/reports/1.4.0-release-post-library`
- Manifest: all fixed reports record `buildConfiguration: "release"`; optional external user corpus was skipped.
- Topic exact fixture: `three-theme-exact-300`, 453.5 ms, purity 1.000, theme recall 1.000, 3 clusters.
- Topic approximate fixture: `three-theme-approx-450`, 514.1 ms, purity 1.000, theme recall 1.000, 3 clusters.
- Sentiment mixed baseline: `sentiment-gold-v2`, 72 examples, accuracy 0.833, macro F1 0.834, neutral false positive rate 0.229.
- Sentiment news-focused baseline: `sentiment-gold-v3`, 18 examples, accuracy 0.944, macro F1 0.944, neutral false positive rate 0.000.
- Fixed user fixture total duration: p50 32.2 ms, p95 49.3 ms.
- Fixed user fixture stage durations:
  - Topics: p95 21.3 ms.
  - Sentiment: p95 8.5 ms.
  - KWIC smoke: p95 0.9 ms.
- Bundled reference corpus total duration: p50 1228.5 ms, p95 1312.5 ms.
- Bundled reference corpus stage durations:
  - Topics: p95 854.4 ms.
  - Parse document: p95 342.5 ms.
  - Sentiment: p95 84.4 ms.
  - KWIC smoke: p95 9.0 ms.
- Bundled reference corpus Topics quality fields stayed stable: `approximateRefined`, 13 clusters, 238 clustered segments, 107 outliers, 345 total segments, warning count 1, `bundled-local-embedding`, explained variance 0.9266709539964267.
- Library/import release baseline after shard-write optimization: `library-baseline.json`, 3/3 successful runs.
- Library/import stage durations:
  - Import/index: p50 223.1 ms, p95 224.6 ms.
  - Library scene open: p50 109.9 ms, p95 114.7 ms.
  - Library scene refresh after duplicate-snapshot guard: p50 0.001 ms, p95 0.004 ms.
  - Library scene search: p50 26.3 ms, p95 27.6 ms.
  - Library selection update: p95 10.7 ms.
- Current release-mode priority after Library shard-write optimization:
  1. Topics on bundled reference corpus, p95 854.4 ms.
  2. Parse document on bundled reference corpus, p95 342.5 ms.
  3. Library import/index, p95 224.6 ms.
  4. Library scene open, p95 114.7 ms.
  5. Sentiment on bundled reference corpus, p95 84.4 ms.

Latest analysis concurrency validation:

- Date: 2026-06-23
- Change: ordinary Topics, main Sentiment, topic-segment-derived Sentiment, Plot, Ngram, Cluster, Collocate, Stats, Word, Tokenize, ChiSquare, and Locator runs now use the shared latest-result task supervisor path. Rapid repeated requests cancel/replace the previous run, discard stale results, and only persist the latest result tab state. Stats and Word share the frequency-result freshness token so an older frequency run cannot overwrite a newer run from the adjacent page.
- Focused command: `swift test --filter WorkspaceRuntimeConcurrencyTests`
- Result: 14 runtime concurrency tests, 0 failures. Coverage now includes KWIC, Compare, Topics, main Sentiment, topic-segment-derived Sentiment, Plot, Ngram, Cluster, Collocate, shared Stats/Word frequency results, Tokenize, ChiSquare, Locator latest-result protection, and stale persistence callback suppression.
- Broader affected command: `swift test --filter 'WorkspaceRuntimeConcurrencyTests|PlotClusterFeatureTests|MainWorkspaceViewModelTests|WorkspaceActionDispatcherTests|WorkspaceWorkflowChainTests|WorkspaceFailurePathTests|CoordinatorsTests|CompositionTests'`
- Result: 181 affected ViewModel/dispatcher/coordinator/workflow/concurrency/Plot/Cluster/failure tests, 0 failures.

Latest cancellation-state validation:

- Date: 2026-06-22
- Change: task-center cancellation now uses a distinct `cancelled` task state and `cancelledCount` instead of reporting user cancellation through the failed bucket. Managed result runs, update checks/downloads, diagnostics export, and report-bundle export mark user cancellation as cancelled, late success/failure events cannot overwrite cancelled tasks, and cancelled terminal events do not emit failure notifications.
- Command: `swift test --filter 'NativeTaskCenterTests|WorkspaceFailurePathTests|MainWorkspaceViewModelTests|NativeHostPreferencesStoreTests|NativeDiagnosticsBundleServiceTests|CompositionTests'`
- Result: 101 affected task-center/ViewModel/failure-path/diagnostics/preferences/composition tests, 0 failures.

Latest packaged app smoke:

- Date: 2026-06-22
- Build/package command: `WORDZ_MAC_DISABLE_SWIFTPM_SANDBOX=1 WORDZ_MAC_DIST_DIR=/Users/zouyuxuan/corpus-lite/apps/macos-native/WordZMac/dist-native-1.4-smoke zsh Scripts/package-app.sh`
- Result: the app bundle, zip, and pkg were created; DMG creation stopped in the current managed environment with `hdiutil: create failed - 设备未配置`.
- Smoke command: `zsh Scripts/release-smoke.sh dist-native-1.4-smoke/WordZ.app`
- Result: app-bundle smoke passed. The check validated `Info.plist`, build info, executable presence/SHA metadata, Topic and Sentiment resources, English and Chinese localizations, and the sibling pkg installer payload.
- Version validated: `1.3.9`, from the current `VERSION` file. The `1.4.0` version bump/tag remains a separate release step.
- Script support added: `Scripts/release-smoke.sh` now accepts a `.app` bundle directly, so app/package structure can still be verified when manifest or DMG generation is unavailable.

Latest focused Library import/index optimization run:

- Date: 2026-06-22
- Command: `CLANG_MODULE_CACHE_PATH=/tmp/wordz-clang-module-cache SWIFTPM_HOME=/tmp/wordz-swiftpm-cache WORDZ_1_4_BASELINE_OUTPUT_DIR=/tmp/wordz-library-baseline-after-3 WORDZ_1_4_LIBRARY_BASELINE_BUILD_CONFIGURATION=release swift test --disable-sandbox -c release --filter LibraryPerformanceBaselineTests/testRunLibraryPerformanceBaselineForRoadmap`
- Input: 24 generated TXT files per run, 1,200 characters each, 3/3 successful runs.
- Before focused release rerun: import/index p50 351.9 ms, p95 368.5 ms.
- After focused release rerun: import/index p50 218.1 ms, p95 230.3 ms.
- Delta: import/index p95 improved by 138.3 ms, about 37.5%.
- Adjacent Library scene metrics stayed in the same range: scene open p95 106.2 ms, scene search p95 25.8 ms, scene refresh p95 0.032 ms, selection p95 9.2 ms.

Optimization notes:

- A low-level Sentiment phrase matching micro-optimization was tested on the reference corpus and rejected because it regressed Sentiment p95 from roughly 351 ms to roughly 762 ms. The code was reverted; do not pursue that direction without a narrower benchmark and proof that output quality and runtime both improve.
- A Topic local-embedding projection hash cache was tested and rejected. Quality fields stayed unchanged, but the reference-corpus Topics p95 did not show a reliable improvement, so the code was reverted instead of adding unproven cache complexity.
- Library duplicate snapshot refresh optimization:
  - Change: `LibraryManagementViewModel.applyLibrarySnapshot` now skips a full scene rebuild when the same `LibrarySnapshot` is applied after the initial load.
  - Before: synthetic 1,200-corpus Library refresh p95 108.9 ms.
  - After: synthetic 1,200-corpus Library refresh p95 0.003 ms.
  - Quality impact: none expected; this path only skips rebuilding an identical scene model. Empty-library initial bootstrap remains covered by a focused test.
- Library import/index shard-write optimization:
  - Change: new corpus shard writes now create the relational tables first, bulk-insert document, sentence, token, frequency, and token-position rows, then create secondary indexes. New staging shards also skip legacy column-migration checks that are still kept on read/update paths for older shard files.
  - Before: focused release Library import/index p50 351.9 ms, p95 368.5 ms.
  - After: focused release Library import/index p50 218.1 ms, p95 230.3 ms.
  - Quality impact: no analysis-truth change expected; final shard schema and indexes are unchanged. Focused tests still verify frequency indexes, metadata indexes, sentence FTS prefix search, and stored token-position artifacts.
- Topics latest-result concurrency protection:
  - Change: ordinary Topics runs now route through `WorkspaceTaskSupervisor` with `replaceLatest`, reuse the shared managed result-run completion path, and cancel the underlying topic analysis task when the request is replaced or cancelled.
  - Before: Topics service guarded duplicate concurrent requests, but a rapid second run could be skipped instead of guaranteed to become the latest UI state.
  - After: rapid Topics reruns execute as replace-latest requests; stale results are discarded before applying page state or persisting the selected tab.
  - Quality impact: no analysis-truth change expected; the same repository run and topic options builder are reused. Focused tests assert only the latest query result reaches the Topics page and scene.
- Sentiment latest-result concurrency protection:
  - Change: current-corpus, pasted-text, visible-KWIC, corpus-compare, and topic-segment-derived Sentiment runs now build their request before calling the repository and only apply the result after the latest token is confirmed.
  - Before: the Sentiment workflow applied results internally, so wrapping the outer call could not prevent stale results from writing page state.
  - After: rapid Sentiment reruns execute as replace-latest requests; stale results are discarded before applying `rawResult`, scene state, cross-analysis summaries, or selected-tab persistence.
  - Quality impact: no analysis-truth change expected; the same Sentiment request builders and repository run are used. Focused tests assert only the latest pasted-text and topic-segment requests reach the Sentiment page and scene.
- Secondary analysis latest-result concurrency protection:
  - Change: Plot, Ngram, Cluster, and Collocate user-triggered runs now route through the same `WorkspaceTaskSupervisor` replace-latest path as the P0 analysis pages.
  - Before: these pages used the older busy-skip result-run wrapper, so a rapid second run could be ignored while the first result still wrote page state.
  - After: rapid reruns replace the previous request; stale results are discarded before applying page state, result scenes, or selected-tab persistence.
  - Quality impact: no analysis-truth change expected; the same repository calls and request builders are used. Focused tests assert only the latest Plot query, Ngram size, Cluster option, and Collocate keyword reach the page result.
- Short-task latest-result concurrency protection:
  - Change: Stats, Word, Tokenize, ChiSquare, and Locator user-triggered runs now route through the managed replace-latest path instead of the older busy-skip wrapper.
  - Before: rapid repeated short-task runs could skip the newer user action while an older result still completed. Stats and Word also share the same frequency result surface but had separate run entry points.
  - After: rapid reruns replace the previous request; stale results are discarded before applying page state or selected-tab persistence. Stats and Word share the frequency freshness token so the latest adjacent-page frequency run wins.
  - Quality impact: no analysis-truth change expected; the same repository calls, validated inputs, locator source selection, and result application paths are used. Focused tests assert only the latest corpus text, ChiSquare input, and Locator source reach page state.
- Task-center cancelled-state separation:
  - Change: `NativeBackgroundTaskState` now has a dedicated `cancelled` state and task-center snapshots expose `cancelledCount`.
  - Before: user-initiated cancellations were usually presented through failed-state counters or filtered failure notifications, which made task history harder to read.
  - After: managed result cancellation, update cancellation, diagnostics export cancellation, report-bundle export cancellation, and task-center cancel actions leave failed counts unchanged and show a distinct cancelled state. Late complete/fail events are ignored once the task is already cancelled.
  - Quality impact: no analysis-truth change expected; this only changes task state presentation and terminal-event routing.
- Topics result-assembly statistics optimization:
  - Change: `NativeTopicEngine+ResultAssembly` now precomputes per-slice keyword statistics, derives non-target rest statistics without rescanning every rest slice per cluster, and uses normalized cosine similarity for already-normalized topic vectors.
  - Before: bundled reference corpus Topics p50 3452.7 ms, p95 3463.0 ms; summarizing stage about 184 ms per run.
  - After: bundled reference corpus Topics p50 3252.9 ms, p95 3287.1 ms; summarizing stage about 30-31 ms per run.
  - Quality impact: key quality fields stayed stable across all three repeat runs: `approximateRefined`, 13 clusters, 238 clustered segments, 107 outliers, 345 total segments, warning count 1, bundled provider. `explainedVariance` changed only by floating-point tail precision around 0.9266709539964267.

Validated baseline commands:

```sh
zsh Scripts/run-1.4-performance-baseline.sh
swift test --filter TopicBenchmarkTests
swift test --filter SentimentBenchmarkTests
swift test --filter SentimentBenchmarkReportTests
swift test --filter PerformanceBoundaryTests
zsh Scripts/run-1.4-ui-performance-check.sh --release --disable-swiftpm-sandbox
swift test --filter UserBenchmarkTests/testRunFixedFixtureBenchmarkForRoadmapBaseline
swift test --filter UserBenchmarkTests/testRunReferenceCorpusFixtureBenchmarkForRoadmapBaseline
swift test --filter LibraryPerformanceBaselineTests/testRunLibraryPerformanceBaselineForRoadmap
swift test --filter ViewModelsTests/testLibraryManagementViewModelSkipsPublishingUnchangedSceneSyncs --filter ViewModelsTests/testLibraryManagementViewModelAppliesInitialEmptyLibrarySnapshotOnce
swift test --filter NativeTopicEngineTests --filter TopicBenchmarkTests
swift test --filter UserBenchmarkTests/testRunReferenceCorpusFixtureBenchmarkForRoadmapBaseline
swift test --filter WorkspaceRuntimeConcurrencyTests
swift test --filter 'WorkspaceRuntimeConcurrencyTests|WorkspaceWorkflowChainTests|WorkspaceFailurePathTests|CoordinatorsTests'
swift test --filter 'SentimentEngineFeatureTests|SentimentPresentationFeatureTests'
swift test --filter 'WorkspaceRuntimeConcurrencyTests|WorkspaceWorkflowChainTests|WorkspaceFailurePathTests|WorkspaceActionDispatcherTests|SentimentEngineFeatureTests|SentimentPresentationFeatureTests|CompositionTests'
swift test --filter 'WorkspaceRuntimeConcurrencyTests|PlotClusterFeatureTests|MainWorkspaceViewModelTests|WorkspaceActionDispatcherTests|WorkspaceWorkflowChainTests|WorkspaceFailurePathTests|CoordinatorsTests|CompositionTests'
swift test --filter 'NativeTaskCenterTests|WorkspaceFailurePathTests|MainWorkspaceViewModelTests|NativeHostPreferencesStoreTests|NativeDiagnosticsBundleServiceTests|CompositionTests'
zsh Scripts/run-1.4-performance-baseline.sh --release --output-dir .build/reports/1.4.0-release
HOME=/tmp/wordz-swiftpm-home CLANG_MODULE_CACHE_PATH=/tmp/wordz-clang-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/wordz-swiftpm-module-cache zsh Scripts/run-1.4-performance-baseline.sh --release --disable-swiftpm-sandbox --output-dir .build/reports/1.4.0-release-post-library
swift test --disable-sandbox --skip-build --filter NativeCorpusDatabaseSupportTests
CLANG_MODULE_CACHE_PATH=/tmp/wordz-clang-module-cache SWIFTPM_HOME=/tmp/wordz-swiftpm-cache WORDZ_1_4_BASELINE_OUTPUT_DIR=/tmp/wordz-library-baseline-after-3 WORDZ_1_4_LIBRARY_BASELINE_BUILD_CONFIGURATION=release swift test --disable-sandbox -c release --filter LibraryPerformanceBaselineTests/testRunLibraryPerformanceBaselineForRoadmap
WORDZ_MAC_DISABLE_SWIFTPM_SANDBOX=1 WORDZ_MAC_DIST_DIR=/tmp/wordz-app-smoke zsh Scripts/build-app.sh
zsh Scripts/release-smoke.sh /tmp/wordz-app-smoke/WordZ.app
zsh Scripts/run-1.4-api-privacy-check.sh --release --disable-swiftpm-sandbox
zsh Scripts/run-1.4-api-recovery-check.sh --release --disable-swiftpm-sandbox
```

Note: earlier aggregate shell entrypoints needed a less restricted environment because nested `swift test` calls can write SwiftPM/clang cache state outside the writable workspace. The latest release aggregate run completed in the current managed workspace. The generated reports are ignored under `.build/reports/`. In this environment the app bundle and pkg can be validated, but final DMG generation still needs a local release machine where `hdiutil create` is available.

Next required work:

- keep Topics embedding under watch; the remaining hotspot is embedding, and further work should only land with before/after quality evidence
- keep the duplicate-snapshot Library refresh guard covered by the Library baseline so regressions show up as p95 movement
- keep `Scripts/run-1.4-ui-performance-check.sh --release --disable-swiftpm-sandbox` in the pre-tag checklist
- run final DMG packaging on a machine that supports `hdiutil create` before tagging

Baseline command:

```sh
zsh Scripts/run-1.4-performance-baseline.sh
```

Optional external user corpus run:

```sh
zsh Scripts/run-1.4-performance-baseline.sh --user-file /path/to/corpus.txt --user-repeat 3
```

## Next API Work

1. Keep `Scripts/run-1.4-api-privacy-check.sh --release --disable-swiftpm-sandbox` and `Scripts/run-1.4-api-recovery-check.sh --release --disable-swiftpm-sandbox` in the pre-tag checklist.
2. Keep the 1.4.0 API pilot limited to manual connection checking unless a future API feature can meet the same no-corpus-upload, no-analysis-truth-change, redacted-diagnostics, and redacted-failure-UI contract.

## Next Performance Work

1. Keep Topics embedding under watch; do not add another Topics optimization unless it preserves the quality fields already tracked above.
2. Keep Library scene open under watch; aggregate release p95 is about 115 ms for 1,200 synthetic corpora, while duplicate refresh is now effectively skipped.
3. Keep the 1.4 UI performance gate in release checklist runs before packaging.
4. Run final DMG packaging on a release machine where `hdiutil create` is available.
5. Keep every performance change tied to a measurable baseline entry.
