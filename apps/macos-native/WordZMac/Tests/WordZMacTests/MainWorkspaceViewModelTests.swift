import XCTest
@testable import WordZMac

@MainActor
final class MainWorkspaceViewModelTests: XCTestCase {
    func testInitializeIfNeededBootstrapsSceneGraph() async {
        let repository = FakeWorkspaceRepository()
        let workspace = MainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore()
        )

        await workspace.initializeIfNeeded()

        XCTAssertEqual(workspace.sceneGraph.context.appName, "WordZ")
        XCTAssertEqual(workspace.sceneGraph.activeTab, .kwic)
        XCTAssertEqual(workspace.sceneGraph.sidebar.currentCorpus?.title, "Demo Corpus")
        XCTAssertEqual(workspace.sceneGraph.settings.workspaceSummary, "工作区：Demo Corpus ｜ 当前语料：Demo Corpus")
        XCTAssertTrue(workspace.isWelcomePresented)
    }

    func testRunAnalysisFlowsUpdateSceneGraphResultNodes() async {
        let repository = FakeWorkspaceRepository()
        let workspace = MainWorkspaceViewModel(repository: repository)

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

        await workspace.runWordCloud()
        XCTAssertTrue(workspace.sceneGraph.wordCloud.hasResult)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .wordCloud)

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

    func testSettingsSceneSyncDoesNotHijackMainWorkspaceTab() async {
        let repository = FakeWorkspaceRepository()
        let workspace = MainWorkspaceViewModel(repository: repository)

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
        let workspace = MainWorkspaceViewModel(
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

    func testNewWorkspaceResetsSelectionAndSavesEmptyWorkspace() async {
        let repository = FakeWorkspaceRepository()
        let workspace = MainWorkspaceViewModel(repository: repository)

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
                    wordCloudLimit: 140,
                    chiSquareA: "10",
                    chiSquareB: "20",
                    chiSquareC: "6",
                    chiSquareD: "14",
                    chiSquareUseYates: true
                )
            )
        )
        let workspace = MainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.kwic.keyword = ""
        workspace.wordCloud.limit = 20
        workspace.topics.minTopicSize = "2"
        workspace.chiSquare.a = ""

        await workspace.restoreSavedWorkspace()

        XCTAssertEqual(workspace.selectedTab, .chiSquare)
        XCTAssertEqual(workspace.wordCloud.query, "cloud-1*")
        XCTAssertEqual(workspace.wordCloud.limit, 140)
        XCTAssertEqual(workspace.topics.minTopicSize, "4")
        XCTAssertFalse(workspace.topics.includeOutliers)
        XCTAssertEqual(workspace.chiSquare.a, "10")
        XCTAssertEqual(workspace.chiSquare.d, "14")
        XCTAssertTrue(workspace.chiSquare.useYates)
    }

    func testSaveSettingsPersistsCurrentSnapshot() async {
        let repository = FakeWorkspaceRepository()
        let workspace = MainWorkspaceViewModel(repository: repository)

        workspace.settings.showWelcomeScreen = false
        workspace.settings.debugLogging = true

        await workspace.saveSettings()

        XCTAssertEqual(repository.savedUISettings.count, 1)
        XCTAssertEqual(repository.savedUISettings.first?.showWelcomeScreen, false)
        XCTAssertEqual(repository.savedUISettings.first?.debugLogging, true)
    }

    func testShowSelectedCorpusInfoBuildsLibraryInfoSheet() async {
        let repository = FakeWorkspaceRepository()
        let workspace = MainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        await workspace.handleLibraryAction(.showSelectedCorpusInfo)

        XCTAssertEqual(repository.openSavedCorpusCallCount, 1)
        XCTAssertEqual(repository.runStatsCallCount, 1)
        XCTAssertEqual(workspace.library.corpusInfoSheet?.title, "Demo Corpus")
        XCTAssertEqual(workspace.library.corpusInfoSheet?.tokenCountText, "\(repository.statsResult.tokenCount)")
        XCTAssertEqual(workspace.library.corpusInfoSheet?.typeCountText, "\(repository.statsResult.typeCount)")
    }

    func testShutdownStopsRepository() async {
        let repository = FakeWorkspaceRepository()
        let workspace = MainWorkspaceViewModel(repository: repository)

        await workspace.shutdown()

        XCTAssertTrue(repository.stopCalled)
    }

    func testCheckForUpdatesUsesHostServicesAndUpdatesSettingsScene() async {
        let repository = FakeWorkspaceRepository()
        let hostPreferences = InMemoryHostPreferencesStore()
        let hostActions = FakeHostActionService()
        let updateService = FakeUpdateService()
        let workspace = MainWorkspaceViewModel(
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
        let workspace = MainWorkspaceViewModel(
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

    func testAutoDownloadReusesCheckedResultWithoutSecondCheck() async {
        let repository = FakeWorkspaceRepository()
        let updateService = FakeUpdateService()
        let workspace = MainWorkspaceViewModel(
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

    func testExportDiagnosticsWritesReportThroughHostActionService() async {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let workspace = MainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            hostActionService: hostActions
        )

        await workspace.initializeIfNeeded()
        await workspace.exportDiagnostics()

        XCTAssertNotNil(hostActions.exportedReport)
        XCTAssertTrue(hostActions.exportedReport?.contains("WordZMac Diagnostics") == true)
        XCTAssertEqual(workspace.settings.scene.supportStatus, "已导出诊断到 /tmp/WordZMac-diagnostics.txt")
    }

    func testQuickLookCurrentContentUsesSelectedCorpusPathWhenNoResultSceneIsActive() async {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let workspace = MainWorkspaceViewModel(
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
        let workspace = MainWorkspaceViewModel(
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
        let workspace = MainWorkspaceViewModel(
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
        let workspace = MainWorkspaceViewModel(
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
        let workspace = MainWorkspaceViewModel(
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

    func testAdjustingWordCloudLimitAfterRunDoesNotRerunAnalysis() async {
        let repository = FakeWorkspaceRepository()
        let workspace = MainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        await workspace.runWordCloud()
        XCTAssertEqual(repository.runWordCloudCallCount, 1)

        workspace.wordCloud.handle(.changeLimit(10))
        workspace.syncSceneGraph(source: .resultContent)

        XCTAssertEqual(repository.runWordCloudCallCount, 1)
        XCTAssertEqual(workspace.wordCloud.scene?.visibleRows, 10)
        XCTAssertEqual(workspace.wordCloud.scene?.filteredRows, repository.wordCloudResult.rows.count)
    }

    func testIssueBannerAppearsWhenBootstrapFails() async {
        let repository = FakeWorkspaceRepository()
        repository.startError = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"])
        let workspace = MainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()

        XCTAssertEqual(workspace.issueBanner?.title, "本地引擎启动失败")
        XCTAssertEqual(workspace.issueBanner?.message, "boom")
        XCTAssertEqual(workspace.issueBanner?.recoveryAction, .refreshWorkspace)
    }

    func testUpdateFailureProducesRetryableIssueBanner() async {
        let repository = FakeWorkspaceRepository()
        let updateService = FakeUpdateService()
        updateService.error = NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "offline"])
        let workspace = MainWorkspaceViewModel(
            repository: repository,
            updateService: updateService
        )

        await workspace.initializeIfNeeded()
        await workspace.checkForUpdatesNow()

        XCTAssertEqual(workspace.issueBanner?.title, "更新检查失败")
        XCTAssertTrue(workspace.issueBanner?.message.contains("offline") == true)
        XCTAssertEqual(workspace.issueBanner?.recoveryAction, .checkForUpdates)
    }

    func testHandleExternalPathsImportsAndOpensFirstImportedCorpus() async {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let workspace = MainWorkspaceViewModel(
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
        let workspace = MainWorkspaceViewModel(
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
        let workspace = MainWorkspaceViewModel(
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
