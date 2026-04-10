import XCTest
@testable import WordZMac

@MainActor
final class NativeHostPreferencesStoreTests: XCTestCase {
    func testStoreRoundTripsSnapshotAndRecordsRecentDocuments() throws {
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("WordZMacHostPrefsTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("prefs.json")
        let store = NativeHostPreferencesStore(fileURL: fileURL)

        try store.save(
            NativeHostPreferencesSnapshot(
                languageMode: .bilingual,
                autoUpdateEnabled: false,
                checkForUpdatesOnLaunch: false,
                autoDownloadUpdates: true,
                autoInstallDownloadedUpdates: true,
                recentDocuments: [],
                lastUpdateCheckAt: "",
                lastUpdateStatus: "尚未检查更新。",
                downloadedUpdateVersion: "",
                downloadedUpdateName: "",
                downloadedUpdatePath: "",
                taskHistory: [
                    PersistedNativeBackgroundTaskItem(
                        item: NativeBackgroundTaskItem(
                            id: UUID(),
                            title: "Export",
                            detail: "Done",
                            state: .completed,
                            progress: 1,
                            startedAt: Date(timeIntervalSince1970: 1),
                            updatedAt: Date(timeIntervalSince1970: 2),
                            primaryAction: .openFile(path: "/tmp/demo.csv")
                        )
                    )
                ]
            )
        )

        let recentSnapshot = try store.recordRecentDocument(
            corpusID: "corpus-1",
            title: "Demo Corpus",
            subtitle: "Default",
            representedPath: "/tmp/demo.txt"
        )

        XCTAssertEqual(recentSnapshot.recentDocuments.count, 1)
        XCTAssertEqual(store.load().recentDocuments.first?.corpusID, "corpus-1")
        XCTAssertFalse(store.load().autoUpdateEnabled)
        XCTAssertTrue(store.load().autoInstallDownloadedUpdates)
        XCTAssertEqual(store.load().languageMode, .bilingual)
        XCTAssertEqual(store.load().taskHistory.first?.primaryAction?.action, .openFile(path: "/tmp/demo.csv"))
    }
}
