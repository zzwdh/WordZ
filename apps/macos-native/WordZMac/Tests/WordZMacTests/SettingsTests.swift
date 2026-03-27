import XCTest
@testable import WordZMac

@MainActor
final class SettingsTests: XCTestCase {
    func testSettingsViewModelAppliesSnapshotAndExportsValues() {
        let viewModel = WorkspaceSettingsViewModel()
        viewModel.applyContext(
            WorkspaceSceneContext(
                appName: "WordZ",
                versionLabel: "v1.0.21",
                workspaceSummary: "工作区：Demo",
                buildSummary: "SwiftUI + Swift native engine",
                help: ["Docs", "Feedback"]
            )
        )
        viewModel.apply(
            UISettingsSnapshot(
                zoom: 135,
                fontScale: 120,
                fontFamily: "SF Mono",
                showWelcomeScreen: false,
                restoreWorkspace: false,
                debugLogging: true
            )
        )
        viewModel.applyAppInfo(
            AppInfoSummary(json: [
                "name": "WordZ",
                "version": "1.0.21",
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
                currentVersion: "1.0.21",
                latestVersion: "1.0.22",
                releaseURL: "https://github.com/zzwdh/WordZ/releases/tag/v1.0.22",
                statusMessage: "发现新版本 1.0.22，可下载更新包。",
                updateAvailable: true,
                isChecking: false,
                isDownloading: false,
                downloadProgress: nil,
                downloadedUpdateVersion: "",
                downloadedUpdateName: "",
                downloadedUpdatePath: "",
                releaseTitle: "WordZ 1.0.22",
                publishedAt: "2026-03-26T00:00:00Z",
                releaseNotes: ["Native tables now persist layout."],
                assetName: "WordZ-1.0.22-mac-arm64.dmg"
            )
        )

        XCTAssertEqual(viewModel.scene.workspaceSummary, "工作区：Demo")
        XCTAssertEqual(viewModel.languageMode, .english)
        XCTAssertEqual(viewModel.scene.zoomLabel, "135%")
        XCTAssertEqual(viewModel.scene.fontScaleLabel, "120%")
        XCTAssertEqual(viewModel.scene.help, ["Docs", "Feedback"])
        XCTAssertEqual(viewModel.scene.releaseNotes, ["Added native Word page"])
        XCTAssertEqual(viewModel.scene.latestReleaseNotes, ["Native tables now persist layout."])
        XCTAssertEqual(viewModel.scene.latestReleaseTitle, "WordZ 1.0.22")
        XCTAssertEqual(viewModel.scene.latestAssetName, "WordZ-1.0.22-mac-arm64.dmg")
        XCTAssertEqual(viewModel.scene.recentDocuments.count, 1)
        XCTAssertEqual(viewModel.scene.userDataDirectory, "/tmp/wordzmac")

        let exported = viewModel.exportSnapshot()
        XCTAssertEqual(exported.zoom, 135)
        XCTAssertEqual(exported.fontScale, 120)
        XCTAssertEqual(exported.fontFamily, "SF Mono")
        XCTAssertFalse(exported.showWelcomeScreen)
        XCTAssertFalse(exported.restoreWorkspace)
        XCTAssertTrue(exported.debugLogging)

        let exportedHost = viewModel.exportHostPreferences()
        XCTAssertTrue(exportedHost.autoUpdateEnabled)
        XCTAssertEqual(exportedHost.languageMode, .english)
        XCTAssertEqual(exportedHost.recentDocuments.count, 1)
        XCTAssertEqual(exportedHost.lastUpdateStatus, "发现新版本 1.0.22，可下载更新包。")
    }

    func testSettingsSceneDefaultsRemainStable() {
        XCTAssertEqual(SettingsPaneSceneModel.empty.workspaceSummary, "等待载入本地语料库")
        XCTAssertEqual(SettingsPaneSceneModel.empty.buildSummary, "SwiftUI + Swift native engine")
        XCTAssertEqual(SettingsPaneSceneModel.empty.zoomLabel, "100%")
        XCTAssertEqual(SettingsPaneSceneModel.empty.fontScaleLabel, "100%")
    }
}
