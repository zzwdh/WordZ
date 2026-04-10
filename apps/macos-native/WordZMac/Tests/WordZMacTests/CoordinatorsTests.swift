import XCTest
@testable import WordZMac

@MainActor
final class CoordinatorsTests: XCTestCase {
    func testLibraryCoordinatorCachesOpenedCorpusForSameSelection() async throws {
        let repository = FakeWorkspaceRepository()
        let sessionStore = WorkspaceSessionStore()
        let coordinator = LibraryCoordinator(repository: repository, sessionStore: sessionStore)

        let first = try await coordinator.openSelection(selectedCorpusID: "corpus-1")
        let second = try await coordinator.ensureOpenedCorpus(selectedCorpusID: "corpus-1")

        XCTAssertEqual(first.displayName, "Demo Corpus")
        XCTAssertEqual(second.displayName, "Demo Corpus")
        XCTAssertEqual(repository.openSavedCorpusCallCount, 1)
    }

    func testAppCoordinatorRefreshAllAppliesBootstrapAndRestoresSelection() async {
        let repository = FakeWorkspaceRepository()
        let sceneStore = WorkspaceSceneStore()
        let sessionStore = WorkspaceSessionStore()
        let libraryCoordinator = LibraryCoordinator(repository: repository, sessionStore: sessionStore)
        let flowCoordinator = makeWorkspaceFlowCoordinator(
            repository: repository,
            workspacePersistence: WorkspacePersistenceService(),
            workspacePresentation: WorkspacePresentationService(),
            sceneStore: sceneStore,
            windowDocumentController: NativeWindowDocumentController(),
            dialogService: FakeDialogService(),
            sessionStore: sessionStore,
            libraryCoordinator: libraryCoordinator
        )
        let appCoordinator = makeAppCoordinator(
            repository: repository,
            sceneStore: sceneStore,
            sessionStore: sessionStore,
            flowCoordinator: flowCoordinator
        )
        let features = WorkspaceFeatureSet(
            sidebar: LibrarySidebarViewModel(),
            shell: WorkspaceShellViewModel(),
            library: LibraryManagementViewModel(),
            stats: StatsPageViewModel(),
            compare: ComparePageViewModel(),
            chiSquare: ChiSquarePageViewModel(),
            ngram: NgramPageViewModel(),
            kwic: KWICPageViewModel(),
            collocate: CollocatePageViewModel(),
            locator: LocatorPageViewModel(),
            settings: WorkspaceSettingsViewModel()
        )

        await appCoordinator.refreshAll(features: features)

        XCTAssertEqual(repository.loadBootstrapStateCallCount, 1)
        XCTAssertEqual(features.sidebar.selectedCorpusID, "corpus-1")
        XCTAssertEqual(features.shell.selectedTab, .kwic)
        XCTAssertEqual(features.kwic.keyword, "keyword")
        XCTAssertEqual(features.collocate.minFreq, "2")
        XCTAssertEqual(sceneStore.context.appName, "WordZ")
        XCTAssertEqual(features.sidebar.engineStatus, "本地引擎已连接")
        XCTAssertEqual(features.sidebar.lastErrorMessage, "")
    }

    func testAppCoordinatorRefreshAllSurfacesRepositoryFailure() async {
        let repository = FakeWorkspaceRepository()
        repository.loadError = NSError(domain: "Test", code: 9, userInfo: [NSLocalizedDescriptionKey: "load failed"])
        let sceneStore = WorkspaceSceneStore()
        let sessionStore = WorkspaceSessionStore()
        let libraryCoordinator = LibraryCoordinator(repository: repository, sessionStore: sessionStore)
        let flowCoordinator = makeWorkspaceFlowCoordinator(
            repository: repository,
            workspacePersistence: WorkspacePersistenceService(),
            workspacePresentation: WorkspacePresentationService(),
            sceneStore: sceneStore,
            windowDocumentController: NativeWindowDocumentController(),
            dialogService: FakeDialogService(),
            sessionStore: sessionStore,
            libraryCoordinator: libraryCoordinator
        )
        let appCoordinator = makeAppCoordinator(
            repository: repository,
            sceneStore: sceneStore,
            sessionStore: sessionStore,
            flowCoordinator: flowCoordinator
        )
        let features = WorkspaceFeatureSet(
            sidebar: LibrarySidebarViewModel(),
            shell: WorkspaceShellViewModel(),
            library: LibraryManagementViewModel(),
            stats: StatsPageViewModel(),
            compare: ComparePageViewModel(),
            chiSquare: ChiSquarePageViewModel(),
            ngram: NgramPageViewModel(),
            kwic: KWICPageViewModel(),
            collocate: CollocatePageViewModel(),
            locator: LocatorPageViewModel(),
            settings: WorkspaceSettingsViewModel()
        )

        await appCoordinator.refreshAll(features: features)

        XCTAssertEqual(features.sidebar.engineStatus, "本地引擎连接失败")
        XCTAssertEqual(features.sidebar.lastErrorMessage, "load failed")
        XCTAssertFalse(features.shell.isBusy)
    }

    func testWorkspaceFlowCoordinatorRunStatsOpensCorpusAndBuildsScene() async throws {
        let repository = FakeWorkspaceRepository()
        let sceneStore = WorkspaceSceneStore()
        sceneStore.applyAppInfo(repository.bootstrapState.appInfo)
        let sessionStore = WorkspaceSessionStore()
        sessionStore.applyBootstrap(snapshot: repository.bootstrapState.workspaceSnapshot)
        let libraryCoordinator = LibraryCoordinator(repository: repository, sessionStore: sessionStore)
        let taskCenter = NativeTaskCenter()
        let flowCoordinator = makeWorkspaceFlowCoordinator(
            repository: repository,
            workspacePersistence: WorkspacePersistenceService(),
            workspacePresentation: WorkspacePresentationService(),
            sceneStore: sceneStore,
            windowDocumentController: NativeWindowDocumentController(),
            dialogService: FakeDialogService(),
            sessionStore: sessionStore,
            libraryCoordinator: libraryCoordinator,
            taskCenter: taskCenter
        )
        let sidebar = LibrarySidebarViewModel()
        sidebar.applyBootstrap(repository.bootstrapState)
        sidebar.selectedCorpusID = "corpus-1"
        let features = WorkspaceFeatureSet(
            sidebar: sidebar,
            shell: WorkspaceShellViewModel(),
            library: LibraryManagementViewModel(),
            stats: StatsPageViewModel(),
            compare: ComparePageViewModel(),
            chiSquare: ChiSquarePageViewModel(),
            ngram: NgramPageViewModel(),
            kwic: KWICPageViewModel(),
            collocate: CollocatePageViewModel(),
            locator: LocatorPageViewModel(),
            settings: WorkspaceSettingsViewModel()
        )

        await flowCoordinator.runStats(features: features)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.openSavedCorpusCallCount, 1)
        XCTAssertEqual(repository.runStatsCallCount, 1)
        XCTAssertEqual(features.shell.selectedTab, .stats)
        XCTAssertEqual(features.stats.scene?.totalRows, repository.statsResult.frequencyRows.count)
        XCTAssertEqual(features.sidebar.lastErrorMessage, "")
        XCTAssertFalse(repository.savedWorkspaceDrafts.isEmpty)
        XCTAssertEqual(taskCenter.scene.completedCount, 1)
        XCTAssertEqual(taskCenter.scene.items.first?.title, wordZText("统计分析", "Run Stats", mode: .system))
    }

    func testWorkspaceFlowCoordinatorRunTopicsBuildsSceneAndSwitchesTab() async {
        let repository = FakeWorkspaceRepository()
        let sceneStore = WorkspaceSceneStore()
        sceneStore.applyAppInfo(repository.bootstrapState.appInfo)
        let sessionStore = WorkspaceSessionStore()
        sessionStore.applyBootstrap(snapshot: repository.bootstrapState.workspaceSnapshot)
        let libraryCoordinator = LibraryCoordinator(repository: repository, sessionStore: sessionStore)
        let flowCoordinator = makeWorkspaceFlowCoordinator(
            repository: repository,
            workspacePersistence: WorkspacePersistenceService(),
            workspacePresentation: WorkspacePresentationService(),
            sceneStore: sceneStore,
            windowDocumentController: NativeWindowDocumentController(),
            dialogService: FakeDialogService(),
            sessionStore: sessionStore,
            libraryCoordinator: libraryCoordinator
        )
        let sidebar = LibrarySidebarViewModel()
        sidebar.applyBootstrap(repository.bootstrapState)
        sidebar.selectedCorpusID = "corpus-1"
        let features = WorkspaceFeatureSet(
            sidebar: sidebar,
            shell: WorkspaceShellViewModel(),
            library: LibraryManagementViewModel(),
            stats: StatsPageViewModel(),
            topics: TopicsPageViewModel(),
            compare: ComparePageViewModel(),
            chiSquare: ChiSquarePageViewModel(),
            ngram: NgramPageViewModel(),
            kwic: KWICPageViewModel(),
            collocate: CollocatePageViewModel(),
            locator: LocatorPageViewModel(),
            settings: WorkspaceSettingsViewModel()
        )

        await flowCoordinator.runTopics(features: features)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.openSavedCorpusCallCount, 1)
        XCTAssertEqual(repository.runTopicsCallCount, 1)
        XCTAssertEqual(features.shell.selectedTab, .topics)
        XCTAssertEqual(features.topics.scene?.totalClusters, 2)
        XCTAssertEqual(features.topics.scene?.visibleSegments, 2)
        XCTAssertFalse(repository.savedWorkspaceDrafts.isEmpty)
    }

    func testWorkspaceFlowCoordinatorRunTopicsIgnoresConcurrentDuplicateRequests() async {
        let repository = FakeWorkspaceRepository()
        repository.topicsDelayNanoseconds = 80_000_000
        let sceneStore = WorkspaceSceneStore()
        sceneStore.applyAppInfo(repository.bootstrapState.appInfo)
        let sessionStore = WorkspaceSessionStore()
        sessionStore.applyBootstrap(snapshot: repository.bootstrapState.workspaceSnapshot)
        let libraryCoordinator = LibraryCoordinator(repository: repository, sessionStore: sessionStore)
        let flowCoordinator = makeWorkspaceFlowCoordinator(
            repository: repository,
            workspacePersistence: WorkspacePersistenceService(),
            workspacePresentation: WorkspacePresentationService(),
            sceneStore: sceneStore,
            windowDocumentController: NativeWindowDocumentController(),
            dialogService: FakeDialogService(),
            sessionStore: sessionStore,
            libraryCoordinator: libraryCoordinator
        )
        let sidebar = LibrarySidebarViewModel()
        sidebar.applyBootstrap(repository.bootstrapState)
        sidebar.selectedCorpusID = "corpus-1"
        let features = WorkspaceFeatureSet(
            sidebar: sidebar,
            shell: WorkspaceShellViewModel(),
            library: LibraryManagementViewModel(),
            stats: StatsPageViewModel(),
            topics: TopicsPageViewModel(),
            compare: ComparePageViewModel(),
            chiSquare: ChiSquarePageViewModel(),
            ngram: NgramPageViewModel(),
            kwic: KWICPageViewModel(),
            collocate: CollocatePageViewModel(),
            locator: LocatorPageViewModel(),
            settings: WorkspaceSettingsViewModel()
        )

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await flowCoordinator.runTopics(features: features) }
            group.addTask { await flowCoordinator.runTopics(features: features) }
            await group.waitForAll()
        }

        XCTAssertEqual(repository.runTopicsCallCount, 1)
        XCTAssertEqual(features.shell.selectedTab, .topics)
    }

    func testWorkspaceFlowCoordinatorRunTokenizeBuildsSceneAndSwitchesTab() async {
        let repository = FakeWorkspaceRepository()
        let sceneStore = WorkspaceSceneStore()
        sceneStore.applyAppInfo(repository.bootstrapState.appInfo)
        let sessionStore = WorkspaceSessionStore()
        sessionStore.applyBootstrap(snapshot: repository.bootstrapState.workspaceSnapshot)
        let libraryCoordinator = LibraryCoordinator(repository: repository, sessionStore: sessionStore)
        let flowCoordinator = makeWorkspaceFlowCoordinator(
            repository: repository,
            workspacePersistence: WorkspacePersistenceService(),
            workspacePresentation: WorkspacePresentationService(),
            sceneStore: sceneStore,
            windowDocumentController: NativeWindowDocumentController(),
            dialogService: FakeDialogService(),
            sessionStore: sessionStore,
            libraryCoordinator: libraryCoordinator
        )
        let sidebar = LibrarySidebarViewModel()
        sidebar.applyBootstrap(repository.bootstrapState)
        sidebar.selectedCorpusID = "corpus-1"
        let features = WorkspaceFeatureSet(
            sidebar: sidebar,
            shell: WorkspaceShellViewModel(),
            library: LibraryManagementViewModel(),
            stats: StatsPageViewModel(),
            tokenize: TokenizePageViewModel(),
            compare: ComparePageViewModel(),
            chiSquare: ChiSquarePageViewModel(),
            ngram: NgramPageViewModel(),
            kwic: KWICPageViewModel(),
            collocate: CollocatePageViewModel(),
            locator: LocatorPageViewModel(),
            settings: WorkspaceSettingsViewModel()
        )

        await flowCoordinator.runTokenize(features: features)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.openSavedCorpusCallCount, 1)
        XCTAssertEqual(repository.runTokenizeCallCount, 1)
        XCTAssertEqual(features.shell.selectedTab, .tokenize)
        XCTAssertEqual(features.tokenize.scene?.totalTokens, repository.tokenizeResult.tokenCount)
        XCTAssertFalse(repository.savedWorkspaceDrafts.isEmpty)
    }

    func testWorkspaceFlowCoordinatorRunCompareBuildsSceneAndSwitchesTab() async {
        let repository = FakeWorkspaceRepository()
        let sceneStore = WorkspaceSceneStore()
        sceneStore.applyAppInfo(repository.bootstrapState.appInfo)
        let sessionStore = WorkspaceSessionStore()
        sessionStore.applyBootstrap(snapshot: repository.bootstrapState.workspaceSnapshot)
        let libraryCoordinator = LibraryCoordinator(repository: repository, sessionStore: sessionStore)
        let flowCoordinator = makeWorkspaceFlowCoordinator(
            repository: repository,
            workspacePersistence: WorkspacePersistenceService(),
            workspacePresentation: WorkspacePresentationService(),
            sceneStore: sceneStore,
            windowDocumentController: NativeWindowDocumentController(),
            dialogService: FakeDialogService(),
            sessionStore: sessionStore,
            libraryCoordinator: libraryCoordinator
        )
        let sidebar = LibrarySidebarViewModel()
        sidebar.applyBootstrap(repository.bootstrapState)
        let compare = ComparePageViewModel()
        compare.syncLibrarySnapshot(repository.bootstrapState.librarySnapshot)
        let features = WorkspaceFeatureSet(
            sidebar: sidebar,
            shell: WorkspaceShellViewModel(),
            library: LibraryManagementViewModel(),
            stats: StatsPageViewModel(),
            compare: compare,
            chiSquare: ChiSquarePageViewModel(),
            ngram: NgramPageViewModel(),
            kwic: KWICPageViewModel(),
            collocate: CollocatePageViewModel(),
            locator: LocatorPageViewModel(),
            settings: WorkspaceSettingsViewModel()
        )

        await flowCoordinator.runCompare(features: features)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.runCompareCallCount, 1)
        XCTAssertEqual(features.shell.selectedTab, .compare)
        XCTAssertEqual(features.compare.scene?.totalRows, repository.compareResult.rows.count)
    }

    func testWorkspaceFlowCoordinatorCurrentDraftIncludesCompareSelection() {
        let repository = FakeWorkspaceRepository()
        let sceneStore = WorkspaceSceneStore()
        sceneStore.applyAppInfo(repository.bootstrapState.appInfo)
        let sessionStore = WorkspaceSessionStore()
        let libraryCoordinator = LibraryCoordinator(repository: repository, sessionStore: sessionStore)
        let flowCoordinator = makeWorkspaceFlowCoordinator(
            repository: repository,
            workspacePersistence: WorkspacePersistenceService(),
            workspacePresentation: WorkspacePresentationService(),
            sceneStore: sceneStore,
            windowDocumentController: NativeWindowDocumentController(),
            dialogService: FakeDialogService(),
            sessionStore: sessionStore,
            libraryCoordinator: libraryCoordinator
        )
        let sidebar = LibrarySidebarViewModel()
        sidebar.applyBootstrap(repository.bootstrapState)
        let compare = ComparePageViewModel()
        compare.syncLibrarySnapshot(repository.bootstrapState.librarySnapshot)
        compare.handle(.changeReferenceCorpus("corpus-2"))
        let features = WorkspaceFeatureSet(
            sidebar: sidebar,
            shell: WorkspaceShellViewModel(),
            library: LibraryManagementViewModel(),
            stats: StatsPageViewModel(),
            compare: compare,
            chiSquare: ChiSquarePageViewModel(),
            ngram: NgramPageViewModel(),
            kwic: KWICPageViewModel(),
            collocate: CollocatePageViewModel(),
            locator: LocatorPageViewModel(),
            settings: WorkspaceSettingsViewModel()
        )

        let draft = flowCoordinator.currentWorkspaceDraft(features: features)

        XCTAssertEqual(Set(draft.compareSelectedCorpusIDs), Set(["corpus-1", "corpus-2"]))
        XCTAssertEqual(draft.compareReferenceCorpusID, "corpus-2")
    }

    func testWorkspaceFlowCoordinatorRunChiSquareBuildsSceneAndSwitchesTab() async {
        let repository = FakeWorkspaceRepository()
        let sceneStore = WorkspaceSceneStore()
        sceneStore.applyAppInfo(repository.bootstrapState.appInfo)
        let sessionStore = WorkspaceSessionStore()
        let libraryCoordinator = LibraryCoordinator(repository: repository, sessionStore: sessionStore)
        let flowCoordinator = makeWorkspaceFlowCoordinator(
            repository: repository,
            workspacePersistence: WorkspacePersistenceService(),
            workspacePresentation: WorkspacePresentationService(),
            sceneStore: sceneStore,
            windowDocumentController: NativeWindowDocumentController(),
            dialogService: FakeDialogService(),
            sessionStore: sessionStore,
            libraryCoordinator: libraryCoordinator
        )
        let chiSquare = ChiSquarePageViewModel()
        chiSquare.a = "10"
        chiSquare.b = "20"
        chiSquare.c = "6"
        chiSquare.d = "14"
        let features = WorkspaceFeatureSet(
            sidebar: LibrarySidebarViewModel(),
            shell: WorkspaceShellViewModel(),
            library: LibraryManagementViewModel(),
            stats: StatsPageViewModel(),
            compare: ComparePageViewModel(),
            chiSquare: chiSquare,
            ngram: NgramPageViewModel(),
            kwic: KWICPageViewModel(),
            collocate: CollocatePageViewModel(),
            locator: LocatorPageViewModel(),
            settings: WorkspaceSettingsViewModel()
        )

        await flowCoordinator.runChiSquare(features: features)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.runChiSquareCallCount, 1)
        XCTAssertEqual(features.shell.selectedTab, .chiSquare)
        XCTAssertEqual(features.chiSquare.scene?.metrics.count, 6)
    }

    func testWorkspaceFlowCoordinatorRunNgramBuildsSceneAndSwitchesTab() async {
        let repository = FakeWorkspaceRepository()
        let sceneStore = WorkspaceSceneStore()
        sceneStore.applyAppInfo(repository.bootstrapState.appInfo)
        let sessionStore = WorkspaceSessionStore()
        sessionStore.applyBootstrap(snapshot: repository.bootstrapState.workspaceSnapshot)
        let libraryCoordinator = LibraryCoordinator(repository: repository, sessionStore: sessionStore)
        let flowCoordinator = makeWorkspaceFlowCoordinator(
            repository: repository,
            workspacePersistence: WorkspacePersistenceService(),
            workspacePresentation: WorkspacePresentationService(),
            sceneStore: sceneStore,
            windowDocumentController: NativeWindowDocumentController(),
            dialogService: FakeDialogService(),
            sessionStore: sessionStore,
            libraryCoordinator: libraryCoordinator
        )
        let sidebar = LibrarySidebarViewModel()
        sidebar.applyBootstrap(repository.bootstrapState)
        sidebar.selectedCorpusID = "corpus-1"
        let features = WorkspaceFeatureSet(
            sidebar: sidebar,
            shell: WorkspaceShellViewModel(),
            library: LibraryManagementViewModel(),
            stats: StatsPageViewModel(),
            compare: ComparePageViewModel(),
            chiSquare: ChiSquarePageViewModel(),
            ngram: NgramPageViewModel(),
            kwic: KWICPageViewModel(),
            collocate: CollocatePageViewModel(),
            locator: LocatorPageViewModel(),
            settings: WorkspaceSettingsViewModel()
        )

        await flowCoordinator.runNgram(features: features)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.openSavedCorpusCallCount, 1)
        XCTAssertEqual(repository.runNgramCallCount, 1)
        XCTAssertEqual(features.shell.selectedTab, .ngram)
        XCTAssertEqual(features.ngram.scene?.totalRows, repository.ngramResult.rows.count)
        XCTAssertFalse(repository.savedWorkspaceDrafts.isEmpty)
    }

    func testWorkspaceFlowCoordinatorRunLocatorUsesKwicSourceAndBuildsScene() async {
        let repository = FakeWorkspaceRepository()
        let sceneStore = WorkspaceSceneStore()
        sceneStore.applyAppInfo(repository.bootstrapState.appInfo)
        let sessionStore = WorkspaceSessionStore()
        sessionStore.applyBootstrap(snapshot: repository.bootstrapState.workspaceSnapshot)
        let libraryCoordinator = LibraryCoordinator(repository: repository, sessionStore: sessionStore)
        let flowCoordinator = makeWorkspaceFlowCoordinator(
            repository: repository,
            workspacePersistence: WorkspacePersistenceService(),
            workspacePresentation: WorkspacePresentationService(),
            sceneStore: sceneStore,
            windowDocumentController: NativeWindowDocumentController(),
            dialogService: FakeDialogService(),
            sessionStore: sessionStore,
            libraryCoordinator: libraryCoordinator
        )
        let sidebar = LibrarySidebarViewModel()
        sidebar.applyBootstrap(repository.bootstrapState)
        sidebar.selectedCorpusID = "corpus-1"
        let kwic = KWICPageViewModel()
        kwic.keyword = "node"
        kwic.apply(makeKWICResult(rowCount: 5))
        let locator = LocatorPageViewModel()
        locator.updateSource(kwic.primaryLocatorSource)
        let features = WorkspaceFeatureSet(
            sidebar: sidebar,
            shell: WorkspaceShellViewModel(),
            library: LibraryManagementViewModel(),
            stats: StatsPageViewModel(),
            compare: ComparePageViewModel(),
            chiSquare: ChiSquarePageViewModel(),
            ngram: NgramPageViewModel(),
            kwic: kwic,
            collocate: CollocatePageViewModel(),
            locator: locator,
            settings: WorkspaceSettingsViewModel()
        )

        await flowCoordinator.runLocator(features: features)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.runLocatorCallCount, 1)
        XCTAssertEqual(features.shell.selectedTab, .locator)
        XCTAssertEqual(features.locator.scene?.totalRows, repository.locatorResult.rows.count)
    }

    func testLibraryManagementCoordinatorImportsAndRefreshesSnapshots() async throws {
        let repository = FakeWorkspaceRepository()
        let sessionStore = WorkspaceSessionStore()
        let dialog = FakeDialogService()
        dialog.importPathsResult = ["/tmp/new-corpus.txt"]
        let coordinator = LibraryManagementCoordinator(
            repository: repository,
            dialogService: dialog,
            sessionStore: sessionStore
        )
        let library = LibraryManagementViewModel()
        let sidebar = LibrarySidebarViewModel()
        sidebar.applyBootstrap(repository.bootstrapState)
        library.applyBootstrap(repository.bootstrapState.librarySnapshot)

        _ = try await coordinator.importPaths(into: library, sidebar: sidebar)

        XCTAssertEqual(repository.importCorpusPathsCallCount, 1)
        XCTAssertTrue(sidebar.librarySnapshot.corpora.contains(where: { $0.name == "new-corpus" }))
        XCTAssertTrue(library.scene.statusMessage.contains("已导入"))
    }

    func testLibraryManagementCoordinatorSavesAndDeletesCorpusSet() async throws {
        let repository = FakeWorkspaceRepository()
        let sessionStore = WorkspaceSessionStore()
        let dialog = FakeDialogService()
        dialog.promptTextResult = "课堂语料集"
        let coordinator = LibraryManagementCoordinator(
            repository: repository,
            dialogService: dialog,
            sessionStore: sessionStore
        )
        let library = LibraryManagementViewModel()
        let sidebar = LibrarySidebarViewModel()
        sidebar.applyBootstrap(repository.bootstrapState)
        library.applyBootstrap(repository.bootstrapState.librarySnapshot)
        library.selectCorpusIDs(["corpus-1"])

        try await coordinator.saveCurrentCorpusSet(into: library, sidebar: sidebar)

        XCTAssertEqual(repository.saveCorpusSetCallCount, 1)
        XCTAssertEqual(library.selectedCorpusSet?.name, "课堂语料集")
        XCTAssertEqual(sidebar.selectedCorpusSetID, library.selectedCorpusSetID)
        XCTAssertTrue(library.scene.statusMessage.contains("已保存语料集"))
        XCTAssertEqual(repository.librarySnapshot.corpusSets.count, 1)

        try await coordinator.deleteSelectedCorpusSet(into: library, sidebar: sidebar)

        XCTAssertEqual(repository.deleteCorpusSetCallCount, 1)
        XCTAssertTrue(repository.librarySnapshot.corpusSets.isEmpty)
        XCTAssertNil(library.selectedCorpusSetID)
        XCTAssertNil(sidebar.selectedCorpusSetID)
        XCTAssertTrue(library.scene.statusMessage.contains("已删除语料集"))
    }

    func testLibraryManagementCoordinatorAppliesBatchMetadataPatchAcrossSelection() async throws {
        let repository = FakeWorkspaceRepository()
        let sessionStore = WorkspaceSessionStore()
        let coordinator = LibraryManagementCoordinator(
            repository: repository,
            dialogService: FakeDialogService(),
            sessionStore: sessionStore
        )
        let library = LibraryManagementViewModel()
        let sidebar = LibrarySidebarViewModel()
        sidebar.applyBootstrap(repository.bootstrapState)
        library.applyBootstrap(repository.bootstrapState.librarySnapshot)
        library.selectCorpusIDs(["corpus-1", "corpus-2"])

        try await coordinator.updateSelectedCorporaMetadata(
            BatchCorpusMetadataPatch(
                sourceLabel: "语料平台",
                genreLabel: "新闻",
                tagsToAdd: ["课堂, 重点"]
            ),
            into: library,
            sidebar: sidebar
        )

        XCTAssertEqual(repository.updateCorpusMetadataCallCount, 2)

        let updatedCorpora = repository.librarySnapshot.corpora
        let corpusOne = try XCTUnwrap(updatedCorpora.first(where: { $0.id == "corpus-1" }))
        let corpusTwo = try XCTUnwrap(updatedCorpora.first(where: { $0.id == "corpus-2" }))

        XCTAssertEqual(corpusOne.metadata.sourceLabel, "语料平台")
        XCTAssertEqual(corpusTwo.metadata.sourceLabel, "语料平台")
        XCTAssertEqual(corpusOne.metadata.genreLabel, "新闻")
        XCTAssertEqual(corpusTwo.metadata.genreLabel, "新闻")
        XCTAssertEqual(corpusOne.metadata.yearLabel, "2024")
        XCTAssertEqual(corpusTwo.metadata.yearLabel, "2023")
        XCTAssertTrue(corpusOne.metadata.tags.contains("课堂"))
        XCTAssertTrue(corpusOne.metadata.tags.contains("重点"))
        XCTAssertTrue(corpusTwo.metadata.tags.contains("研究"))
        XCTAssertTrue(corpusTwo.metadata.tags.contains("重点"))
        XCTAssertTrue(library.scene.statusMessage.contains("已批量更新 2 条语料"))
    }

    func testWorkspaceFlowCoordinatorExportCurrentWritesTokenizedTextAsUTF8() async throws {
        let repository = FakeWorkspaceRepository()
        let dialog = FakeDialogService()
        let exportURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-tokenized-\(UUID().uuidString).txt")
        try? FileManager.default.removeItem(at: exportURL)
        dialog.savePathResult = exportURL.path

        let sceneStore = WorkspaceSceneStore()
        sceneStore.applyAppInfo(repository.bootstrapState.appInfo)
        let sessionStore = WorkspaceSessionStore()
        let libraryCoordinator = LibraryCoordinator(repository: repository, sessionStore: sessionStore)
        let flowCoordinator = makeWorkspaceFlowCoordinator(
            repository: repository,
            workspacePersistence: WorkspacePersistenceService(),
            workspacePresentation: WorkspacePresentationService(),
            sceneStore: sceneStore,
            windowDocumentController: NativeWindowDocumentController(),
            dialogService: dialog,
            sessionStore: sessionStore,
            libraryCoordinator: libraryCoordinator
        )
        let shell = WorkspaceShellViewModel()
        shell.selectedTab = .tokenize
        let tokenize = TokenizePageViewModel()
        tokenize.apply(makeTokenizeResult())
        let features = WorkspaceFeatureSet(
            sidebar: LibrarySidebarViewModel(),
            shell: shell,
            library: LibraryManagementViewModel(),
            stats: StatsPageViewModel(),
            tokenize: tokenize,
            compare: ComparePageViewModel(),
            chiSquare: ChiSquarePageViewModel(),
            ngram: NgramPageViewModel(),
            kwic: KWICPageViewModel(),
            collocate: CollocatePageViewModel(),
            locator: LocatorPageViewModel(),
            settings: WorkspaceSettingsViewModel()
        )

        await flowCoordinator.exportCurrent(features: features)

        let contents = try String(contentsOf: exportURL, encoding: .utf8)
        XCTAssertEqual(contents, "alpha beta gamma\ndelta alpha\n")
        XCTAssertTrue(features.library.scene.statusMessage.contains(exportURL.path))
    }
}
