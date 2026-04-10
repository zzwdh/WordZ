import AppKit
import Foundation

@MainActor
protocol NativeHostActionServicing: AnyObject {
    func openUserDataDirectory(path: String) async throws
    func openFile(path: String) async throws
    func openURL(_ value: String) async throws
    func openFeedback() async throws
    func openReleaseNotes() async throws
    func openProjectHome() async throws
    func quickLook(path: String) async throws
    func share(paths: [String]) async throws
    func openDownloadedUpdate(path: String) async throws
    func openDownloadedUpdateAndTerminate(path: String) async throws
    func revealDownloadedUpdate(path: String) async throws
    func exportArchiveBundle(archivePath: String, suggestedName: String, title: String, preferredRoute: NativeWindowRoute?) async throws -> String?
    func exportDiagnosticBundle(archivePath: String, suggestedName: String, preferredRoute: NativeWindowRoute?) async throws -> String?
    func clearRecentDocuments() async throws
    func noteRecentDocument(path: String) async
}

@MainActor
final class NativeHostActionService: NativeHostActionServicing {
    private let dialogService: NativeDialogServicing
    private let quickLookService: any NativeQuickLookServicing
    private let sharingService: any NativeSharingServicing
    private let fileManager: FileManager
    private let workspace = NSWorkspace.shared
    private let homepageURL = URL(string: "https://github.com/zzwdh/WordZ")!
    private let feedbackURL = URL(string: "https://github.com/zzwdh/WordZ/issues/new/choose")!
    private let releasesURL = URL(string: "https://github.com/zzwdh/WordZ/releases")!

    init(
        dialogService: NativeDialogServicing,
        quickLookService: any NativeQuickLookServicing = NativeQuickLookService(),
        sharingService: any NativeSharingServicing = NativeSharingService(),
        fileManager: FileManager = .default
    ) {
        self.dialogService = dialogService
        self.quickLookService = quickLookService
        self.sharingService = sharingService
        self.fileManager = fileManager
    }

    private var languageMode: AppLanguageMode {
        WordZLocalization.shared.effectiveMode
    }

    func openUserDataDirectory(path: String) async throws {
        try openFileURL(
            URL(fileURLWithPath: path, isDirectory: true),
            errorDescription: t("无法在 Finder 中打开用户数据目录。", "Unable to open the user data directory in Finder."),
            errorCode: 1
        )
    }

    func openFile(path: String) async throws {
        try openFileURL(
            URL(fileURLWithPath: path),
            errorDescription: t("无法打开文件。", "Unable to open the file."),
            errorCode: 5
        )
    }

    func openURL(_ value: String) async throws {
        guard let url = URL(string: value) else {
            throw NSError(domain: "WordZMac.NativeHostActionService", code: 6, userInfo: [
                NSLocalizedDescriptionKey: t("无效的链接地址。", "The URL is invalid.")
            ])
        }
        try open(url: url, errorDescription: t("无法打开链接。", "Unable to open the URL."), errorCode: 7)
    }

    func openFeedback() async throws {
        try open(url: feedbackURL, errorDescription: t("无法打开反馈页面。", "Unable to open the feedback page."))
    }

    func openReleaseNotes() async throws {
        try open(url: releasesURL, errorDescription: t("无法打开版本说明页面。", "Unable to open the release notes page."))
    }

    func openProjectHome() async throws {
        try open(url: homepageURL, errorDescription: t("无法打开项目主页。", "Unable to open the project home page."))
    }

    func quickLook(path: String) async throws {
        try quickLookService.preview(path: path)
    }

    func share(paths: [String]) async throws {
        try sharingService.share(paths: paths)
    }

    func openDownloadedUpdate(path: String) async throws {
        try openFileURL(
            URL(fileURLWithPath: path),
            errorDescription: t("无法打开已下载的更新包。", "Unable to open the downloaded update package."),
            errorCode: 3
        )
    }

    func openDownloadedUpdateAndTerminate(path: String) async throws {
        try await openDownloadedUpdate(path: path)
        try? await Task.sleep(nanoseconds: 500_000_000)
        NSApplication.shared.terminate(nil)
    }

    func revealDownloadedUpdate(path: String) async throws {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw NSError(domain: "WordZMac.NativeHostActionService", code: 4, userInfo: [
                NSLocalizedDescriptionKey: t("已下载更新包不存在。", "The downloaded update package could not be found.")
            ])
        }
        workspace.activateFileViewerSelecting([url])
    }

    func exportArchiveBundle(
        archivePath: String,
        suggestedName: String,
        title: String,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws -> String? {
        guard let destinationPath = await dialogService.chooseSavePath(
            title: title,
            suggestedName: suggestedName,
            allowedExtension: "zip",
            preferredRoute: preferredRoute
        ) else {
            return nil
        }
        let sourceURL = URL(fileURLWithPath: archivePath)
        let destinationURL = URL(fileURLWithPath: destinationPath)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationPath
    }

    func exportDiagnosticBundle(
        archivePath: String,
        suggestedName: String,
        preferredRoute: NativeWindowRoute? = nil
    ) async throws -> String? {
        try await exportArchiveBundle(
            archivePath: archivePath,
            suggestedName: suggestedName,
            title: t("导出诊断包", "Export Diagnostics Bundle"),
            preferredRoute: preferredRoute
        )
    }

    func clearRecentDocuments() async throws {
        NSDocumentController.shared.clearRecentDocuments(self)
    }

    func noteRecentDocument(path: String) async {
        guard !path.isEmpty else { return }
        NSDocumentController.shared.noteNewRecentDocumentURL(URL(fileURLWithPath: path))
    }

    private func openFileURL(_ url: URL, errorDescription: String, errorCode: Int) throws {
        guard workspace.open(url) else {
            throw NSError(domain: "WordZMac.NativeHostActionService", code: errorCode, userInfo: [
                NSLocalizedDescriptionKey: errorDescription
            ])
        }
    }

    private func open(url: URL, errorDescription: String, errorCode: Int = 2) throws {
        guard workspace.open(url) else {
            throw NSError(domain: "WordZMac.NativeHostActionService", code: errorCode, userInfo: [
                NSLocalizedDescriptionKey: errorDescription
            ])
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
