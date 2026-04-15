import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class NativeHostPreferencesStoreTests: XCTestCase {
    func testStoreRoundTripsSnapshotAndRecordsRecentDocuments() throws {
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("WordZMacHostPrefsTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("prefs.json")
        let store = NativeHostPreferencesStore(fileURL: fileURL)

        try store.save(
            NativeHostPreferencesSnapshot(
                languageMode: .english,
                autoUpdateEnabled: false,
                checkForUpdatesOnLaunch: false,
                autoDownloadUpdates: true,
                autoInstallDownloadedUpdates: true,
                showMenuBarIcon: false,
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
        XCTAssertFalse(store.load().showMenuBarIcon)
        XCTAssertEqual(store.load().languageMode, .system)
        XCTAssertEqual(store.load().taskHistory.first?.primaryAction?.action, .openFile(path: "/tmp/demo.csv"))
    }

    func testLoadMigratesLegacyLanguagePreferenceToSystem() throws {
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("WordZMacHostPrefsLegacyTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("prefs.json")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try """
        {
          "languageMode": "bilingual",
          "autoUpdateEnabled": true,
          "checkForUpdatesOnLaunch": true,
          "autoDownloadUpdates": false,
          "autoInstallDownloadedUpdates": false,
          "recentDocuments": [],
          "lastUpdateCheckAt": "",
          "lastUpdateStatus": "尚未检查更新。",
          "downloadedUpdateVersion": "",
          "downloadedUpdateName": "",
          "downloadedUpdatePath": "",
          "taskHistory": [],
          "hasCompletedInitialLaunch": false
        }
        """.write(to: fileURL, atomically: true, encoding: .utf8)

        let store = NativeHostPreferencesStore(fileURL: fileURL)

        XCTAssertEqual(store.load().languageMode, .system)
        XCTAssertTrue(store.load().showMenuBarIcon)
    }

    func testLoadFillsDefaultUpdateStatusWhenLegacyPayloadOmitsField() throws {
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("WordZMacHostPrefsMissingStatusTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("prefs.json")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try """
        {
          "languageMode": "system",
          "autoUpdateEnabled": true,
          "checkForUpdatesOnLaunch": true,
          "autoDownloadUpdates": false,
          "autoInstallDownloadedUpdates": false,
          "recentDocuments": [],
          "lastUpdateCheckAt": "",
          "downloadedUpdateVersion": "",
          "downloadedUpdateName": "",
          "downloadedUpdatePath": "",
          "taskHistory": [],
          "hasCompletedInitialLaunch": false
        }
        """.write(to: fileURL, atomically: true, encoding: .utf8)

        let store = NativeHostPreferencesStore(fileURL: fileURL)

        XCTAssertEqual(store.load().lastUpdateStatus, NativeHostPreferencesSnapshot.default.lastUpdateStatus)
    }
}
