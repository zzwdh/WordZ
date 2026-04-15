import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class AnalysisStateSupportTests: XCTestCase {
    private final class FakeStateController: AnalysisStateApplying {
        var isApplyingStateFlag = false
    }

    private final class FakeRevisionController: AnalysisSceneBuildRevisionControlling {
        var sceneBuildRevision = 0
    }

    private final class FakeSelectionController: AnalysisSelectedRowControlling {
        var selectedRowID: String?
    }

    private struct FakeRow: Identifiable {
        let id: String
    }

    func testApplyStateChangeTogglesFlagAndTriggersRebuild() {
        let controller = FakeStateController()
        var rebuilt = false

        controller.applyStateChange(rebuildScene: {
            rebuilt = true
        }) {
            XCTAssertTrue(controller.isApplyingStateFlag)
        }

        XCTAssertFalse(controller.isApplyingStateFlag)
        XCTAssertTrue(rebuilt)
    }

    func testSceneBuildRevisionHelpersInvalidateOlderBuilds() {
        let controller = FakeRevisionController()
        let firstRevision = controller.beginSceneBuildPass()
        XCTAssertTrue(controller.isCurrentSceneBuild(firstRevision))

        controller.invalidatePendingSceneBuilds()

        XCTAssertFalse(controller.isCurrentSceneBuild(firstRevision))
        XCTAssertTrue(controller.isCurrentSceneBuild(controller.sceneBuildRevision))
    }

    func testSyncSelectedRowFallsBackToFirstAvailableRow() {
        let controller = FakeSelectionController()
        controller.selectedRowID = "missing"

        controller.syncSelectedRow(within: [
            FakeRow(id: "alpha"),
            FakeRow(id: "beta")
        ])

        XCTAssertEqual(controller.selectedRowID, "alpha")
    }
}
