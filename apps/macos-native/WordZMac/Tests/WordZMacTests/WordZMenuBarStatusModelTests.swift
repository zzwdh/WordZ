import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class WordZMenuBarStatusModelTests: XCTestCase {
    func testIconStateTracksOnlyMeaningfulTaskAndUpdateTransitions() {
        let model = WordZMenuBarStatusModel()

        XCTAssertEqual(model.iconState, .idle)

        model.applyTaskCenterScene(
            NativeTaskCenterSceneModel(
                items: [],
                runningCount: 1,
                completedCount: 0,
                failedCount: 0,
                summary: "1 running",
                aggregateProgress: 0.1,
                highlightedItems: []
            )
        )
        XCTAssertEqual(model.iconState, .tasksRunning)

        model.applyTaskCenterScene(
            NativeTaskCenterSceneModel(
                items: [],
                runningCount: 1,
                completedCount: 0,
                failedCount: 0,
                summary: "1 running, 80%",
                aggregateProgress: 0.8,
                highlightedItems: []
            )
        )
        XCTAssertEqual(model.iconState, .tasksRunning)

        model.applyUpdateState(
            NativeUpdateStateSnapshot(
                currentVersion: "1.2.9",
                latestVersion: "1.3.0",
                releaseURL: "https://example.com/release",
                statusMessage: "Downloaded update",
                updateAvailable: true,
                isChecking: false,
                isDownloading: false,
                downloadProgress: nil,
                downloadedUpdateVersion: "1.3.0",
                downloadedUpdateName: "WordZ.pkg",
                downloadedUpdatePath: "/tmp/WordZ.pkg",
                releaseTitle: "WordZ 1.3.0",
                publishedAt: "",
                releaseNotes: [],
                assetName: "WordZ.pkg"
            )
        )
        XCTAssertEqual(model.iconState, .updateReady)

        model.applyTaskCenterScene(.empty)
        XCTAssertEqual(model.iconState, .updateReady)

        model.applyUpdateState(.empty)
        XCTAssertEqual(model.iconState, .idle)
    }
}
