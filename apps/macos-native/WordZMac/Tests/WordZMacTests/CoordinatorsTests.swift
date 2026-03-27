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
        let flowCoordinator = WorkspaceFlowCoordinator(
            repository: repository,
            workspacePersistence: WorkspacePersistenceService(),
            workspacePresentation: WorkspacePresentationService(),
            sceneStore: sceneStore,
            windowDocumentController: NativeWindowDocumentController(),
            dialogService: FakeDialogService(),
            sessionStore: sessionStore,
            libraryCoordinator: libraryCoordinator
        )
        let appCoordinator = AppCoordinator(
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
            wordCloud: WordCloudPageViewModel(),
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
        let flowCoordinator = WorkspaceFlowCoordinator(
            repository: repository,
            workspacePersistence: WorkspacePersistenceService(),
            workspacePresentation: WorkspacePresentationService(),
            sceneStore: sceneStore,
            windowDocumentController: NativeWindowDocumentController(),
            dialogService: FakeDialogService(),
            sessionStore: sessionStore,
            libraryCoordinator: libraryCoordinator
        )
        let appCoordinator = AppCoordinator(
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
            wordCloud: WordCloudPageViewModel(),
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
        let flowCoordinator = WorkspaceFlowCoordinator(
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
            wordCloud: WordCloudPageViewModel(),
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
    }

    func testWorkspaceFlowCoordinatorRunCompareBuildsSceneAndSwitchesTab() async {
        let repository = FakeWorkspaceRepository()
        let sceneStore = WorkspaceSceneStore()
        sceneStore.applyAppInfo(repository.bootstrapState.appInfo)
        let sessionStore = WorkspaceSessionStore()
        sessionStore.applyBootstrap(snapshot: repository.bootstrapState.workspaceSnapshot)
        let libraryCoordinator = LibraryCoordinator(repository: repository, sessionStore: sessionStore)
        let flowCoordinator = WorkspaceFlowCoordinator(
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
            wordCloud: WordCloudPageViewModel(),
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

    func testWorkspaceFlowCoordinatorRunChiSquareBuildsSceneAndSwitchesTab() async {
        let repository = FakeWorkspaceRepository()
        let sceneStore = WorkspaceSceneStore()
        sceneStore.applyAppInfo(repository.bootstrapState.appInfo)
        let sessionStore = WorkspaceSessionStore()
        let libraryCoordinator = LibraryCoordinator(repository: repository, sessionStore: sessionStore)
        let flowCoordinator = WorkspaceFlowCoordinator(
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
            wordCloud: WordCloudPageViewModel(),
            kwic: KWICPageViewModel(),
            collocate: CollocatePageViewModel(),
            locator: LocatorPageViewModel(),
            settings: WorkspaceSettingsViewModel()
        )

        await flowCoordinator.runChiSquare(features: features)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.runChiSquareCallCount, 1)
        XCTAssertEqual(features.shell.selectedTab, .chiSquare)
        XCTAssertEqual(features.chiSquare.scene?.metrics.count, 4)
    }

    func testWorkspaceFlowCoordinatorRunNgramBuildsSceneAndSwitchesTab() async {
        let repository = FakeWorkspaceRepository()
        let sceneStore = WorkspaceSceneStore()
        sceneStore.applyAppInfo(repository.bootstrapState.appInfo)
        let sessionStore = WorkspaceSessionStore()
        sessionStore.applyBootstrap(snapshot: repository.bootstrapState.workspaceSnapshot)
        let libraryCoordinator = LibraryCoordinator(repository: repository, sessionStore: sessionStore)
        let flowCoordinator = WorkspaceFlowCoordinator(
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
            wordCloud: WordCloudPageViewModel(),
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

    func testWorkspaceFlowCoordinatorRunWordCloudBuildsSceneAndSwitchesTab() async {
        let repository = FakeWorkspaceRepository()
        let sceneStore = WorkspaceSceneStore()
        sceneStore.applyAppInfo(repository.bootstrapState.appInfo)
        let sessionStore = WorkspaceSessionStore()
        sessionStore.applyBootstrap(snapshot: repository.bootstrapState.workspaceSnapshot)
        let libraryCoordinator = LibraryCoordinator(repository: repository, sessionStore: sessionStore)
        let flowCoordinator = WorkspaceFlowCoordinator(
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
            wordCloud: WordCloudPageViewModel(),
            kwic: KWICPageViewModel(),
            collocate: CollocatePageViewModel(),
            locator: LocatorPageViewModel(),
            settings: WorkspaceSettingsViewModel()
        )

        await flowCoordinator.runWordCloud(features: features)

        XCTAssertEqual(repository.runWordCloudCallCount, 1)
        XCTAssertEqual(features.shell.selectedTab, .wordCloud)
        XCTAssertEqual(features.wordCloud.scene?.visibleRows, repository.wordCloudResult.rows.count)
    }

    func testWorkspaceFlowCoordinatorRunLocatorUsesKwicSourceAndBuildsScene() async {
        let repository = FakeWorkspaceRepository()
        let sceneStore = WorkspaceSceneStore()
        sceneStore.applyAppInfo(repository.bootstrapState.appInfo)
        let sessionStore = WorkspaceSessionStore()
        sessionStore.applyBootstrap(snapshot: repository.bootstrapState.workspaceSnapshot)
        let libraryCoordinator = LibraryCoordinator(repository: repository, sessionStore: sessionStore)
        let flowCoordinator = WorkspaceFlowCoordinator(
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
            wordCloud: WordCloudPageViewModel(),
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
}
