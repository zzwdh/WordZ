import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class SettingsTests: XCTestCase {
    func testSettingsViewModelAppliesSnapshotAndExportsValues() {
        let viewModel = WorkspaceSettingsViewModel()
        viewModel.applyContext(
            WorkspaceSceneContext(
                appName: "WordZ",
                versionLabel: "v1.1.0",
                workspaceSummary: "工作区：Demo",
                buildSummary: "SwiftUI + Swift native engine",
                help: ["Docs", "Feedback"]
            )
        )
        viewModel.apply(
            UISettingsSnapshot(
                showWelcomeScreen: false,
                restoreWorkspace: false,
                debugLogging: true,
                recentMetadataSourceLabels: ["教材", "期刊"],
                recentCorpusSetIDs: ["set-2", "set-1"]
            )
        )
        viewModel.applyAppInfo(
            AppInfoSummary(json: [
                "name": "WordZ",
                "version": "1.1.0",
                "help": ["Docs", "Feedback"],
                "releaseNotes": ["Added native Word page"],
                "userDataDir": "/tmp/wordzmac"
            ])
        )
        viewModel.applyHostPreferences(
            NativeHostPreferencesSnapshot(
                languageMode: .english,
                autoUpdateEnabled: true,
                checkForUpdatesOnLaunch: true,
                autoDownloadUpdates: false,
                autoInstallDownloadedUpdates: false,
                showMenuBarIcon: false,
                recentDocuments: [
                    RecentDocumentItem(
                        corpusID: "corpus-1",
                        title: "Demo Corpus",
                        subtitle: "Default",
                        representedPath: "/tmp/demo.txt",
                        lastOpenedAt: "2026-03-26T00:00:00Z"
                    )
                ],
                lastUpdateCheckAt: "2026-03-26T00:00:00Z",
                lastUpdateStatus: "已检查更新。",
                downloadedUpdateVersion: "",
                downloadedUpdateName: "",
                downloadedUpdatePath: ""
            )
        )
        viewModel.applyUpdateState(
            NativeUpdateStateSnapshot(
                currentVersion: "1.1.0",
                latestVersion: "1.1.1",
                releaseURL: "https://github.com/zzwdh/WordZ/releases/tag/v1.1.1",
                statusMessage: "发现新版本 1.1.1，可下载更新包。",
                updateAvailable: true,
                isChecking: false,
                isDownloading: false,
                downloadProgress: nil,
                downloadedUpdateVersion: "",
                downloadedUpdateName: "",
                downloadedUpdatePath: "",
                releaseTitle: "WordZ 1.1.1",
                publishedAt: "2026-03-26T00:00:00Z",
                releaseNotes: ["Native tables now persist layout."],
                assetName: "WordZ-1.1.1-mac-arm64.dmg"
            )
        )

        XCTAssertEqual(viewModel.scene.workspaceSummary, "工作区：Demo")
        XCTAssertEqual(viewModel.languageMode, .system)
        XCTAssertEqual(viewModel.scene.help, ["Docs", "Feedback"])
        XCTAssertEqual(viewModel.scene.releaseNotes, ["Added native Word page"])
        XCTAssertEqual(viewModel.scene.latestReleaseNotes, ["Native tables now persist layout."])
        XCTAssertEqual(viewModel.scene.latestReleaseTitle, "WordZ 1.1.1")
        XCTAssertEqual(viewModel.scene.latestAssetName, "WordZ-1.1.1-mac-arm64.dmg")
        XCTAssertEqual(viewModel.scene.recentDocuments.count, 1)
        XCTAssertEqual(viewModel.scene.userDataDirectory, "/tmp/wordzmac")
        XCTAssertFalse(viewModel.showMenuBarIcon)

        let exported = viewModel.exportSnapshot()
        XCTAssertFalse(exported.showWelcomeScreen)
        XCTAssertFalse(exported.restoreWorkspace)
        XCTAssertTrue(exported.debugLogging)
        XCTAssertEqual(exported.recentMetadataSourceLabels, ["教材", "期刊"])
        XCTAssertEqual(exported.recentCorpusSetIDs, ["set-2", "set-1"])

        let exportedHost = viewModel.exportHostPreferences()
        XCTAssertTrue(exportedHost.autoUpdateEnabled)
        XCTAssertFalse(exportedHost.autoInstallDownloadedUpdates)
        XCTAssertEqual(exportedHost.languageMode, .system)
        XCTAssertEqual(exportedHost.recentDocuments.count, 1)
        XCTAssertEqual(exportedHost.lastUpdateStatus, "发现新版本 1.1.1，可下载更新包。")
        XCTAssertFalse(exportedHost.showMenuBarIcon)
    }

    func testSettingsSceneDefaultsRemainStable() {
        XCTAssertEqual(SettingsPaneSceneModel.empty.workspaceSummary, "等待载入本地语料库")
        XCTAssertEqual(SettingsPaneSceneModel.empty.buildSummary, "SwiftUI + Swift native engine")
        XCTAssertEqual(SettingsPaneSceneModel.empty.supportStatus, "准备就绪")
    }

    func testApplyHostPreferencesCanPreserveRuntimeUpdatePolicy() {
        let viewModel = WorkspaceSettingsViewModel()
        viewModel.languageMode = .english
        viewModel.autoUpdateEnabled = true
        viewModel.checkForUpdatesOnLaunch = false
        viewModel.autoDownloadUpdates = true
        viewModel.autoInstallDownloadedUpdates = true

        viewModel.applyHostPreferences(
            NativeHostPreferencesSnapshot(
                languageMode: .system,
                autoUpdateEnabled: true,
                checkForUpdatesOnLaunch: true,
                autoDownloadUpdates: false,
                autoInstallDownloadedUpdates: false,
                showMenuBarIcon: false,
                recentDocuments: [
                    RecentDocumentItem(
                        corpusID: "corpus-1",
                        title: "Demo Corpus",
                        subtitle: "Default",
                        representedPath: "/tmp/demo.txt",
                        lastOpenedAt: "2026-03-26T00:00:00Z"
                    )
                ],
                lastUpdateCheckAt: "2026-03-26T00:00:00Z",
                lastUpdateStatus: "已检查更新。",
                downloadedUpdateVersion: "1.1.1",
                downloadedUpdateName: "WordZ-1.1.1-mac-arm64.dmg",
                downloadedUpdatePath: "/tmp/WordZ-1.1.1-mac-arm64.dmg"
            ),
            preservingRuntimeUpdatePolicy: true
        )

        XCTAssertEqual(viewModel.languageMode, .system)
        XCTAssertTrue(viewModel.autoUpdateEnabled)
        XCTAssertFalse(viewModel.checkForUpdatesOnLaunch)
        XCTAssertTrue(viewModel.autoDownloadUpdates)
        XCTAssertTrue(viewModel.autoInstallDownloadedUpdates)
        XCTAssertFalse(viewModel.showMenuBarIcon)
        XCTAssertEqual(viewModel.scene.recentDocuments.count, 1)
        XCTAssertEqual(viewModel.scene.downloadedUpdateName, "WordZ-1.1.1-mac-arm64.dmg")
    }

    func testUISettingsSnapshotRoundTripsRecentMetadataSources() {
        let snapshot = UISettingsSnapshot(
            showWelcomeScreen: false,
            restoreWorkspace: true,
            debugLogging: true,
            recentMetadataSourceLabels: ["教材", "新闻"],
            recentCorpusSetIDs: ["set-1", "set-2"]
        )

        XCTAssertEqual(UISettingsSnapshot(json: snapshot.asJSONObject()), snapshot)
    }

    func testPersistedUISettingsDecodesMissingRecentMetadataSourcesAsEmpty() throws {
        let data = #"{"showWelcomeScreen":true,"restoreWorkspace":false,"debugLogging":true}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(NativePersistedUISettings.self, from: data)

        XCTAssertEqual(decoded.recentMetadataSourceLabels, [])
        XCTAssertEqual(decoded.uiSettings.recentMetadataSourceLabels, [])
        XCTAssertEqual(decoded.recentCorpusSetIDs, [])
        XCTAssertEqual(decoded.uiSettings.recentCorpusSetIDs, [])
    }

    func testLanguageModeAssignmentsNormalizeToSystem() {
        let viewModel = WorkspaceSettingsViewModel()

        viewModel.languageMode = .english
        XCTAssertEqual(viewModel.languageMode, .system)

        viewModel.languageMode = .chinese
        XCTAssertEqual(viewModel.languageMode, .system)
    }
}
