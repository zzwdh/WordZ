import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class WordZMenuBarStatusModelTests: XCTestCase {
    func testIconStateTracksUpdateTransitions() {
        let model = WordZMenuBarStatusModel()

        XCTAssertEqual(model.iconState, .idle)

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

        model.applyUpdateState(.empty)
        XCTAssertEqual(model.iconState, .idle)
    }
}
