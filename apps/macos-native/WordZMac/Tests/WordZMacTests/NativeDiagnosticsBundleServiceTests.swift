import XCTest
@testable import WordZWorkspaceCore

final class NativeDiagnosticsBundleServiceTests: XCTestCase {
    func testBuildBundleWritesArchiveWithRuntimeAndPersistedState() throws {
        let fileManager = FileManager.default
        let tempRoot = fileManager.temporaryDirectory.appendingPathComponent("WordZMacDiagnosticsTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempRoot) }

        let persistedWorkspaceURL = tempRoot.appendingPathComponent("workspace-snapshot.json")
        let startupLogURL = tempRoot.appendingPathComponent("wordz-startup-crash.log")
        try Data("{\"currentTab\":\"stats\"}".utf8).write(to: persistedWorkspaceURL)
        try Data("startup failed".utf8).write(to: startupLogURL)

        let persistedTaskItem = PersistedNativeBackgroundTaskItem(
            item: NativeBackgroundTaskItem(
                id: UUID(),
                title: "Export Diagnostics Bundle",
                detail: "Completed",
                state: NativeBackgroundTaskState.completed,
                progress: 1,
                startedAt: Date(timeIntervalSince1970: 1),
                updatedAt: Date(timeIntervalSince1970: 2),
                primaryAction: .openFile(path: "/tmp/report.zip")
            )
        )

        let service = NativeDiagnosticsBundleService(temporaryRootURL: tempRoot)
        let payload = NativeDiagnosticsBundlePayload(
            bundleBaseName: "WordZMac-diagnostics-test",
            reportText: "WordZMac Diagnostics\nBundle Identifier: com.zzwdh.wordz.native",
            buildMetadata: NativeBuildMetadata(
                appName: "WordZ",
                bundleIdentifier: "com.zzwdh.wordz.native",
                version: "1.2.0",
                buildNumber: "20260403160000",
                architecture: "arm64",
                builtAt: "2026-04-03T16:00:00Z",
                gitCommit: "abcdef1234567890",
                gitBranch: "codex/p2",
                distributionChannel: "release",
                executableSHA256: "deadbeef",
                bundlePath: "/Applications/WordZ.app",
                executablePath: "/Applications/WordZ.app/Contents/MacOS/WordZMac",
                sourceLabel: "WordZMacBuildInfo.json"
            ),
            context: NativeDiagnosticsBundleContext(
                generatedAt: "2026-04-03T16:01:00Z",
                appName: "WordZ",
                versionLabel: "1.2.0",
                buildSummary: "SwiftUI + Swift native engine · arm64",
                workspaceSummary: "工作区：Demo",
                activeTab: "stats",
                selectedFolderName: "全部",
                selectedCorpusName: "Demo Corpus",
                engineEntryPath: "/engine/index.mjs",
                runtimeWorkingDirectory: tempRoot.path,
                userDataDirectory: tempRoot.path,
                taskCenterSummary: "No background tasks right now.",
                runningTaskCount: 0,
                persistedTaskCount: 1
            ),
            hostPreferences: NativeHostPreferencesSnapshot(
                languageMode: .system,
                autoUpdateEnabled: true,
                checkForUpdatesOnLaunch: true,
                autoDownloadUpdates: false,
                autoInstallDownloadedUpdates: false,
                recentDocuments: [
                    RecentDocumentItem(
                        corpusID: "corpus-1",
                        title: "Demo Corpus",
                        subtitle: "教学",
                        representedPath: "/tmp/demo.txt",
                        lastOpenedAt: "2026-04-03T15:58:00Z"
                    )
                ],
                lastUpdateCheckAt: "2026-04-03T15:59:00Z",
                lastUpdateStatus: "发现新版本。",
                downloadedUpdateVersion: "",
                downloadedUpdateName: "",
                downloadedUpdatePath: "",
                taskHistory: [persistedTaskItem]
            ),
            taskHistory: [persistedTaskItem],
            workspaceDraft: WorkspaceStateDraft.empty,
            uiSettings: UISettingsSnapshot(showWelcomeScreen: true, restoreWorkspace: true, debugLogging: true),
            generatedFiles: [
                NativeDiagnosticsBundleGeneratedFile(
                    data: Data("{\"downloadedUpdatePath\":\"<redacted>/WordZ.dmg\"}".utf8),
                    relativePath: "persisted/native-host-preferences.json",
                    description: "Sanitized persisted host preferences."
                ),
                NativeDiagnosticsBundleGeneratedFile(
                    data: Data("{\"librarySchemaVersion\":2,\"pendingShardMigrationCount\":1}".utf8),
                    relativePath: "storage-snapshot.json",
                    description: "Current local storage topology and migration summary."
                )
            ],
            extraFiles: [
                NativeDiagnosticsBundleSourceFile(
                    sourceURL: persistedWorkspaceURL,
                    relativePath: "persisted/workspace-snapshot.json",
                    description: "Persisted workspace snapshot."
                ),
                NativeDiagnosticsBundleSourceFile(
                    sourceURL: startupLogURL,
                    relativePath: "logs/startup-crash.log",
                    description: "Startup crash log."
                )
            ]
        )

        let artifact = try service.buildBundle(payload: payload)
        defer { service.cleanup(artifact) }

        XCTAssertTrue(fileManager.fileExists(atPath: artifact.archiveURL.path))

        let extractDirectoryURL = tempRoot.appendingPathComponent("extracted", isDirectory: true)
        try fileManager.createDirectory(at: extractDirectoryURL, withIntermediateDirectories: true)
        try unzip(archiveURL: artifact.archiveURL, destinationURL: extractDirectoryURL)

        let bundleDirectoryURL = extractDirectoryURL.appendingPathComponent("WordZMac-diagnostics-test", isDirectory: true)
        XCTAssertTrue(fileManager.fileExists(atPath: bundleDirectoryURL.appendingPathComponent("diagnostics.txt").path))
        XCTAssertTrue(fileManager.fileExists(atPath: bundleDirectoryURL.appendingPathComponent("build-metadata.json").path))
        XCTAssertTrue(fileManager.fileExists(atPath: bundleDirectoryURL.appendingPathComponent("workspace-snapshot.json").path))
        XCTAssertTrue(fileManager.fileExists(atPath: bundleDirectoryURL.appendingPathComponent("ui-settings.json").path))
        XCTAssertTrue(fileManager.fileExists(atPath: bundleDirectoryURL.appendingPathComponent("host-preferences.json").path))
        XCTAssertTrue(fileManager.fileExists(atPath: bundleDirectoryURL.appendingPathComponent("task-history.json").path))
        XCTAssertTrue(fileManager.fileExists(atPath: bundleDirectoryURL.appendingPathComponent("runtime-context.json").path))
        XCTAssertTrue(fileManager.fileExists(atPath: bundleDirectoryURL.appendingPathComponent("persisted/workspace-snapshot.json").path))
        XCTAssertTrue(fileManager.fileExists(atPath: bundleDirectoryURL.appendingPathComponent("persisted/native-host-preferences.json").path))
        XCTAssertTrue(fileManager.fileExists(atPath: bundleDirectoryURL.appendingPathComponent("storage-snapshot.json").path))
        XCTAssertTrue(fileManager.fileExists(atPath: bundleDirectoryURL.appendingPathComponent("logs/startup-crash.log").path))
        let persistedHostPreferencesData = try Data(contentsOf: bundleDirectoryURL.appendingPathComponent("persisted/native-host-preferences.json"))
        XCTAssertTrue(String(decoding: persistedHostPreferencesData, as: UTF8.self).contains("<redacted>/WordZ.dmg"))

        let manifestData = try Data(contentsOf: bundleDirectoryURL.appendingPathComponent("manifest.json"))
        let manifestObject = try XCTUnwrap(JSONSerialization.jsonObject(with: manifestData) as? [String: Any])
        let includedFiles = try XCTUnwrap(manifestObject["includedFiles"] as? [[String: Any]])
        let includedPaths = includedFiles.compactMap { $0["path"] as? String }
        XCTAssertTrue(includedPaths.contains("diagnostics.txt"))
        XCTAssertTrue(includedPaths.contains("persisted/native-host-preferences.json"))
        XCTAssertTrue(includedPaths.contains("persisted/workspace-snapshot.json"))
        XCTAssertTrue(includedPaths.contains("storage-snapshot.json"))
        XCTAssertTrue(includedPaths.contains("logs/startup-crash.log"))
    }

    private func unzip(archiveURL: URL, destinationURL: URL) throws {
        let process = Process()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archiveURL.path, destinationURL.path]
        process.standardOutput = Pipe()
        process.standardError = stderrPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            XCTFail("Failed to unzip diagnostics bundle: \(stderr)")
            return
        }
    }
}
