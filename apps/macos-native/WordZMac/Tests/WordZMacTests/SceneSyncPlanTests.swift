import XCTest
@testable import WordZMac

final class SceneSyncPlanTests: XCTestCase {
    func testSceneSyncPlanMergeCollapsesNavigationIntoLibrarySelection() {
        let merged = SceneSyncSource.navigation.plan.merged(with: SceneSyncSource.librarySelection.plan)

        XCTAssertEqual(merged.mutations, [.librarySelection])
        XCTAssertTrue(merged.syncWorkflowLibraryState)
        XCTAssertTrue(merged.refreshChromeState)
        XCTAssertTrue(merged.rebuildRootScene)
        XCTAssertFalse(merged.rebuildWelcomeScene)
    }

    func testSceneSyncPlanMergePreservesIndependentMutations() {
        let merged = SceneSyncSource.settings.plan.merged(with: SceneSyncSource.resultContent.plan)

        XCTAssertEqual(merged.mutations, [.resultContent, .settings])
        XCTAssertFalse(merged.syncWorkflowLibraryState)
        XCTAssertTrue(merged.refreshChromeState)
        XCTAssertTrue(merged.rebuildRootScene)
        XCTAssertTrue(merged.rebuildWelcomeScene)
    }

    func testSceneSyncRequestMergeUsesLatestResultTabWhenResultContentRemainsPresent() {
        let initial = SceneSyncRequest(
            plan: SceneSyncSource.resultContent.plan,
            resultTab: .stats
        )
        let merged = initial.merged(with: SceneSyncRequest(
            plan: SceneSyncSource.resultContent.plan,
            resultTab: .kwic
        ))

        XCTAssertEqual(merged.resultTab, .kwic)
        XCTAssertEqual(merged.plan.mutations, [.resultContent])
    }

    func testSceneSyncPlanMergeCollapsesToFullMutation() {
        let merged = SceneSyncSource.resultContent.plan.merged(with: SceneSyncSource.full.plan)

        XCTAssertEqual(merged.mutations, [.full])
        XCTAssertTrue(merged.syncWorkflowLibraryState)
        XCTAssertTrue(merged.refreshChromeState)
        XCTAssertTrue(merged.rebuildRootScene)
        XCTAssertTrue(merged.rebuildWelcomeScene)
    }
}
