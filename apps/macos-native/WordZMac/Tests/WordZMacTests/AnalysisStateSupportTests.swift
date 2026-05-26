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

    private enum FakeColumn: Hashable {
        case alpha
        case beta
    }

    private enum FakeSortMode: Equatable {
        case alpha
        case beta
    }

    private enum FakePageSize: Equatable, InteractiveAllPageSizing {
        case ten
        case all

        var isAllSelection: Bool { self == .all }
        static var safeInteractiveFallback: FakePageSize { .ten }
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

    func testSelectionOnlyUpdateClassifiesNoOpsAndValidSelectionChanges() {
        let controller = FakeSelectionController()
        controller.selectedRowID = "alpha"
        let rows = [
            FakeRow(id: "alpha"),
            FakeRow(id: "beta")
        ]

        XCTAssertEqual(
            controller.applySelectionOnlyUpdate("alpha", within: rows),
            .none
        )
        XCTAssertEqual(controller.selectedRowID, "alpha")

        XCTAssertEqual(
            controller.applySelectionOnlyUpdate("beta", within: rows),
            .selectionOnly
        )
        XCTAssertEqual(controller.selectedRowID, "beta")

        XCTAssertEqual(
            controller.applySelectionOnlyUpdate("missing", within: rows),
            .selectionOnly
        )
        XCTAssertEqual(controller.selectedRowID, "alpha")
    }

    func testSceneUpdatePlannerClassifiesTableMutationsAsViewportChanges() {
        XCTAssertEqual(AnalysisSceneUpdatePlanner.scope(for: .sort), .tableViewport)
        XCTAssertEqual(AnalysisSceneUpdatePlanner.scope(for: .pageSize), .tableViewport)
        XCTAssertEqual(AnalysisSceneUpdatePlanner.scope(for: .pageNavigation), .tableViewport)
        XCTAssertEqual(AnalysisSceneUpdatePlanner.scope(for: .columnVisibility), .tableViewport)
    }

    func testTablePresentationMutationsResetPagingAndIgnoreNoOps() {
        var state = AnalysisTablePresentationState<FakeColumn, FakeSortMode, FakePageSize>(
            sortMode: .alpha,
            pageSize: .ten,
            currentPage: 3,
            visibleColumns: [.alpha]
        )

        XCTAssertFalse(state.applySortModeChange(.alpha))
        XCTAssertEqual(state.currentPage, 3)

        XCTAssertTrue(state.applySortModeChange(.beta))
        XCTAssertEqual(state.sortMode, .beta)
        XCTAssertEqual(state.currentPage, 1)

        state.currentPage = 4
        XCTAssertFalse(state.applyPageSizeChange(.ten))
        XCTAssertEqual(state.currentPage, 4)

        XCTAssertTrue(state.applyPageSizeChange(.all))
        XCTAssertEqual(state.pageSize, .all)
        XCTAssertEqual(state.currentPage, 1)
    }

    func testTablePresentationKeepsLargeAllSelectionGuardrail() {
        var state = AnalysisTablePresentationState<FakeColumn, FakeSortMode, FakePageSize>(
            sortMode: .alpha,
            pageSize: .all,
            currentPage: 3,
            visibleColumns: [.alpha]
        )

        XCTAssertTrue(state.applyResolvedPageSizeChange(
            .all,
            totalRows: ResultPerformanceGuardrails.maximumInteractiveAllRows + 1
        ))
        XCTAssertEqual(state.pageSize, .ten)
        XCTAssertEqual(state.currentPage, 1)
    }

    func testTablePresentationColumnToggleProtectsLastVisibleColumn() {
        var state = AnalysisTablePresentationState<FakeColumn, FakeSortMode, FakePageSize>(
            sortMode: .alpha,
            pageSize: .ten,
            visibleColumns: [.alpha]
        )

        XCTAssertFalse(state.toggleColumn(.alpha))
        XCTAssertEqual(state.visibleColumns, [.alpha])

        XCTAssertTrue(state.toggleColumn(.beta))
        XCTAssertEqual(state.visibleColumns, [.alpha, .beta])

        XCTAssertTrue(state.toggleColumn(.beta))
        XCTAssertEqual(state.visibleColumns, [.alpha])
    }
}
