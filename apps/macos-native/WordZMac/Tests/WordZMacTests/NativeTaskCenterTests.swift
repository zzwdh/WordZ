import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class NativeTaskCenterTests: XCTestCase {
    func testSceneTracksAggregateProgressAndHighlightedRunningItems() {
        let center = NativeTaskCenter()
        let first = center.beginTask(title: "Import", detail: "Reading files", progress: 0.25)
        _ = center.beginTask(title: "Topics", detail: "Embedding paragraphs", progress: 0.75)

        XCTAssertEqual(center.scene.runningCount, 2)
        XCTAssertEqual(center.scene.highlightedItems.count, 2)
        XCTAssertEqual(center.scene.highlightedItems.first?.title, "Topics")
        XCTAssertEqual(center.scene.aggregateProgress ?? -1, 0.5, accuracy: 0.0001)

        center.completeTask(id: first, detail: "Import complete")
        XCTAssertEqual(center.scene.runningCount, 1)
        XCTAssertEqual(center.scene.completedCount, 1)
        XCTAssertEqual(center.scene.aggregateProgress ?? -1, 0.75, accuracy: 0.0001)
    }

    func testRestoreHistoryConvertsRunningTasksToFailedAndPreservesActions() {
        let center = NativeTaskCenter()
        center.restoreHistory([
            PersistedNativeBackgroundTaskItem(
                item: NativeBackgroundTaskItem(
                    id: UUID(),
                    title: "Download",
                    detail: "Downloading package",
                    state: .running,
                    progress: 0.4,
                    startedAt: Date(timeIntervalSince1970: 100),
                    updatedAt: Date(timeIntervalSince1970: 200),
                    primaryAction: nil
                )
            ),
            PersistedNativeBackgroundTaskItem(
                item: NativeBackgroundTaskItem(
                    id: UUID(),
                    title: "Export",
                    detail: "Finished",
                    state: .completed,
                    progress: 1,
                    startedAt: Date(timeIntervalSince1970: 10),
                    updatedAt: Date(timeIntervalSince1970: 20),
                    primaryAction: .openFile(path: "/tmp/report.csv")
                )
            )
        ])

        XCTAssertEqual(center.scene.failedCount, 1)
        XCTAssertEqual(center.scene.completedCount, 1)
        XCTAssertTrue(center.scene.items.first?.detail.contains("上次会话已中断") == true)
        XCTAssertEqual(center.scene.items.last?.primaryAction, .openFile(path: "/tmp/report.csv"))
    }

    func testHistoryChangeIsNotEmittedForProgressOnlyUpdates() {
        let center = NativeTaskCenter()
        var emittedHistories: [[PersistedNativeBackgroundTaskItem]] = []
        center.onHistoryChange = { emittedHistories.append($0) }

        let taskID = center.beginTask(title: "Topics", detail: "Preparing", progress: 0)
        XCTAssertEqual(emittedHistories.count, 1)

        center.updateTask(id: taskID, detail: "Embedding", progress: 0.42)
        XCTAssertEqual(emittedHistories.count, 1)

        center.completeTask(id: taskID, detail: "Done")
        XCTAssertEqual(emittedHistories.count, 2)
    }
}
