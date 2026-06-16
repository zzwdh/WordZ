# WordZ 1.4.0 Performance/API Baseline

## Current Status

Updated: 2026-06-16

This file tracks the concrete 1.4.0 work that supports the roadmap theme: performance optimization and API call stabilization.

## API Foundation

Status: first implementation landed and focused validation is green.

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
- saved API request timeout and max concurrency settings with conservative bounds
- API credential status in Settings without persisting the secret in host preferences
- update check and update download gating when API access is disabled
- live update-check service factory receives the current saved API timeout and max concurrency settings

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
- `MainWorkspaceViewModelTests.testAPIConnectionCheckDoesNotRunWhenAPIIsDisabled`
- `NativeDiagnosticsBundleServiceTests.testBuildBundleWritesArchiveWithRuntimeAndPersistedState`
- `NativeHostPreferencesStoreTests.testStoreRoundTripsSnapshotAndRecordsRecentDocuments`
- `SettingsTests.testSettingsViewModelAppliesSnapshotAndExportsValues`
- `SettingsTests.testAPIRequestPolicyClampsToConservativeBounds`
- existing update parsing, HTTP failure, and download failure tests

Latest focused validation:

```sh
swift test --filter NativeUpdateServiceTests --filter SettingsTests --filter NativeHostPreferencesStoreTests --filter MainWorkspaceViewModelTests/testCheckForUpdatesUsesCurrentAPIRequestPolicyFactory --filter MainWorkspaceViewModelTests/testCheckForUpdatesDoesNotCallServiceWhenAPIIsDisabled --filter MainWorkspaceViewModelTests/testAPICredentialActionsUseCredentialStoreWithoutPersistingSecretInPreferences --filter MainWorkspaceViewModelTests/testAPIConnectionCheckUsesSavedCredentialAndUpdatesSettingsScene --filter MainWorkspaceViewModelTests/testAPIConnectionCheckDoesNotRunWhenAPIIsDisabled
```

Result: 27 focused API/update/settings tests, 0 failures.

## Performance Baseline

Status: fixed-machine algorithm, small fixture, bundled reference-corpus, Library/import baseline, and first Library refresh optimization captured. The aggregate debug baseline now runs end-to-end outside the managed sandbox.

Existing foundation:

- runtime budget policy exists for analysis tasks
- large result scene boundary tests exist
- previous topic benchmark work established the expected before/after quality comparison pattern
- `Scripts/run-1.4-performance-baseline.sh` now aggregates fixed topic, sentiment, fixed user fixture, bundled reference-corpus fixture, Library/import, and optional external user corpus reports

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

Optimization notes:

- A low-level Sentiment phrase matching micro-optimization was tested on the reference corpus and rejected because it regressed Sentiment p95 from roughly 351 ms to roughly 762 ms. The code was reverted; do not pursue that direction without a narrower benchmark and proof that output quality and runtime both improve.
- A Topic local-embedding projection hash cache was tested and rejected. Quality fields stayed unchanged, but the reference-corpus Topics p95 did not show a reliable improvement, so the code was reverted instead of adding unproven cache complexity.
- Library duplicate snapshot refresh optimization:
  - Change: `LibraryManagementViewModel.applyLibrarySnapshot` now skips a full scene rebuild when the same `LibrarySnapshot` is applied after the initial load.
  - Before: synthetic 1,200-corpus Library refresh p95 108.9 ms.
  - After: synthetic 1,200-corpus Library refresh p95 0.003 ms.
  - Quality impact: none expected; this path only skips rebuilding an identical scene model. Empty-library initial bootstrap remains covered by a focused test.

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
```

Note: the aggregate shell entrypoint was run outside the managed sandbox because nested `swift test` calls write SwiftPM/clang cache state outside the writable workspace. The generated reports are ignored under `.build/reports/1.4.0`.

Next required work:

- compare quality-sensitive outputs before and after performance changes
- run the aggregate performance report with release/build-package conditions before tagging
- optimize Topics first, then compare Library import/index versus Sentiment before choosing the second optimization target
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

1. Decide the one narrow manual API pilot now that settings, credential controls, and connection testing exist.
2. Add pilot-specific diagnostics that prove request metadata is redacted and corpus text is not logged.

## Next Performance Work

1. Run the aggregate performance report with release/build-package conditions before tagging.
2. Optimize Topics with before/after quality comparison.
3. Choose the next target between Library import/index and Sentiment using release/build-package p95, because their debug p95 values remain close.
4. Keep Library scene open under watch; current debug p95 is about 153 ms for 1,200 synthetic corpora, while duplicate refresh is now effectively skipped.
5. Keep every performance change tied to a measurable baseline entry.
