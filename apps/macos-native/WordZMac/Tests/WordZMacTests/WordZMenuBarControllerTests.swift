import AppKit
import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class WordZMenuBarControllerTests: XCTestCase {
    func testMenuBarControllerTracksVisibilitySetting() async {
        let workspace = makeMainWorkspaceViewModel(repository: FakeWorkspaceRepository())
        let statusHost = FakeMenuBarStatusHost()
        let controller = WordZMenuBarController(
            workspace: workspace,
            localization: WordZLocalization.shared,
            statusHost: statusHost
        )

        controller.start(applicationDelegate: NativeApplicationDelegate())
        XCTAssertTrue(controller.isStatusItemInserted)
        XCTAssertEqual(statusHost.insertCallCount, 1)
        XCTAssertEqual(statusHost.removeCallCount, 0)

        workspace.settings.showMenuBarIcon = false
        await Task.yield()
        XCTAssertFalse(controller.isStatusItemInserted)
        XCTAssertEqual(statusHost.removeCallCount, 1)

        workspace.settings.showMenuBarIcon = true
        await Task.yield()
        XCTAssertTrue(controller.isStatusItemInserted)
        XCTAssertEqual(statusHost.insertCallCount, 2)
    }

    func testMenuBarControllerBuildsWorkspaceTaskAndUpdateMenus() throws {
        let workspace = makeMainWorkspaceViewModel(repository: FakeWorkspaceRepository())
        workspace.settings.applyContext(
            WorkspaceSceneContext(
                appName: "WordZ",
                versionLabel: "v1.2.9",
                workspaceSummary: "Demo Workspace",
                buildSummary: "SwiftUI + Swift native engine",
                help: []
            )
        )
        workspace.sidebar.librarySnapshot = makeBootstrapState().librarySnapshot
        workspace.sidebar.selectedCorpusID = "corpus-1"
        _ = workspace.taskCenter.beginTask(title: "Download Update", detail: "Running", progress: 0.4)
        workspace.settings.applyUpdateState(
            NativeUpdateStateSnapshot(
                currentVersion: "1.2.9",
                latestVersion: "1.3.0",
                releaseURL: "https://example.com/release",
                statusMessage: "发现新版本 1.3.0，可下载更新包。",
                updateAvailable: true,
                isChecking: false,
                isDownloading: false,
                downloadProgress: nil,
                downloadedUpdateVersion: "",
                downloadedUpdateName: "",
                downloadedUpdatePath: "",
                releaseTitle: "WordZ 1.3.0",
                publishedAt: "2026-04-13T00:00:00Z",
                releaseNotes: ["Menu bar is back."],
                assetName: "WordZ-1.3.0-mac-arm64.dmg"
            )
        )

        let statusHost = FakeMenuBarStatusHost()
        let controller = WordZMenuBarController(
            workspace: workspace,
            localization: WordZLocalization.shared,
            statusHost: statusHost
        )

        controller.start(applicationDelegate: NativeApplicationDelegate())
        controller.rebuildMenu()

        let rootMenu = try XCTUnwrap(statusHost.lastInsertedItem?.menu)
        XCTAssertTrue(rootMenu.items.contains(where: { $0.title == "当前工作区：Demo Workspace" }))
        XCTAssertTrue(rootMenu.items.contains(where: { $0.title == "当前语料：Demo Corpus" }))
        XCTAssertTrue(rootMenu.items.contains(where: { $0.title == "工作区" }))
        XCTAssertTrue(rootMenu.items.contains(where: { $0.title == "发现新版本" }))

        let taskMenuItem = try XCTUnwrap(rootMenu.items.first(where: { $0.title == "后台任务 (1)" }))
        let taskMenu = try XCTUnwrap(taskMenuItem.submenu)
        XCTAssertTrue(taskMenu.items.contains(where: { $0.title == "打开任务中心" }))

        let workspaceMenuItem = try XCTUnwrap(rootMenu.items.first(where: { $0.title == "工作区" }))
        let workspaceMenu = try XCTUnwrap(workspaceMenuItem.submenu)
        XCTAssertTrue(workspaceMenu.items.contains(where: { $0.title == "导入语料…" }))
        XCTAssertTrue(workspaceMenu.items.contains(where: { $0.title == "快速预览当前内容" }))

        let updateMenuItem = try XCTUnwrap(rootMenu.items.first(where: { $0.title == "发现新版本" }))
        let updateMenu = try XCTUnwrap(updateMenuItem.submenu)
        XCTAssertTrue(updateMenu.items.contains(where: { $0.title == "下载更新" }))
    }
}

@MainActor
private final class FakeMenuBarStatusHost: WordZMenuBarStatusHosting {
    private(set) var insertCallCount = 0
    private(set) var removeCallCount = 0
    private(set) var lastInsertedItem: FakeMenuBarStatusItem?

    func insertStatusItem() -> any WordZMenuBarStatusPresenting {
        insertCallCount += 1
        let item = FakeMenuBarStatusItem()
        lastInsertedItem = item
        return item
    }

    func removeStatusItem(_ item: any WordZMenuBarStatusPresenting) {
        removeCallCount += 1
    }
}

@MainActor
private final class FakeMenuBarStatusItem: WordZMenuBarStatusPresenting {
    var menu: NSMenu?
    private(set) var image: NSImage?
    private(set) var accessibilityLabel = ""

    func setImage(_ image: NSImage, accessibilityLabel: String) {
        self.image = image
        self.accessibilityLabel = accessibilityLabel
    }
}
