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

    func testSceneBuildSchedulingCancelsPreviousOwnerTaskBeforeApply() {
        let controller = FakeRevisionController()
        var appliedValues: [String] = []
        let secondApplied = expectation(description: "second scene applied")
        let settled = expectation(description: "scheduler settled")

        let firstRevision = controller.beginSceneBuildPass()
        AnalysisSceneBuildScheduling.schedule(
            owner: controller,
            context: .init(page: "test", rowCount: 1, revision: firstRevision, isAsync: true),
            build: {
                Thread.sleep(forTimeInterval: 0.15)
                try Task.checkCancellation()
                return "first"
            },
            apply: { value in
                appliedValues.append(value)
                return true
            }
        )

        let secondRevision = controller.beginSceneBuildPass()
        AnalysisSceneBuildScheduling.schedule(
            owner: controller,
            context: .init(page: "test", rowCount: 1, revision: secondRevision, isAsync: true),
            build: {
                "second"
            },
            apply: { value in
                appliedValues.append(value)
                if value == "second" {
                    secondApplied.fulfill()
                }
                return true
            }
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            settled.fulfill()
        }

        wait(for: [secondApplied, settled], timeout: 1.0)
        XCTAssertEqual(appliedValues, ["second"])
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
