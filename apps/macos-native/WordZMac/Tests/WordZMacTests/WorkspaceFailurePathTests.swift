import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class WorkspaceFailurePathTests: XCTestCase {
    func testCreateGroupAndAssignEvidenceItemSkipsMutationWhenPromptIsCancelled() async throws {
        let dialogService = FakeDialogService()
        dialogService.promptTextResult = nil

        let repository = FakeWorkspaceRepository()
        let dragged = makeEvidenceItem(
            id: "evidence-unsectioned-1",
            sourceKind: .kwic,
            reviewStatus: .keep,
            sectionTitle: nil
        )
        repository.evidenceItems = [dragged]
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()
        workspace.evidenceWorkbench.reviewFilter = .keep
        workspace.evidenceWorkbench.groupingMode = .section

        await workspace.createGroupAndAssignEvidenceItem(
            dragged.id,
            preferredWindowRoute: .evidenceWorkbench
        )

        XCTAssertEqual(repository.replaceEvidenceItemsCallCount, 0)
        XCTAssertNil(repository.evidenceItems.first?.sectionTitle)
        XCTAssertEqual(dialogService.promptTextPreferredRoute, .evidenceWorkbench)
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
        XCTAssertEqual(workspace.taskCenter.scene.runningCount, 0)
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
        XCTAssertEqual(workspace.taskCenter.scene.runningCount, 0)
    }

    func testRunTopicsFailureClearsRunningTaskAndPreservesCurrentTab() async {
        let repository = FakeWorkspaceRepository()
        repository.topicsError = NSError(
            domain: "Test",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "topic-down"]
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.selectedTab = .word
        workspace.topics.query = "alpha"

        await workspace.runTopics()

        XCTAssertEqual(repository.runTopicsCallCount, 1)
        XCTAssertEqual(workspace.selectedTab, .word)
        XCTAssertEqual(workspace.sidebar.scene.errorMessage, "topic-down")
        XCTAssertFalse(workspace.sceneGraph.topics.hasResult)
        XCTAssertEqual(workspace.taskCenter.scene.runningCount, 0)
    }

    func testOpenTopicsSentimentWithoutTopicsRowsLeavesCurrentTabAndShowsError() async {
        let workspace = makeMainWorkspaceViewModel(repository: FakeWorkspaceRepository())

        await workspace.initializeIfNeeded()
        workspace.selectedTab = .topics
        workspace.syncSceneGraph()

        await workspace.openTopicsSentiment(scope: .visibleTopics)

        XCTAssertEqual(workspace.selectedTab, .topics)
        XCTAssertEqual(workspace.sidebar.scene.errorMessage, "请先生成 Topics 结果。")
        XCTAssertEqual(workspace.taskCenter.scene.runningCount, 0)
    }

    func testDownloadLatestUpdateFailureProducesIssueBannerAndClearsRunningTask() async {
        let repository = FakeWorkspaceRepository()
        let updateService = FakeUpdateService()
        updateService.downloadError = NSError(
            domain: "Test",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "download-offline"]
        )
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            updateService: updateService
        )

        await workspace.initializeIfNeeded()
        await workspace.checkForUpdatesNow()
        await workspace.downloadLatestUpdate()

        XCTAssertEqual(updateService.checkCallCount, 1)
        XCTAssertEqual(updateService.downloadCallCount, 1)
        XCTAssertEqual(workspace.issueBanner?.title, "下载更新失败")
        XCTAssertTrue(workspace.issueBanner?.message.contains("download-offline") == true)
        XCTAssertEqual(workspace.taskCenter.scene.runningCount, 0)
    }
}
