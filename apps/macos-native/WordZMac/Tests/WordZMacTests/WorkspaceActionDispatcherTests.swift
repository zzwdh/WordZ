import XCTest
@testable import WordZMac

@MainActor
final class WorkspaceActionDispatcherTests: XCTestCase {
    func testDispatcherRefreshActionRunsWorkspaceRefreshFlow() async {
        let repository = FakeWorkspaceRepository()
        let workspace = MainWorkspaceViewModel(repository: repository)
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleToolbarAction(.refresh)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.loadBootstrapStateCallCount, 1)
        XCTAssertEqual(workspace.sceneGraph.context.appName, "WordZ")
    }

    func testDispatcherStatsLocalActionResyncsSceneGraph() {
        let repository = FakeWorkspaceRepository()
        let workspace = MainWorkspaceViewModel(repository: repository)
        workspace.stats.apply(makeStatsResult(rowCount: 5))
        workspace.syncSceneGraph()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        XCTAssertTrue(workspace.sceneGraph.stats.table.isVisible("count"))

        dispatcher.handleStatsAction(.toggleColumn(.count))

        XCTAssertFalse(workspace.sceneGraph.stats.table.isVisible("count"))
    }

    func testDispatcherCompareLocalActionResyncsSceneGraph() {
        let repository = FakeWorkspaceRepository()
        let workspace = MainWorkspaceViewModel(repository: repository)
        workspace.sidebar.applyBootstrap(repository.bootstrapState)
        workspace.compare.syncLibrarySnapshot(repository.bootstrapState.librarySnapshot)
        workspace.compare.apply(makeCompareResult())
        workspace.syncSceneGraph()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        XCTAssertTrue(workspace.sceneGraph.compare.table.isVisible("distribution"))

        dispatcher.handleCompareAction(.toggleColumn(.distribution))

        XCTAssertFalse(workspace.sceneGraph.compare.table.isVisible("distribution"))
    }

    func testDispatcherChiSquareResetResyncsSceneGraph() {
        let repository = FakeWorkspaceRepository()
        let workspace = MainWorkspaceViewModel(repository: repository)
        workspace.chiSquare.apply(makeChiSquareResult())
        workspace.syncSceneGraph()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        XCTAssertTrue(workspace.sceneGraph.chiSquare.hasResult)

        dispatcher.handleChiSquareAction(.reset)

        XCTAssertFalse(workspace.sceneGraph.chiSquare.hasResult)
    }

    func testDispatcherKWICLocalActionResyncsSceneGraph() {
        let repository = FakeWorkspaceRepository()
        let workspace = MainWorkspaceViewModel(repository: repository)
        workspace.kwic.keyword = "node"
        workspace.kwic.apply(makeKWICResult(rowCount: 5))
        workspace.syncSceneGraph()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        XCTAssertTrue(workspace.sceneGraph.kwic.table.isVisible("leftContext"))

        dispatcher.handleKWICAction(.toggleColumn(.leftContext))

        XCTAssertFalse(workspace.sceneGraph.kwic.table.isVisible("leftContext"))
    }

    func testDispatcherKwicActivationRunsLocatorFromSelectedRow() async {
        let repository = FakeWorkspaceRepository()
        let workspace = MainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        workspace.kwic.keyword = "node"
        workspace.kwic.apply(makeKWICResult(rowCount: 3))
        workspace.syncLocatorSourceFromKWIC()
        workspace.syncSceneGraph()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleKWICAction(.activateRow("1-2"))
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.runLocatorCallCount, 1)
        XCTAssertEqual(repository.lastRunLocatorSentenceId, 1)
        XCTAssertEqual(repository.lastRunLocatorNodeIndex, 2)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .locator)
    }

    func testDispatcherNgramLocalActionResyncsSceneGraph() {
        let repository = FakeWorkspaceRepository()
        let workspace = MainWorkspaceViewModel(repository: repository)
        workspace.ngram.apply(makeNgramResult(rowCount: 5))
        workspace.syncSceneGraph()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        XCTAssertTrue(workspace.sceneGraph.ngram.table.isVisible("count"))

        dispatcher.handleNgramAction(.toggleColumn(.count))

        XCTAssertFalse(workspace.sceneGraph.ngram.table.isVisible("count"))
    }

    func testDispatcherCollocateLocalActionResyncsSceneGraph() {
        let repository = FakeWorkspaceRepository()
        let workspace = MainWorkspaceViewModel(repository: repository)
        workspace.collocate.keyword = "node"
        workspace.collocate.apply(makeCollocateResult(rowCount: 5))
        workspace.syncSceneGraph()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        XCTAssertTrue(workspace.sceneGraph.collocate.table.isVisible("rate"))

        dispatcher.handleCollocateAction(.toggleColumn(.rate))

        XCTAssertFalse(workspace.sceneGraph.collocate.table.isVisible("rate"))
    }

    func testDispatcherLocatorLocalActionResyncsSceneGraph() {
        let repository = FakeWorkspaceRepository()
        let workspace = MainWorkspaceViewModel(repository: repository)
        workspace.kwic.keyword = "node"
        workspace.kwic.apply(makeKWICResult(rowCount: 5))
        let source = workspace.kwic.primaryLocatorSource ?? LocatorSource(keyword: "node", sentenceId: 1, nodeIndex: 2)
        workspace.locator.apply(makeLocatorResult(rowCount: 5), source: source)
        workspace.syncSceneGraph()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        XCTAssertTrue(workspace.sceneGraph.locator.table.isVisible("status"))

        dispatcher.handleLocatorAction(.toggleColumn(.status))

        XCTAssertFalse(workspace.sceneGraph.locator.table.isVisible("status"))
    }

    func testDispatcherLibrarySelectionActionsSyncSidebarAndOpenFlow() async {
        let repository = FakeWorkspaceRepository()
        let workspace = MainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleLibraryAction(.selectRecycleEntry("recycle-1"))
        XCTAssertNil(workspace.sidebar.selectedCorpusID)
        XCTAssertEqual(workspace.library.scene.selectedRecycleEntryID, "recycle-1")

        dispatcher.handleLibraryAction(.selectCorpus("corpus-2"))
        dispatcher.handleLibraryAction(.openSelectedCorpus)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(workspace.sidebar.selectedCorpusID, "corpus-2")
        XCTAssertEqual(repository.openSavedCorpusCallCount, 1)
    }

    func testDispatcherSettingsSavePersistsSnapshot() async {
        let repository = FakeWorkspaceRepository()
        let workspace = MainWorkspaceViewModel(repository: repository)
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)
        workspace.settings.zoom = 125
        workspace.settings.fontScale = 110
        workspace.settings.restoreWorkspace = false

        dispatcher.handleSettingsAction(.save)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.savedUISettings.count, 1)
        XCTAssertEqual(repository.savedUISettings.first?.zoom, 125)
        XCTAssertEqual(repository.savedUISettings.first?.fontScale, 110)
        XCTAssertEqual(repository.savedUISettings.first?.restoreWorkspace, false)
    }
}
