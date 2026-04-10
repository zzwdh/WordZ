import XCTest
@testable import WordZMac

@MainActor
final class MainWorkspaceViewModelTests: XCTestCase {
    func testInitializeIfNeededBootstrapsSceneGraph() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore()
        )

        await workspace.initializeIfNeeded()

        XCTAssertEqual(workspace.sceneGraph.context.appName, "WordZ")
        XCTAssertEqual(workspace.sceneGraph.activeTab, .kwic)
        XCTAssertEqual(workspace.sceneGraph.sidebar.currentCorpus?.title, "Demo Corpus")
        XCTAssertEqual(workspace.sceneGraph.settings.workspaceSummary, "工作区：Demo Corpus ｜ 当前语料：Demo Corpus")
        XCTAssertFalse(workspace.isWelcomePresented)
    }

    func testRunAnalysisFlowsUpdateSceneGraphResultNodes() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.ngram.query = "phrase"
        workspace.kwic.keyword = "node"
        workspace.collocate.keyword = "node"
        workspace.compare.syncLibrarySnapshot(repository.bootstrapState.librarySnapshot)
        workspace.chiSquare.a = "10"
        workspace.chiSquare.b = "20"
        workspace.chiSquare.c = "6"
        workspace.chiSquare.d = "14"

        await workspace.runStats()
        XCTAssertTrue(workspace.sceneGraph.stats.hasResult)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .stats)

        await workspace.runTokenize()
        XCTAssertTrue(workspace.sceneGraph.tokenize.hasResult)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .tokenize)

        await workspace.runCompare()
        XCTAssertTrue(workspace.sceneGraph.compare.hasResult)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .compare)

        await workspace.runChiSquare()
        XCTAssertTrue(workspace.sceneGraph.chiSquare.hasResult)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .chiSquare)

        await workspace.runNgram()
        XCTAssertTrue(workspace.sceneGraph.ngram.hasResult)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .ngram)

        await workspace.runKWIC()
        XCTAssertTrue(workspace.sceneGraph.kwic.hasResult)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .kwic)

        await workspace.runCollocate()
        XCTAssertTrue(workspace.sceneGraph.collocate.hasResult)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .collocate)

        await workspace.runLocator()
        XCTAssertTrue(workspace.sceneGraph.locator.hasResult)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .locator)
    }

    func testResultContentSyncRefreshesSidebarSummaryAndExportAvailabilityFromUpdatedGraph() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        XCTAssertNil(workspace.sidebar.scene.results)
        XCTAssertEqual(
            workspace.shell.scene.toolbar.items.first(where: { $0.action == .exportCurrent })?.isEnabled,
            false
        )

        await workspace.runStats()

        XCTAssertEqual(workspace.sidebar.scene.results?.title, workspace.sceneGraph.stats.title)
        XCTAssertEqual(workspace.sidebar.scene.results?.subtitle, workspace.sceneGraph.stats.status)
        XCTAssertEqual(
            workspace.shell.scene.toolbar.items.first(where: { $0.action == .exportCurrent })?.isEnabled,
            true
        )
    }

    func testSettingsSceneSyncDoesNotHijackMainWorkspaceTab() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.selectedTab = .word
        workspace.settings.debugLogging = true
        workspace.syncSceneGraph(source: .settings)

        XCTAssertEqual(workspace.sceneGraph.activeTab, .word)
        XCTAssertTrue(workspace.settings.debugLogging)
    }

    func testOpenSelectedCorpusUpdatesSidebarAndPersistsWorkspace() async {
        let repository = FakeWorkspaceRepository()
        let hostPreferences = InMemoryHostPreferencesStore()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: hostPreferences
        )

        await workspace.initializeIfNeeded()
        await workspace.openSelectedCorpus()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.openSavedCorpusCallCount, 1)
        XCTAssertEqual(workspace.sceneGraph.sidebar.currentCorpus?.title, "Demo Corpus")
        XCTAssertFalse(repository.savedWorkspaceDrafts.isEmpty)
        XCTAssertEqual(hostPreferences.recordRecentCallCount, 1)
        XCTAssertEqual(workspace.settings.scene.recentDocuments.first?.corpusID, "corpus-1")
    }

    func testOpenRecentDocumentPreparesSelectionWithoutExtraWorkspaceSave() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        let savedDraftCountBeforeOpen = repository.savedWorkspaceDrafts.count

        await workspace.openRecentDocument("corpus-2")
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.openSavedCorpusCallCount, 1)
        XCTAssertEqual(repository.savedWorkspaceDrafts.count, savedDraftCountBeforeOpen + 1)
        XCTAssertEqual(workspace.sidebar.selectedCorpusID, "corpus-2")
        XCTAssertEqual(workspace.sceneGraph.sidebar.currentCorpus?.title, "Compare Corpus")
    }

    func testNewWorkspaceResetsSelectionAndSavesEmptyWorkspace() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        await workspace.newWorkspace()

        XCTAssertEqual(workspace.selectedTab, .stats)
        XCTAssertNil(workspace.sidebar.selectedCorpusID)
        XCTAssertTrue(repository.savedWorkspaceDrafts.contains(where: { draft in
            draft.currentTab == WorkspaceDetailTab.stats.snapshotValue && draft.corpusIds.isEmpty
        }))
    }

    func testRestoreSavedWorkspaceReappliesSavedQueryState() async {
        let repository = FakeWorkspaceRepository(
            bootstrapState: makeBootstrapState(
                workspaceSnapshot: makeWorkspaceSnapshot(
                    currentTab: "chi-square",
                    searchQuery: "cloud-1*",
                    topicsMinTopicSize: "4",
                    topicsIncludeOutliers: false,
                    topicsPageSize: "25",
                    topicsActiveTopicID: "topic-2",
                    chiSquareA: "10",
                    chiSquareB: "20",
                    chiSquareC: "6",
                    chiSquareD: "14",
                    chiSquareUseYates: true
                )
            )
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.kwic.keyword = ""
        workspace.word.query = ""
        workspace.topics.minTopicSize = "2"
        workspace.chiSquare.a = ""

        await workspace.restoreSavedWorkspace()

        XCTAssertEqual(workspace.selectedTab, .chiSquare)
        XCTAssertEqual(workspace.word.query, "cloud-1*")
        XCTAssertEqual(workspace.topics.minTopicSize, "4")
        XCTAssertFalse(workspace.topics.includeOutliers)
        XCTAssertEqual(workspace.chiSquare.a, "10")
        XCTAssertEqual(workspace.chiSquare.d, "14")
        XCTAssertTrue(workspace.chiSquare.useYates)
    }

    func testSaveSettingsPersistsCurrentSnapshot() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        workspace.settings.showWelcomeScreen = false
        workspace.settings.debugLogging = true

        await workspace.saveSettings()

        XCTAssertEqual(repository.savedUISettings.count, 1)
        XCTAssertEqual(repository.savedUISettings.first?.showWelcomeScreen, false)
        XCTAssertEqual(repository.savedUISettings.first?.debugLogging, true)
    }

    func testShowSelectedCorpusInfoBuildsLibraryInfoSheet() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        await workspace.handleLibraryAction(.showSelectedCorpusInfo)

        XCTAssertEqual(repository.loadCorpusInfoCallCount, 1)
        XCTAssertEqual(repository.openSavedCorpusCallCount, 0)
        XCTAssertEqual(repository.runStatsCallCount, 0)
        XCTAssertEqual(workspace.library.corpusInfoSheet?.title, "Demo Corpus")
        XCTAssertEqual(workspace.library.corpusInfoSheet?.tokenCountText, "\(repository.corpusInfoResult.tokenCount)")
        XCTAssertEqual(workspace.library.corpusInfoSheet?.typeCountText, "\(repository.corpusInfoResult.typeCount)")
        XCTAssertEqual(workspace.library.corpusInfoSheet?.encodingText, "UTF-8")
        XCTAssertEqual(workspace.library.corpusInfoSheet?.genreText, "教学")
        XCTAssertEqual(workspace.library.corpusInfoSheet?.tagsText, "课堂, 基础")
    }

    func testPerformTaskActionOpenFileUsesHostActionService() async {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostActionService: hostActions
        )

        await workspace.performTaskAction(.openFile(path: "/tmp/report.csv"))

        XCTAssertEqual(hostActions.openedFilePaths, ["/tmp/report.csv"])
    }

    func testPerformTaskActionOpenURLUsesHostActionService() async {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostActionService: hostActions
        )

        await workspace.performTaskAction(.openURL("https://example.com/release"))

        XCTAssertEqual(hostActions.openedExternalURLs, ["https://example.com/release"])
    }

    func testShutdownStopsRepository() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.shutdown()

        XCTAssertTrue(repository.stopCalled)
    }

    func testCheckForUpdatesUsesHostServicesAndUpdatesSettingsScene() async {
        let repository = FakeWorkspaceRepository()
        let hostPreferences = InMemoryHostPreferencesStore()
        let hostActions = FakeHostActionService()
        let updateService = FakeUpdateService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: hostPreferences,
            hostActionService: hostActions,
            updateService: updateService
        )

        await workspace.initializeIfNeeded()
        await workspace.checkForUpdatesNow()

        XCTAssertEqual(updateService.checkCallCount, 1)
        XCTAssertEqual(hostPreferences.recordUpdateCheckCallCount, 1)
        XCTAssertTrue(workspace.settings.scene.updateSummary.contains("发现新版本"))
        XCTAssertEqual(workspace.settings.scene.latestReleaseTitle, "WordZ 1.1.1")
        XCTAssertEqual(workspace.settings.scene.latestAssetName, "WordZ-1.1.1-mac-arm64.dmg")
        XCTAssertEqual(workspace.settings.scene.latestReleaseNotes, ["Native table layout persistence"])
    }

    func testConcurrentCheckForUpdatesSharesSingleInFlightRequest() async {
        let repository = FakeWorkspaceRepository()
        let updateService = FakeUpdateService()
        updateService.checkDelayNanoseconds = 80_000_000
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            updateService: updateService
        )

        await workspace.initializeIfNeeded()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await workspace.checkForUpdatesNow() }
            group.addTask { await workspace.checkForUpdatesNow() }
            await group.waitForAll()
        }

        XCTAssertEqual(updateService.checkCallCount, 1)
    }

    func testLaunchTriggeredUpdateCheckCanRunWithoutCancellingPendingLaunchTask() async {
        let repository = FakeWorkspaceRepository()
        let updateService = FakeUpdateService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            updateService: updateService
        )

        workspace.launchUpdateCheckTask = Task { }
        await workspace.checkForUpdatesNow(cancelPendingLaunchTask: false)

        XCTAssertEqual(updateService.checkCallCount, 1)
        XCTAssertNil(workspace.issueBanner)
        XCTAssertTrue(workspace.settings.scene.updateSummary.contains("发现新版本"))
    }

    func testLaunchTriggeredUpdateCheckPostsShowUpdateWindowWhenUpdateIsAvailable() async {
        let repository = FakeWorkspaceRepository()
        let updateService = FakeUpdateService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            updateService: updateService
        )

        let presented = expectation(description: "show update window")
        let token = NotificationCenter.default.addObserver(
            forName: .wordZMacCommandTriggered,
            object: nil,
            queue: nil
        ) { notification in
            if NativeAppCommandCenter.parse(notification) == .showUpdateWindow {
                presented.fulfill()
            }
        }
        defer { NotificationCenter.default.removeObserver(token) }

        await workspace.checkForUpdatesNow(trigger: .launch)

        await fulfillment(of: [presented], timeout: 1)
        XCTAssertNil(workspace.issueBanner)
    }

    func testLaunchTriggeredUpdateFailureDoesNotProduceIssueBanner() async {
        let repository = FakeWorkspaceRepository()
        let updateService = FakeUpdateService()
        updateService.error = NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "offline"])
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            updateService: updateService
        )

        await workspace.checkForUpdatesNow(trigger: .launch)

        XCTAssertNil(workspace.issueBanner)
        XCTAssertEqual(workspace.settings.scene.supportStatus, "offline")
    }

    func testAutoDownloadReusesCheckedResultWithoutSecondCheck() async {
        let repository = FakeWorkspaceRepository()
        let updateService = FakeUpdateService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            updateService: updateService
        )

        await workspace.initializeIfNeeded()
        workspace.settings.autoDownloadUpdates = true
        await workspace.checkForUpdatesNow()

        XCTAssertEqual(updateService.checkCallCount, 1)
        XCTAssertEqual(updateService.downloadCallCount, 1)
        XCTAssertEqual(workspace.settings.scene.downloadedUpdateName, "WordZ-1.1.1-mac-arm64.dmg")
    }

    func testInstallLatestUpdateAndRestartHandsOffDownloadedInstaller() async {
        let repository = FakeWorkspaceRepository()
        let hostPreferences = InMemoryHostPreferencesStore()
        hostPreferences.snapshot.downloadedUpdateName = "WordZ-1.1.1-mac-arm64.dmg"
        hostPreferences.snapshot.downloadedUpdatePath = "/tmp/WordZ-1.1.1-mac-arm64.dmg"
        let hostActions = FakeHostActionService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: hostPreferences,
            hostActionService: hostActions
        )

        await workspace.installLatestUpdateAndRestart()

        XCTAssertEqual(hostActions.openDownloadedUpdateAndTerminateCallCount, 1)
        XCTAssertEqual(hostActions.lastInstalledDownloadedUpdatePath, "/tmp/WordZ-1.1.1-mac-arm64.dmg")
    }

    func testDisableAutomaticUpdateDownloadsAndInstallPersistsPreferences() async {
        let repository = FakeWorkspaceRepository()
        let hostPreferences = InMemoryHostPreferencesStore()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: hostPreferences
        )

        workspace.settings.autoDownloadUpdates = true
        workspace.settings.autoInstallDownloadedUpdates = true

        await workspace.disableAutomaticUpdateDownloadsAndInstall()

        XCTAssertFalse(workspace.settings.autoDownloadUpdates)
        XCTAssertFalse(workspace.settings.autoInstallDownloadedUpdates)
        XCTAssertEqual(hostPreferences.saveCallCount, 1)
        XCTAssertFalse(hostPreferences.snapshot.autoDownloadUpdates)
        XCTAssertFalse(hostPreferences.snapshot.autoInstallDownloadedUpdates)
    }

    func testExportDiagnosticsWritesReportThroughHostActionService() async {
        let repository = FakeWorkspaceRepository()
        let hostPreferences = InMemoryHostPreferencesStore()
        hostPreferences.snapshot.recentDocuments = [
            RecentDocumentItem(
                corpusID: "corpus-1",
                title: "Demo Corpus",
                subtitle: "Default",
                representedPath: "/tmp/demo.txt",
                lastOpenedAt: "2026-04-03T00:00:00Z"
            )
        ]
        hostPreferences.snapshot.downloadedUpdatePath = "/tmp/WordZ-1.2.0-mac-arm64.dmg"
        let hostActions = FakeHostActionService()
        let diagnosticsBundleService = FakeDiagnosticsBundleService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: hostPreferences,
            hostActionService: hostActions,
            diagnosticsBundleService: diagnosticsBundleService
        )

        await workspace.initializeIfNeeded()
        await workspace.exportDiagnostics(preferredWindowRoute: .settings)

        XCTAssertNotNil(diagnosticsBundleService.lastPayload)
        XCTAssertTrue(diagnosticsBundleService.lastPayload?.reportText.contains("WordZMac Diagnostics") == true)
        XCTAssertTrue(diagnosticsBundleService.lastPayload?.reportText.contains("Bundle ID") == true || diagnosticsBundleService.lastPayload?.reportText.contains("Bundle Identifier") == true)
        XCTAssertTrue(diagnosticsBundleService.lastPayload?.reportText.contains("引擎入口") == true || diagnosticsBundleService.lastPayload?.reportText.contains("Engine Entry") == true)
        XCTAssertTrue(diagnosticsBundleService.lastPayload?.reportText.contains("后台任务摘要") == true || diagnosticsBundleService.lastPayload?.reportText.contains("Task Center Summary") == true)
        XCTAssertFalse(diagnosticsBundleService.lastPayload?.reportText.contains("/tmp/WordZ-1.2.0-mac-arm64.dmg") == true)
        XCTAssertEqual(diagnosticsBundleService.lastPayload?.hostPreferences.recentDocuments.first?.representedPath, "<redacted>/demo.txt")
        XCTAssertEqual(diagnosticsBundleService.lastPayload?.hostPreferences.downloadedUpdatePath, "<redacted>/WordZ-1.2.0-mac-arm64.dmg")
        XCTAssertEqual(diagnosticsBundleService.lastPayload?.generatedFiles.map(\.relativePath), [
            "persisted/workspace-state.json",
            "persisted/ui-settings.json",
            "persisted/native-host-preferences.json"
        ])
        XCTAssertEqual(hostActions.exportedDiagnosticArchivePath, "/tmp/WordZMac-diagnostics.zip")
        XCTAssertEqual(hostActions.exportedDiagnosticPreferredRoute, .settings)
        XCTAssertEqual(workspace.settings.scene.supportStatus, "已导出诊断包到 /tmp/WordZMac-diagnostics.zip")
    }

    func testSaveCurrentAnalysisPresetPersistsAndReloadsPresetList() async {
        let repository = FakeWorkspaceRepository()
        let dialogService = FakeDialogService()
        dialogService.promptTextResult = "Compare Focus"
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()
        workspace.selectedTab = .compare
        workspace.compare.query = "rose"
        await workspace.saveCurrentAnalysisPreset(preferredWindowRoute: .mainWorkspace)

        XCTAssertEqual(repository.saveAnalysisPresetCallCount, 1)
        XCTAssertEqual(dialogService.promptTextPreferredRoute, .mainWorkspace)
        XCTAssertEqual(workspace.analysisPresets.first?.name, "Compare Focus")
        XCTAssertEqual(workspace.analysisPresets.first?.activeTab, .compare)
        XCTAssertEqual(workspace.settings.scene.supportStatus, "已保存分析预设：Compare Focus")
    }

    func testDeleteAnalysisPresetForwardsPreferredRouteToConfirmDialog() async {
        let repository = FakeWorkspaceRepository()
        repository.analysisPresetItems = [
            AnalysisPresetItem(
                id: "preset-1",
                name: "Compare Focus",
                createdAt: "today",
                updatedAt: "today",
                snapshot: WorkspaceSnapshotSummary(draft: .empty)
            )
        ]
        let dialogService = FakeDialogService()
        dialogService.confirmResult = true
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()
        await workspace.deleteAnalysisPreset("preset-1", preferredWindowRoute: .mainWorkspace)

        XCTAssertEqual(dialogService.confirmPreferredRoute, .mainWorkspace)
        XCTAssertEqual(repository.deleteAnalysisPresetCallCount, 1)
    }

    func testApplyAnalysisPresetRebuildsWorkspaceInputsAndPersistsDraft() async {
        let repository = FakeWorkspaceRepository()
        repository.analysisPresetItems = [
            AnalysisPresetItem(
                id: "preset-1",
                name: "Topic Drilldown",
                createdAt: "today",
                updatedAt: "today",
                snapshot: WorkspaceSnapshotSummary(
                    draft: WorkspaceStateDraft(
                        currentTab: WorkspaceDetailTab.topics.snapshotValue,
                        currentLibraryFolderId: "all",
                        selectedCorpusSetID: "",
                        corpusIds: ["corpus-1"],
                        corpusNames: ["Demo Corpus"],
                        searchQuery: "climate",
                        searchOptions: .default,
                        stopwordFilter: .default,
                        ngramSize: "2",
                        ngramPageSize: "10",
                        kwicLeftWindow: "5",
                        kwicRightWindow: "5",
                        collocateLeftWindow: "5",
                        collocateRightWindow: "5",
                        collocateMinFreq: "1",
                        topicsMinTopicSize: "6",
                        topicsIncludeOutliers: false,
                        topicsPageSize: "25",
                        topicsActiveTopicID: "topic-1",
                        chiSquareA: "",
                        chiSquareB: "",
                        chiSquareC: "",
                        chiSquareD: "",
                        chiSquareUseYates: false
                    )
                )
            )
        ]
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        await workspace.applyAnalysisPreset("preset-1")
        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(workspace.selectedTab, .topics)
        XCTAssertEqual(workspace.topics.minTopicSize, "6")
        XCTAssertFalse(workspace.topics.includeOutliers)
        XCTAssertEqual(workspace.topics.query, "climate")
        XCTAssertEqual(repository.savedWorkspaceDrafts.last?.currentTab, WorkspaceDetailTab.topics.snapshotValue)
    }

    func testResearchWorkflowComputedStateReflectsPresetAndBundleAvailability() async {
        let repository = FakeWorkspaceRepository()
        repository.analysisPresetItems = [
            AnalysisPresetItem(
                id: "preset-1",
                name: "KWIC Citation",
                createdAt: "2026-04-08T00:00:00Z",
                updatedAt: "2026-04-08T00:00:00Z",
                snapshot: WorkspaceSnapshotSummary(
                    draft: WorkspaceStateDraft(
                        currentTab: WorkspaceDetailTab.kwic.snapshotValue,
                        currentLibraryFolderId: "all",
                        selectedCorpusSetID: "",
                        corpusIds: ["corpus-1"],
                        corpusNames: ["Demo Corpus"],
                        searchQuery: "rose",
                        searchOptions: .default,
                        stopwordFilter: .default,
                        ngramSize: "2",
                        ngramPageSize: "10",
                        kwicLeftWindow: "5",
                        kwicRightWindow: "5",
                        collocateLeftWindow: "5",
                        collocateRightWindow: "5",
                        collocateMinFreq: "1",
                        topicsMinTopicSize: "4",
                        topicsIncludeOutliers: true,
                        topicsPageSize: "20",
                        topicsActiveTopicID: "",
                        chiSquareA: "",
                        chiSquareB: "",
                        chiSquareC: "",
                        chiSquareD: "",
                        chiSquareUseYates: false
                    )
                )
            )
        ]
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.kwic.keyword = "rose"
        await workspace.runKWIC()

        XCTAssertEqual(workspace.analysisPresets.first?.name, "KWIC Citation")
        XCTAssertTrue(workspace.canExportCurrentReportBundle)
    }

    func testExportCurrentReportBundleUsesArchiveExportAndTaskCenter() async {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let reportBundleService = FakeAnalysisReportBundleService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostActionService: hostActions,
            reportBundleService: reportBundleService
        )

        await workspace.initializeIfNeeded()
        await workspace.runStats()
        await workspace.exportCurrentReportBundle(preferredWindowRoute: .mainWorkspace)

        XCTAssertNotNil(reportBundleService.lastPayload)
        XCTAssertTrue(reportBundleService.lastPayload?.reportText.contains("WordZ Report Bundle") == true)
        XCTAssertNotNil(reportBundleService.lastPayload?.tableSnapshot)
        XCTAssertEqual(hostActions.exportedArchivePath, "/tmp/WordZMac-report.zip")
        XCTAssertEqual(hostActions.exportedArchiveTitle, "导出研究报告包")
        XCTAssertEqual(hostActions.exportedArchivePreferredRoute, .mainWorkspace)
        XCTAssertEqual(workspace.settings.scene.supportStatus, "已导出研究报告包到 /tmp/WordZMac-report.zip")
    }

    func testQuickLookCurrentContentUsesSelectedCorpusPathWhenNoResultSceneIsActive() async {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            hostActionService: hostActions
        )

        await workspace.initializeIfNeeded()
        await workspace.quickLookCurrentCorpus()

        XCTAssertEqual(hostActions.quickLookCallCount, 1)
        XCTAssertEqual(hostActions.lastQuickLookPath, "/tmp/demo.txt")
    }

    func testQuickLookCurrentContentBuildsTemporaryCSVForResultScene() async throws {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let previewDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("wordz-quicklook-\(UUID().uuidString)", isDirectory: true)
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            hostActionService: hostActions,
            quickLookPreviewFileService: QuickLookPreviewFileService(rootDirectory: previewDirectory)
        )

        await workspace.initializeIfNeeded()
        await workspace.runStats()
        await workspace.quickLookCurrentCorpus()

        XCTAssertEqual(hostActions.quickLookCallCount, 1)
        let previewPath = try XCTUnwrap(hostActions.lastQuickLookPath)
        XCTAssertTrue(previewPath.hasSuffix(".csv"))
        let contents = try String(contentsOfFile: previewPath, encoding: .utf8)
        XCTAssertTrue(contents.contains("word-0"))
    }

    func testQuickLookCurrentContentBuildsTemporaryCSVForChiSquareScene() async throws {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let previewDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("wordz-chi-square-quicklook-\(UUID().uuidString)", isDirectory: true)
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            hostActionService: hostActions,
            quickLookPreviewFileService: QuickLookPreviewFileService(rootDirectory: previewDirectory)
        )

        await workspace.initializeIfNeeded()
        workspace.chiSquare.a = "10"
        workspace.chiSquare.b = "20"
        workspace.chiSquare.c = "6"
        workspace.chiSquare.d = "14"
        await workspace.runChiSquare()
        await workspace.quickLookCurrentCorpus()

        XCTAssertEqual(hostActions.quickLookCallCount, 1)
        let previewPath = try XCTUnwrap(hostActions.lastQuickLookPath)
        XCTAssertTrue(previewPath.hasSuffix(".csv"))
        let contents = try String(contentsOfFile: previewPath, encoding: .utf8)
        XCTAssertTrue(contents.contains("section"))
        XCTAssertTrue(contents.contains("summary"))
    }

    func testShareCurrentContentBuildsTemporaryCSVForResultScene() async throws {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let previewDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("wordz-share-\(UUID().uuidString)", isDirectory: true)
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            hostActionService: hostActions,
            quickLookPreviewFileService: QuickLookPreviewFileService(rootDirectory: previewDirectory)
        )

        await workspace.initializeIfNeeded()
        await workspace.runStats()
        await workspace.shareCurrentContent()

        XCTAssertEqual(hostActions.shareCallCount, 1)
        let sharedPath = try XCTUnwrap(hostActions.lastSharedPaths.first)
        XCTAssertTrue(sharedPath.hasSuffix(".csv"))
        XCTAssertTrue(try String(contentsOfFile: sharedPath, encoding: .utf8).contains("word-0"))
    }

    func testShareCurrentContentBuildsTemporaryCSVForChiSquareScene() async throws {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let previewDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("wordz-chi-square-share-\(UUID().uuidString)", isDirectory: true)
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            hostActionService: hostActions,
            quickLookPreviewFileService: QuickLookPreviewFileService(rootDirectory: previewDirectory)
        )

        await workspace.initializeIfNeeded()
        workspace.chiSquare.a = "10"
        workspace.chiSquare.b = "20"
        workspace.chiSquare.c = "6"
        workspace.chiSquare.d = "14"
        await workspace.runChiSquare()
        await workspace.shareCurrentContent()

        XCTAssertEqual(hostActions.shareCallCount, 1)
        let sharedPath = try XCTUnwrap(hostActions.lastSharedPaths.first)
        XCTAssertTrue(sharedPath.hasSuffix(".csv"))
        XCTAssertTrue(try String(contentsOfFile: sharedPath, encoding: .utf8).contains("effect-summary"))
    }

    func testIssueBannerAppearsWhenBootstrapFails() async {
        let repository = FakeWorkspaceRepository()
        repository.startError = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"])
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()

        XCTAssertEqual(workspace.issueBanner?.title, "本地引擎启动失败")
        XCTAssertEqual(workspace.issueBanner?.message, "boom")
        XCTAssertEqual(workspace.issueBanner?.recoveryAction, .refreshWorkspace)
    }

    func testUpdateFailureProducesRetryableIssueBanner() async {
        let repository = FakeWorkspaceRepository()
        let updateService = FakeUpdateService()
        updateService.error = NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "offline"])
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            updateService: updateService
        )

        await workspace.initializeIfNeeded()
        await workspace.checkForUpdatesNow()

        XCTAssertEqual(workspace.issueBanner?.title, "更新检查失败")
        XCTAssertTrue(workspace.issueBanner?.message.contains("offline") == true)
        XCTAssertEqual(workspace.issueBanner?.recoveryAction, .checkForUpdates)
    }

    func testCancelledUpdateCheckDoesNotProduceIssueBanner() async {
        let repository = FakeWorkspaceRepository()
        let updateService = FakeUpdateService()
        updateService.error = CancellationError()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            updateService: updateService
        )

        await workspace.initializeIfNeeded()
        await workspace.checkForUpdatesNow()

        XCTAssertNil(workspace.issueBanner)
        XCTAssertEqual(workspace.settings.scene.supportStatus, "已取消检查更新。")
    }

    func testHandleExternalPathsImportsAndOpensFirstImportedCorpus() async {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            hostActionService: hostActions,
            updateService: FakeUpdateService()
        )

        await workspace.initializeIfNeeded()
        await workspace.handleExternalPaths(["/tmp/a.txt", "/tmp/b.txt"])
        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(repository.importCorpusPathsCallCount, 1)
        XCTAssertEqual(repository.openSavedCorpusCallCount, 1)
        XCTAssertEqual(workspace.sidebar.selectedCorpusID, "imported-1")
        XCTAssertFalse(workspace.isWelcomePresented)
    }

    func testClearRecentDocumentsClearsStoreAndHostRecentItems() async {
        let repository = FakeWorkspaceRepository()
        let hostPreferences = InMemoryHostPreferencesStore()
        hostPreferences.snapshot.recentDocuments = [
            RecentDocumentItem(
                corpusID: "corpus-1",
                title: "Demo Corpus",
                subtitle: "Default",
                representedPath: "/tmp/demo.txt",
                lastOpenedAt: "2026-03-26T00:00:00Z"
            )
        ]
        let hostActions = FakeHostActionService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: hostPreferences,
            hostActionService: hostActions,
            updateService: FakeUpdateService()
        )

        await workspace.initializeIfNeeded()
        await workspace.clearRecentDocuments()

        XCTAssertEqual(hostPreferences.clearRecentCallCount, 1)
        XCTAssertEqual(hostActions.clearRecentDocumentsCallCount, 1)
        XCTAssertTrue(workspace.settings.scene.recentDocuments.isEmpty)
    }

    func testRevealDownloadedUpdateUsesHostActionService() async {
        let repository = FakeWorkspaceRepository()
        let hostPreferences = InMemoryHostPreferencesStore()
        let hostActions = FakeHostActionService()
        let updateService = FakeUpdateService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: hostPreferences,
            hostActionService: hostActions,
            updateService: updateService
        )

        await workspace.initializeIfNeeded()
        await workspace.checkForUpdatesNow()
        await workspace.downloadLatestUpdate()
        await workspace.revealDownloadedUpdate()

        XCTAssertEqual(hostActions.revealDownloadedUpdateCallCount, 1)
        XCTAssertEqual(hostActions.lastRevealedDownloadedUpdatePath, "/tmp/WordZ-1.1.1-mac-arm64.dmg")
    }
}
