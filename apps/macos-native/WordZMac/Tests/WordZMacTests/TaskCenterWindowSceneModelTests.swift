import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class TaskCenterWindowSceneModelTests: XCTestCase {
    func testSearchMatchesTitleDetailStateAndActionCaseInsensitively() {
        let scene = makeScene(items: [
            makeItem(
                title: "Download Update",
                detail: "Fetching installer package",
                state: .running,
                progress: 0.5,
                updatedAt: Date(timeIntervalSince1970: 30),
                primaryAction: .cancelTask(id: UUID())
            ),
            makeItem(
                title: "Diagnostics Export",
                detail: "Bundle failed to archive",
                state: .failed,
                progress: nil,
                updatedAt: Date(timeIntervalSince1970: 20),
                primaryAction: .openURL("https://example.com/release")
            ),
            makeItem(
                title: "Report Export",
                detail: "Saved to disk",
                state: .completed,
                progress: 1,
                updatedAt: Date(timeIntervalSince1970: 10),
                primaryAction: .openFile(path: "/tmp/report.csv")
            )
        ], aggregateProgress: 0.5)

        XCTAssertEqual(
            TaskCenterWindowSceneModel(
                taskCenterScene: scene,
                searchQuery: "  download  ",
                languageMode: .english
            ).matchedCount,
            1
        )
        XCTAssertEqual(
            TaskCenterWindowSceneModel(
                taskCenterScene: scene,
                searchQuery: "INSTALLER",
                languageMode: .english
            ).matchedCount,
            1
        )
        XCTAssertEqual(
            TaskCenterWindowSceneModel(
                taskCenterScene: scene,
                searchQuery: "failed",
                languageMode: .english
            ).matchedCount,
            1
        )
        XCTAssertEqual(
            TaskCenterWindowSceneModel(
                taskCenterScene: scene,
                searchQuery: "view details",
                languageMode: .english
            ).matchedCount,
            1
        )
        XCTAssertEqual(
            TaskCenterWindowSceneModel(
                taskCenterScene: scene,
                searchQuery: "open file",
                languageMode: .english
            ).matchedCount,
            1
        )
    }

    func testSectionsStayOrderedAndAggregateProgressDoesNotChangeWhenSearching() {
        let scene = makeScene(items: [
            makeItem(
                title: "Older Import",
                detail: "Queued",
                state: .running,
                progress: 0.25,
                updatedAt: Date(timeIntervalSince1970: 10)
            ),
            makeItem(
                title: "Newest Import",
                detail: "Reading files",
                state: .running,
                progress: 0.75,
                updatedAt: Date(timeIntervalSince1970: 40)
            ),
            makeItem(
                title: "Diagnostics",
                detail: "Could not package logs",
                state: .failed,
                progress: nil,
                updatedAt: Date(timeIntervalSince1970: 30)
            ),
            makeItem(
                title: "Report",
                detail: "Finished",
                state: .completed,
                progress: 1,
                updatedAt: Date(timeIntervalSince1970: 20)
            )
        ], aggregateProgress: 0.5)

        let fullModel = TaskCenterWindowSceneModel(
            taskCenterScene: scene,
            searchQuery: "",
            languageMode: .english
        )
        XCTAssertEqual(fullModel.sections.map(\.state), [.running, .failed, .completed])
        XCTAssertEqual(fullModel.sections.first?.items.map(\.title), ["Newest Import", "Older Import"])

        let filteredModel = TaskCenterWindowSceneModel(
            taskCenterScene: scene,
            searchQuery: "newest",
            languageMode: .english
        )
        XCTAssertEqual(filteredModel.sections.map(\.state), [.running])
        XCTAssertEqual(filteredModel.aggregateProgress ?? -1, 0.5, accuracy: 0.0001)
        XCTAssertEqual(filteredModel.aggregateProgressSummary, "2 running · 50%")
    }

    func testSearchSubtitleReflectsMatchesWithoutChangingTotals() {
        let scene = makeScene(items: [
            makeItem(
                title: "Import",
                detail: "Reading folder",
                state: .running,
                progress: 0.4,
                updatedAt: Date(timeIntervalSince1970: 10)
            ),
            makeItem(
                title: "Export",
                detail: "Finished",
                state: .completed,
                progress: 1,
                updatedAt: Date(timeIntervalSince1970: 5)
            )
        ], aggregateProgress: 0.4)

        let model = TaskCenterWindowSceneModel(
            taskCenterScene: scene,
            searchQuery: "export",
            languageMode: .english
        )

        XCTAssertEqual(model.subtitle, "Showing 1 of 2 · 1 running")
        XCTAssertTrue(model.isSearching)
        XCTAssertTrue(model.hasFinishedItems)
    }

    private func makeScene(
        items: [NativeBackgroundTaskItem],
        aggregateProgress: Double?
    ) -> NativeTaskCenterSceneModel {
        NativeTaskCenterSceneModel(
            items: items,
            runningCount: items.filter { $0.state == .running }.count,
            completedCount: items.filter { $0.state == .completed }.count,
            failedCount: items.filter { $0.state == .failed }.count,
            summary: "Task summary",
            aggregateProgress: aggregateProgress,
            highlightedItems: Array(items.filter { $0.state == .running }.prefix(2))
        )
    }

    private func makeItem(
        title: String,
        detail: String,
        state: NativeBackgroundTaskState,
        progress: Double?,
        updatedAt: Date,
        primaryAction: NativeBackgroundTaskAction? = nil
    ) -> NativeBackgroundTaskItem {
        NativeBackgroundTaskItem(
            id: UUID(),
            title: title,
            detail: detail,
            state: state,
            progress: progress,
            startedAt: updatedAt.addingTimeInterval(-5),
            updatedAt: updatedAt,
            primaryAction: primaryAction
        )
    }
}
