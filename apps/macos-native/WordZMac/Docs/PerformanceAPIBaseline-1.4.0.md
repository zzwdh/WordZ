# WordZ 1.4.0 Performance/API Baseline

## Current Status

Updated: 2026-06-22

This file tracks the concrete 1.4.0 work that supports the roadmap theme: performance optimization and API call stabilization.

## API Foundation

Status: first implementation and the narrow manual API pilot have landed; focused validation is green.

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

Current API contract:

- API calls are optional infrastructure and must not block local corpus analysis.
- User-facing features should not call `URLSession` directly when the request belongs to app-level API behavior.
- API errors must preserve enough detail for recovery while avoiding raw credentials or sensitive payloads in logs.
- API work must be cancellable through Swift task cancellation.
- When API access is disabled, local analysis remains available and network-backed update checks/downloads do not run.

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

Latest pilot privacy validation:

```sh
swift test --filter NativeUpdateServiceTests/testNativeAPIConnectionTestServiceUsesUnifiedClientAndCredentialHeader --filter MainWorkspaceViewModelTests/testAPIConnectionCheckAddsRedactedPilotMetadataToDiagnostics
```

Result: 2 focused API pilot diagnostics tests, 0 failures. The workspace test encodes the diagnostics payload and verifies it does not contain the saved token, API key, URL query token, or a sample corpus text fragment.

## Performance Baseline

Status: fixed-machine algorithm, small fixture, bundled reference-corpus, Library/import baseline, first Library refresh optimization, first Topics result-assembly optimization, first Library import/index shard-write optimization, and release-mode aggregate baseline captured.

Existing foundation:

- runtime budget policy exists for analysis tasks
- large result scene boundary tests exist
- previous topic benchmark work established the expected before/after quality comparison pattern
- `Scripts/run-1.4-performance-baseline.sh` now aggregates fixed topic, sentiment, fixed user fixture, bundled reference-corpus fixture, Library/import, and optional external user corpus reports
- `Scripts/run-1.4-performance-baseline.sh --release` runs the fixed reports through release SwiftPM tests and records `buildConfiguration: "release"` in the manifest

Latest aggregate fixed run:

- Date: 2026-06-16
- Generated at: 2026-06-16T15:42:30Z
- Output directory: `.build/reports/1.4.0`
- Hardware summary: `appleSilicon`, Metal available, ANE available, 10 active processors, 24576 MB memory, low power off, thermal nominal.
- Topic exact fixture: `three-theme-exact-300`, 4217.0 ms, purity 1.000, theme recall 1.000, 3 clusters.
- Topic approximate fixture: `three-theme-approx-450`, 2802.0 ms, purity 1.000, theme recall 1.000, 3 clusters.
- Sentiment mixed baseline: `sentiment-gold-v2`, 72 examples, accuracy 0.833, macro F1 0.834, neutral false positive rate 0.229.
- Sentiment news-focused baseline: `sentiment-gold-v3`, 18 examples, accuracy 0.944, macro F1 0.944, neutral false positive rate 0.000.
- Large-result UI boundary suite: 19 tests passed, covering rapid paging, sorting, filtering, column visibility, visible-row reloads, and latest-scene application across major analysis pages.
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

Latest aggregate release run:

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
- Current release-mode priority after Topics optimization:
  1. Library import/index, aggregate p95 426.1 ms before the shard-write optimization.
  2. Library scene open, p95 118.3 ms.
  3. Sentiment on bundled reference corpus, p95 79.5 ms.
  4. KWIC smoke, p95 8.6 ms.

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
swift test --filter UserBenchmarkTests/testRunFixedFixtureBenchmarkForRoadmapBaseline
swift test --filter UserBenchmarkTests/testRunReferenceCorpusFixtureBenchmarkForRoadmapBaseline
swift test --filter LibraryPerformanceBaselineTests/testRunLibraryPerformanceBaselineForRoadmap
swift test --filter ViewModelsTests/testLibraryManagementViewModelSkipsPublishingUnchangedSceneSyncs --filter ViewModelsTests/testLibraryManagementViewModelAppliesInitialEmptyLibrarySnapshotOnce
swift test --filter NativeTopicEngineTests --filter TopicBenchmarkTests
swift test --filter UserBenchmarkTests/testRunReferenceCorpusFixtureBenchmarkForRoadmapBaseline
zsh Scripts/run-1.4-performance-baseline.sh --release --output-dir .build/reports/1.4.0-release
swift test --disable-sandbox --skip-build --filter NativeCorpusDatabaseSupportTests
CLANG_MODULE_CACHE_PATH=/tmp/wordz-clang-module-cache SWIFTPM_HOME=/tmp/wordz-swiftpm-cache WORDZ_1_4_BASELINE_OUTPUT_DIR=/tmp/wordz-library-baseline-after-3 WORDZ_1_4_LIBRARY_BASELINE_BUILD_CONFIGURATION=release swift test --disable-sandbox -c release --filter LibraryPerformanceBaselineTests/testRunLibraryPerformanceBaselineForRoadmap
```

Note: earlier aggregate shell entrypoints needed a less restricted environment because nested `swift test` calls can write SwiftPM/clang cache state outside the writable workspace. The latest release aggregate run completed in the current managed workspace. The generated reports are ignored under `.build/reports/`.

Next required work:

- rerun the full release aggregate baseline after the Library shard-write optimization before tagging, because the current proof is a focused release Library baseline
- keep Topics embedding under watch; the remaining hotspot is embedding, and further work should only land with before/after quality evidence
- keep the duplicate-snapshot Library refresh guard covered by the Library baseline so regressions show up as p95 movement

Baseline command:

```sh
zsh Scripts/run-1.4-performance-baseline.sh
```

Optional external user corpus run:

```sh
zsh Scripts/run-1.4-performance-baseline.sh --user-file /path/to/corpus.txt --user-repeat 3
```

## Next API Work

1. Run one release/build-package diagnostics export check before tagging to confirm the pilot metadata remains redacted outside the debug test harness.
2. Keep the 1.4.0 API pilot limited to manual connection checking unless a future API feature can meet the same no-corpus-upload, no-analysis-truth-change, and redacted-diagnostics contract.

## Next Performance Work

1. Rerun the full release aggregate baseline after the Library shard-write optimization and update the aggregate p95 table before tagging.
2. Keep Topics embedding under watch; do not add another Topics optimization unless it preserves the quality fields already tracked above.
3. Keep Library scene open under watch; focused release p95 is about 106 ms for 1,200 synthetic corpora, while duplicate refresh is now effectively skipped.
4. Use Library scene open or packaged-app smoke as the next performance gate instead of another Library import/index pass unless the aggregate rerun contradicts the focused result.
5. Keep every performance change tied to a measurable baseline entry.
