import Foundation
import WordZExport
import WordZHost
import WordZShared
import WordZWindowing
@testable import WordZWorkspaceCore

struct FakeBuildMetadataProvider: NativeBuildMetadataProviding {
    var metadata = NativeBuildMetadata(
        appName: "WordZ",
        bundleIdentifier: "com.test.wordz",
        version: "1.0",
        buildNumber: "1",
        architecture: "arm64",
        builtAt: "2026-04-08",
        gitCommit: "test-commit",
        gitBranch: "test",
        distributionChannel: "test",
        executableSHA256: "sha256"
        ,
        bundlePath: "/Applications/WordZ.app",
        executablePath: "/Applications/WordZ.app/Contents/MacOS/WordZ",
        sourceLabel: "test"
    )

    func current() -> NativeBuildMetadata {
        metadata
    }
}

@MainActor
final class FakeDialogService: NativeDialogServicing {
    var importPathsResult: [String]?
    var openPathResult: String?
    var directoryResult: String?
    var savePathResult: String?
    var exportFormatResult: TableExportFormat? = .csv
    var promptTextResult: String?
    var confirmResult = true
    var openPathPreferredRoute: NativeWindowRoute?
    var promptTextPreferredRoute: NativeWindowRoute?
    var savePathPreferredRoute: NativeWindowRoute?
    var confirmPreferredRoute: NativeWindowRoute?
    var confirmCallCount = 0
    var confirmTitle: String?
    var confirmMessage: String?
    var promptTextTitle: String?
    var promptTextMessage: String?
    var promptTextDefaultValue: String?
    var promptTextConfirmTitle: String?

    func chooseImportPaths(preferredRoute: NativeWindowRoute?) async -> [String]? {
        return importPathsResult
    }

    func chooseOpenPath(
        title: String,
        message: String,
        allowedExtensions: [String],
        preferredRoute: NativeWindowRoute?
    ) async -> String? {
        openPathPreferredRoute = preferredRoute
        return openPathResult
    }

    func chooseDirectory(title: String, message: String, preferredRoute: NativeWindowRoute?) async -> String? {
        return directoryResult
    }

    func chooseSavePath(
        title: String,
        suggestedName: String,
        allowedExtension: String,
        preferredRoute: NativeWindowRoute?
    ) async -> String? {
        savePathPreferredRoute = preferredRoute
        return savePathResult
    }

    func chooseExportFormat(preferredRoute: NativeWindowRoute?) async -> TableExportFormat? {
        return exportFormatResult
    }

    func promptText(
        title: String,
        message: String,
        defaultValue: String,
        confirmTitle: String,
        preferredRoute: NativeWindowRoute?
    ) async -> String? {
        promptTextTitle = title
        promptTextMessage = message
        promptTextDefaultValue = defaultValue
        promptTextConfirmTitle = confirmTitle
        promptTextPreferredRoute = preferredRoute
        return promptTextResult
    }

    func confirm(
        title: String,
        message: String,
        confirmTitle: String,
        preferredRoute: NativeWindowRoute?
    ) async -> Bool {
        confirmCallCount += 1
        self.confirmTitle = title
        confirmMessage = message
        confirmPreferredRoute = preferredRoute
        return confirmResult
    }
}

@MainActor
final class InMemoryHostPreferencesStore: NativeHostPreferencesStoring {
    var snapshot = NativeHostPreferencesSnapshot.default
    var saveCallCount = 0
    var recordRecentCallCount = 0
    var clearRecentCallCount = 0
    var recordUpdateCheckCallCount = 0
    var recordDownloadedUpdateCallCount = 0
    var clearDownloadedUpdateCallCount = 0

    func load() -> NativeHostPreferencesSnapshot {
        snapshot
    }

    func save(_ snapshot: NativeHostPreferencesSnapshot) throws {
        saveCallCount += 1
        self.snapshot = snapshot
    }

    func recordRecentDocument(
        corpusID: String,
        title: String,
        subtitle: String,
        representedPath: String
    ) throws -> NativeHostPreferencesSnapshot {
        recordRecentCallCount += 1
        snapshot.recentDocuments.removeAll { $0.corpusID == corpusID }
        snapshot.recentDocuments.insert(
            RecentDocumentItem(
                corpusID: corpusID,
                title: title,
                subtitle: subtitle,
                representedPath: representedPath,
                lastOpenedAt: "2026-03-26T00:00:00Z"
            ),
            at: 0
        )
        return snapshot
    }

    func clearRecentDocuments() throws -> NativeHostPreferencesSnapshot {
        clearRecentCallCount += 1
        snapshot.recentDocuments = []
        return snapshot
    }

    func recordUpdateCheck(status: String) throws -> NativeHostPreferencesSnapshot {
        recordUpdateCheckCallCount += 1
        snapshot.lastUpdateCheckAt = "2026-03-26T00:00:00Z"
        snapshot.lastUpdateStatus = status
        return snapshot
    }

    func recordDownloadedUpdate(version: String, name: String, path: String) throws -> NativeHostPreferencesSnapshot {
        recordDownloadedUpdateCallCount += 1
        snapshot.downloadedUpdateVersion = version
        snapshot.downloadedUpdateName = name
        snapshot.downloadedUpdatePath = path
        return snapshot
    }

    func clearDownloadedUpdate() throws -> NativeHostPreferencesSnapshot {
        clearDownloadedUpdateCallCount += 1
        snapshot.downloadedUpdateVersion = ""
        snapshot.downloadedUpdateName = ""
        snapshot.downloadedUpdatePath = ""
        return snapshot
    }
}

@MainActor
final class FakeHostActionService: NativeHostActionServicing {
    var openedFilePaths: [String] = []
    var openedExternalURLs: [String] = []
    var copiedClipboardTexts: [String] = []
    var quickLookCallCount = 0
    var lastQuickLookPath: String?
    var shareCallCount = 0
    var lastSharedPaths: [String] = []
    var openDownloadedUpdateAndTerminateCallCount = 0
    var lastInstalledDownloadedUpdatePath: String?
    var revealDownloadedUpdateCallCount = 0
    var lastRevealedDownloadedUpdatePath: String?
    var clearRecentDocumentsCallCount = 0
    var exportedArchivePath: String?
    var exportedArchiveTitle: String?
    var exportedArchivePathToReturn: String? = "/tmp/WordZMac-report.zip"
    var exportedArchivePreferredRoute: NativeWindowRoute?
    var exportedDiagnosticArchivePath: String?
    var exportedPathToReturn: String? = "/tmp/WordZMac-diagnostics.zip"
    var exportedDiagnosticPreferredRoute: NativeWindowRoute?

    func openUserDataDirectory(path: String) async throws {
    }

    func openFile(path: String) async throws {
        openedFilePaths.append(path)
    }

    func openURL(_ value: String) async throws {
        openedExternalURLs.append(value)
    }

    func openFeedback() async throws {
    }

    func openReleaseNotes() async throws {
    }

    func openProjectHome() async throws {
    }

    func quickLook(path: String) async throws {
        quickLookCallCount += 1
        lastQuickLookPath = path
    }

    func share(paths: [String]) async throws {
        shareCallCount += 1
        lastSharedPaths = paths
    }

    func openDownloadedUpdate(path: String) async throws {
    }

    func openDownloadedUpdateAndTerminate(path: String) async throws {
        openDownloadedUpdateAndTerminateCallCount += 1
        lastInstalledDownloadedUpdatePath = path
    }

    func revealDownloadedUpdate(path: String) async throws {
        revealDownloadedUpdateCallCount += 1
        lastRevealedDownloadedUpdatePath = path
    }

    func exportArchiveBundle(
        archivePath: String,
        suggestedName: String,
        title: String,
        preferredRoute: NativePresentationRouteHint?
    ) async throws -> String? {
        exportedArchivePath = archivePath
        exportedArchiveTitle = title
        exportedArchivePreferredRoute = preferredRoute?.nativeWindowRoute
        return exportedArchivePathToReturn
    }

    func exportDiagnosticBundle(
        archivePath: String,
        suggestedName: String,
        preferredRoute: NativePresentationRouteHint?
    ) async throws -> String? {
        exportedDiagnosticArchivePath = archivePath
        exportedDiagnosticPreferredRoute = preferredRoute?.nativeWindowRoute
        return exportedPathToReturn
    }

    func clearRecentDocuments() async throws {
        clearRecentDocumentsCallCount += 1
    }

    func noteRecentDocument(path: String) async {}

    func copyTextToClipboard(_ text: String) {
        copiedClipboardTexts.append(text)
    }
}

final class FakeDiagnosticsBundleService: NativeDiagnosticsBundleServicing {
    var artifactToReturn = NativeDiagnosticsBundleArtifact(
        archiveURL: URL(fileURLWithPath: "/tmp/WordZMac-diagnostics.zip"),
        workingDirectoryURL: URL(fileURLWithPath: "/tmp/WordZMac-diagnostics")
    )
    private(set) var lastPayload: NativeDiagnosticsBundlePayload?
    private(set) var cleanedArtifacts: [NativeDiagnosticsBundleArtifact] = []

    func buildBundle(payload: NativeDiagnosticsBundlePayload) throws -> NativeDiagnosticsBundleArtifact {
        lastPayload = payload
        return artifactToReturn
    }

    func cleanup(_ artifact: NativeDiagnosticsBundleArtifact) {
        cleanedArtifacts.append(artifact)
    }
}

@MainActor
final class FakeAnalysisReportBundleService: AnalysisReportBundleServicing {
    var artifactToReturn = AnalysisReportBundleArtifact(
        workingDirectoryURL: URL(fileURLWithPath: "/tmp/WordZMac-report"),
        bundleDirectoryURL: URL(fileURLWithPath: "/tmp/WordZMac-report/WordZMac-stats-report"),
        archiveURL: URL(fileURLWithPath: "/tmp/WordZMac-report.zip")
    )
    private(set) var lastPayload: AnalysisReportBundlePayload?
    private(set) var cleanedArtifacts: [AnalysisReportBundleArtifact] = []

    func buildBundle(payload: AnalysisReportBundlePayload) throws -> AnalysisReportBundleArtifact {
        lastPayload = payload
        return artifactToReturn
    }

    func cleanup(_ artifact: AnalysisReportBundleArtifact) {
        cleanedArtifacts.append(artifact)
    }
}

@MainActor
final class FakeUpdateService: NativeUpdateServicing {
    var checkCallCount = 0
    var downloadCallCount = 0
    var checkDelayNanoseconds: UInt64 = 0
    var downloadDelayNanoseconds: UInt64 = 0
    var result = NativeUpdateCheckResult(
        currentVersion: "1.1.0",
        latestVersion: "1.1.1",
        releaseURL: "https://github.com/zzwdh/WordZ/releases/tag/v1.1.1",
        statusMessage: "发现新版本 1.1.1，可前往发布页下载安装。",
        updateAvailable: true,
        asset: NativeUpdateAsset(
            name: "WordZ-1.1.1-mac-arm64.dmg",
            downloadURL: "https://example.com/WordZ-1.1.1-mac-arm64.dmg"
        ),
        releaseTitle: "WordZ 1.1.1",
        publishedAt: "2026-03-26T00:00:00Z",
        releaseNotes: ["Native table layout persistence"]
    )
    var downloadResult = NativeDownloadedUpdate(
        version: "1.1.1",
        assetName: "WordZ-1.1.1-mac-arm64.dmg",
        localPath: "/tmp/WordZ-1.1.1-mac-arm64.dmg",
        releaseURL: "https://github.com/zzwdh/WordZ/releases/tag/v1.1.1"
    )
    var error: Error?
    var downloadError: Error?

    func checkForUpdates(currentVersion: String) async throws -> NativeUpdateCheckResult {
        checkCallCount += 1
        if checkDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: checkDelayNanoseconds)
        }
        if let error { throw error }
        return NativeUpdateCheckResult(
            currentVersion: currentVersion,
            latestVersion: result.latestVersion,
            releaseURL: result.releaseURL,
            statusMessage: result.statusMessage,
            updateAvailable: result.updateAvailable,
            asset: result.asset,
            releaseTitle: result.releaseTitle,
            publishedAt: result.publishedAt,
            releaseNotes: result.releaseNotes
        )
    }

    func downloadUpdate(
        _ update: NativeUpdateCheckResult,
        onProgress: @escaping @MainActor (Double) -> Void
    ) async throws -> NativeDownloadedUpdate {
        downloadCallCount += 1
        if downloadDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: downloadDelayNanoseconds)
        }
        if let downloadError { throw downloadError }
        onProgress(0.5)
        onProgress(1)
        return downloadResult
    }
}

@MainActor
final class FakeNotificationService: NativeNotificationServicing {
    private(set) var notifications: [(String, String, String)] = []
    var onNotify: (() -> Void)?

    func notify(title: String, subtitle: String, body: String) async {
        notifications.append((title, subtitle, body))
        onNotify?()
    }
}

@MainActor
final class FakeApplicationActivityInspector: ApplicationActivityInspecting {
    var isApplicationActive: Bool
    var shouldDeliverBackgroundNotifications: Bool

    init(
        isApplicationActive: Bool = false,
        shouldDeliverBackgroundNotifications: Bool? = nil
    ) {
        self.isApplicationActive = isApplicationActive
        self.shouldDeliverBackgroundNotifications = shouldDeliverBackgroundNotifications ?? !isApplicationActive
    }
}
