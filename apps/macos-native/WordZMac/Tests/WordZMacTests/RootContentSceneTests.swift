import XCTest
@testable import WordZMac

@MainActor
final class RootContentSceneTests: XCTestCase {
    func testRootContentSceneBuilderBuildsWindowTitleTabsAndToolbar() {
        let toolbar = WorkspaceToolbarSceneModel(
            items: [
                WorkspaceToolbarActionItem(action: .refresh, title: "刷新", isEnabled: true),
                WorkspaceToolbarActionItem(action: .runKWIC, title: "KWIC", isEnabled: false)
            ]
        )

        let scene = RootContentSceneBuilder().build(
            windowTitle: "Demo Corpus",
            activeTab: .kwic,
            toolbar: toolbar,
            languageMode: .chinese
        )

        XCTAssertEqual(scene.windowTitle, "Demo Corpus")
        XCTAssertEqual(scene.selectedTab, .kwic)
        XCTAssertEqual(scene.tabs.map(\.tab), WorkspaceDetailTab.mainWorkspaceTabs)
        XCTAssertEqual(scene.tabs.first(where: { $0.tab == .stats })?.title, "统计")
        XCTAssertEqual(scene.toolbar.items, toolbar.items)
    }

    func testMainWorkspaceViewModelInitializeSyncsRootScene() async {
        let repository = FakeWorkspaceRepository()
        let workspace = MainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()

        XCTAssertEqual(workspace.rootScene.windowTitle, "WordZ")
        XCTAssertEqual(workspace.rootScene.selectedTab, .kwic)
        XCTAssertEqual(workspace.rootScene.tabs.count, WorkspaceDetailTab.mainWorkspaceTabs.count)
        XCTAssertFalse(workspace.rootScene.tabs.contains(where: { $0.tab == .library }))
        XCTAssertFalse(workspace.rootScene.tabs.contains(where: { $0.tab == .settings }))
        XCTAssertEqual(workspace.rootScene.toolbar.items.count, 17)
        XCTAssertEqual(workspace.rootScene.toolbar.items.first?.action, .refresh)
        XCTAssertEqual(workspace.rootScene.toolbar.items.first(where: { $0.action == .showLibrary })?.isEnabled, true)
        XCTAssertEqual(workspace.rootScene.toolbar.items.first(where: { $0.action == .openSelected })?.isEnabled, true)
        XCTAssertEqual(workspace.rootScene.toolbar.items.first(where: { $0.action == .runWordCloud })?.isEnabled, true)
    }

    func testMainWorkspaceViewModelRootSceneTracksTabAndToolbarUpdates() async {
        let repository = FakeWorkspaceRepository()
        let workspace = MainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.selectedTab = .collocate
        workspace.shell.isBusy = true
        workspace.syncSceneGraph()

        XCTAssertEqual(workspace.rootScene.selectedTab, .collocate)
        XCTAssertEqual(workspace.rootScene.toolbar.items.first(where: { $0.action == .runStats })?.isEnabled, false)
        XCTAssertEqual(workspace.rootScene.toolbar.items.first(where: { $0.action == .runCollocate })?.isEnabled, false)
    }
}
