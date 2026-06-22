import XCTest
@testable import WordZWorkspaceCore

import WordZHost
@MainActor
final class WorkspaceFailurePathTests: XCTestCase {
    func testIssueBannerAppearsWhenBootstrapFails() async {
        let repository = FakeWorkspaceRepository()
        repository.startError = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"])
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()

        XCTAssertEqual(workspace.issueBanner?.title, "分析功能准备失败")
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
        XCTAssertEqual(workspace.taskCenter.scene.failedCount, 0)
        XCTAssertEqual(workspace.taskCenter.scene.cancelledCount, 1)
    }

    func testAPIConnectionCredentialFailureShowsRecoveryWithoutLeakingToken() async {
        let credentialStore = InMemoryAPICredentialStore()
        credentialStore.credential = "token-abc"
        let connectionTester = FakeAPIConnectionTester()
        connectionTester.error = NativeAPIClientError.httpStatus(
            code: 401,
            data: Data("Bearer token-abc".utf8),
            requestID: UUID(),
            retryAfterSeconds: nil
        )
        let workspace = makeMainWorkspaceViewModel(
            repository: FakeWorkspaceRepository(),
            apiCredentialStore: credentialStore,
            apiConnectionTester: connectionTester
        )

        await workspace.initializeIfNeeded()
        await workspace.testAPIConnection()

        XCTAssertEqual(connectionTester.testCallCount, 1)
        XCTAssertEqual(workspace.issueBanner?.title, "API 连接检查失败")
        XCTAssertTrue(workspace.settings.scene.apiCredentialStatus.contains("凭据不可用"))
        XCTAssertTrue(workspace.settings.scene.supportStatus.contains("凭据不可用"))
        XCTAssertFalse(workspace.settings.scene.apiCredentialStatus.contains("token-abc"))
        XCTAssertFalse(workspace.settings.scene.supportStatus.contains("token-abc"))
        XCTAssertFalse(workspace.issueBanner?.message.contains("token-abc") == true)
        XCTAssertEqual(workspace.taskCenter.scene.runningCount, 0)
    }

    func testAPIConnectionRateLimitFailureKeepsLocalAnalysisRecovery() async {
        let connectionTester = FakeAPIConnectionTester()
        connectionTester.error = NativeAPIClientError.httpStatus(
            code: 429,
            data: Data(),
            requestID: UUID(),
            retryAfterSeconds: 12
        )
        let workspace = makeMainWorkspaceViewModel(
            repository: FakeWorkspaceRepository(),
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            apiConnectionTester: connectionTester
        )

        await workspace.initializeIfNeeded()
        await workspace.testAPIConnection()

        XCTAssertEqual(workspace.issueBanner?.title, "API 连接检查失败")
        XCTAssertTrue(workspace.settings.scene.apiCredentialStatus.contains("限流"))
        XCTAssertTrue(workspace.settings.scene.apiCredentialStatus.contains("本地分析仍可使用"))
        XCTAssertEqual(workspace.settings.scene.supportStatus, workspace.settings.scene.apiCredentialStatus)
        XCTAssertEqual(workspace.issueBanner?.message, workspace.settings.scene.apiCredentialStatus)
        XCTAssertEqual(workspace.taskCenter.scene.runningCount, 0)
    }

    func testAPIConnectionOfflineFailureRedactsCredentialAndQueryTokens() async {
        let credentialStore = InMemoryAPICredentialStore()
        credentialStore.credential = "token-abc"
        let connectionTester = FakeAPIConnectionTester()
        connectionTester.error = NativeAPIClientError.transport(
            underlying: NSError(
                domain: NSURLErrorDomain,
                code: URLError.notConnectedToInternet.rawValue,
                userInfo: [
                    NSLocalizedDescriptionKey: "offline Bearer token-abc https://api.example.test/rate_limit?api_key=query-token"
                ]
            ),
            requestID: UUID()
        )
        let workspace = makeMainWorkspaceViewModel(
            repository: FakeWorkspaceRepository(),
            apiCredentialStore: credentialStore,
            apiConnectionTester: connectionTester
        )

        await workspace.initializeIfNeeded()
        await workspace.testAPIConnection()

        XCTAssertEqual(workspace.issueBanner?.title, "API 连接检查失败")
        XCTAssertTrue(workspace.settings.scene.apiCredentialStatus.contains("offline"))
        XCTAssertTrue(workspace.settings.scene.apiCredentialStatus.contains("本地分析仍可使用"))
        XCTAssertFalse(workspace.settings.scene.apiCredentialStatus.contains("token-abc"))
        XCTAssertFalse(workspace.settings.scene.apiCredentialStatus.contains("query-token"))
        XCTAssertTrue(workspace.settings.scene.apiCredentialStatus.contains("api_key=[redacted]"))
        XCTAssertFalse(workspace.settings.scene.supportStatus.contains("token-abc"))
        XCTAssertFalse(workspace.issueBanner?.message.contains("query-token") == true)
        XCTAssertEqual(workspace.taskCenter.scene.runningCount, 0)
    }

    func testCancelledAPIConnectionDoesNotProduceIssueBanner() async {
        let connectionTester = FakeAPIConnectionTester()
        connectionTester.error = CancellationError()
        let workspace = makeMainWorkspaceViewModel(
            repository: FakeWorkspaceRepository(),
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            apiConnectionTester: connectionTester
        )

        await workspace.initializeIfNeeded()
        let failedCountBefore = workspace.taskCenter.scene.failedCount
        await workspace.testAPIConnection()

        XCTAssertNil(workspace.issueBanner)
        XCTAssertEqual(workspace.settings.scene.apiCredentialStatus, "API 连接检查已取消。")
        XCTAssertEqual(workspace.settings.scene.supportStatus, "API 连接检查已取消。")
        XCTAssertEqual(workspace.taskCenter.scene.runningCount, 0)
        XCTAssertEqual(workspace.taskCenter.scene.failedCount, failedCountBefore)
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
