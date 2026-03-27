import AppKit
import Foundation

@MainActor
protocol NativeHostActionServicing: AnyObject {
    func openUserDataDirectory(path: String) async throws
    func openFeedback() async throws
    func openReleaseNotes() async throws
    func openProjectHome() async throws
    func openDownloadedUpdate(path: String) async throws
    func revealDownloadedUpdate(path: String) async throws
    func exportDiagnostics(report: String, suggestedName: String) async throws -> String?
    func clearRecentDocuments() async throws
    func noteRecentDocument(path: String) async
}

@MainActor
final class NativeHostActionService: NativeHostActionServicing {
    private let dialogService: NativeDialogServicing
    private let workspace = NSWorkspace.shared
    private let homepageURL = URL(string: "https://github.com/zzwdh/WordZ")!
    private let feedbackURL = URL(string: "https://github.com/zzwdh/WordZ/issues/new/choose")!
    private let releasesURL = URL(string: "https://github.com/zzwdh/WordZ/releases")!

    init(dialogService: NativeDialogServicing) {
        self.dialogService = dialogService
    }

    private var languageMode: AppLanguageMode {
        WordZLocalization.shared.effectiveMode
    }

    func openUserDataDirectory(path: String) async throws {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        guard workspace.open(url) else {
            throw NSError(domain: "WordZMac.NativeHostActionService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: t("无法在 Finder 中打开用户数据目录。", "Unable to open the user data directory in Finder.")
            ])
        }
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

    func openDownloadedUpdate(path: String) async throws {
        let url = URL(fileURLWithPath: path)
        guard workspace.open(url) else {
            throw NSError(domain: "WordZMac.NativeHostActionService", code: 3, userInfo: [
                NSLocalizedDescriptionKey: t("无法打开已下载的更新包。", "Unable to open the downloaded update package.")
            ])
        }
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

    func exportDiagnostics(report: String, suggestedName: String) async throws -> String? {
        guard let destinationPath = await dialogService.chooseSavePath(
            title: t("导出诊断报告", "Export Diagnostics"),
            suggestedName: suggestedName,
            allowedExtension: "txt"
        ) else {
            return nil
        }
        let destinationURL = URL(fileURLWithPath: destinationPath)
        try report.write(to: destinationURL, atomically: true, encoding: .utf8)
        return destinationPath
    }

    func clearRecentDocuments() async throws {
        NSDocumentController.shared.clearRecentDocuments(self)
    }

    func noteRecentDocument(path: String) async {
        guard !path.isEmpty else { return }
        NSDocumentController.shared.noteNewRecentDocumentURL(URL(fileURLWithPath: path))
    }

    private func open(url: URL, errorDescription: String) throws {
        guard workspace.open(url) else {
            throw NSError(domain: "WordZMac.NativeHostActionService", code: 2, userInfo: [
                NSLocalizedDescriptionKey: errorDescription
            ])
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
