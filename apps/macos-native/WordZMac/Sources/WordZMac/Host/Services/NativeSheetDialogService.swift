import AppKit
import Foundation
import WordZHost

@MainActor
protocol NativeDialogServicing: AnyObject {
    func chooseImportPaths(preferredRoute: NativeWindowRoute?) async -> [String]?
    func chooseOpenPath(title: String, message: String, allowedExtensions: [String], preferredRoute: NativeWindowRoute?) async -> String?
    func chooseDirectory(title: String, message: String, preferredRoute: NativeWindowRoute?) async -> String?
    func chooseSavePath(title: String, suggestedName: String, allowedExtension: String, preferredRoute: NativeWindowRoute?) async -> String?
    func chooseExportFormat(preferredRoute: NativeWindowRoute?) async -> TableExportFormat?
    func promptText(title: String, message: String, defaultValue: String, confirmTitle: String, preferredRoute: NativeWindowRoute?) async -> String?
    func confirm(title: String, message: String, confirmTitle: String, preferredRoute: NativeWindowRoute?) async -> Bool
}

@MainActor
final class NativeSheetDialogService: NativeDialogServicing {
    private let panelPresenter: any NativeDialogPanelPresenting
    private let presentationWindowProvider: @MainActor (NativeWindowRoute?) -> NSWindow?

    init(
        panelPresenter: any NativeDialogPanelPresenting = NativeDialogPanelPresenter(),
        presentationWindowProvider: @escaping @MainActor (NativeWindowRoute?) -> NSWindow? = {
            NativeWindowRouting.presentationWindow(preferredRoute: $0)
        }
    ) {
        self.panelPresenter = panelPresenter
        self.presentationWindowProvider = presentationWindowProvider
    }

    private var languageMode: AppLanguageMode {
        WordZLocalization.shared.effectiveMode
    }

    func chooseImportPaths(preferredRoute: NativeWindowRoute? = nil) async -> [String]? {
        let request = NativeOpenPanelRequest(
            title: t("导入语料", "Import Corpora"),
            message: t(
                "选择要导入的 TXT、DOCX、PDF 文件或文件夹（文件夹会递归扫描）",
                "Choose TXT, DOCX, PDF files or folders to import (folders are scanned recursively)"
            ),
            canChooseFiles: true,
            canChooseDirectories: true,
            allowsMultipleSelection: true,
            canCreateDirectories: false,
            allowedExtensions: ImportedDocumentReadingSupport.supportedImportExtensions
        )
        return await panelPresenter.presentOpenPanel(
            request,
            presentationWindow: presentationWindowProvider(preferredRoute)
        )?.map(\.path)
    }

    func chooseDirectory(title: String, message: String, preferredRoute: NativeWindowRoute? = nil) async -> String? {
        let request = NativeOpenPanelRequest(
            title: title,
            message: message,
            canChooseFiles: false,
            canChooseDirectories: true,
            allowsMultipleSelection: false,
            canCreateDirectories: true
        )
        return await panelPresenter.presentOpenPanel(
            request,
            presentationWindow: presentationWindowProvider(preferredRoute)
        )?.first?.path
    }

    func chooseOpenPath(
        title: String,
        message: String,
        allowedExtensions: [String],
        preferredRoute: NativeWindowRoute? = nil
    ) async -> String? {
        let request = NativeOpenPanelRequest(
            title: title,
            message: message,
            canChooseFiles: true,
            canChooseDirectories: false,
            allowsMultipleSelection: false,
            canCreateDirectories: false,
            allowedExtensions: allowedExtensions
        )
        return await panelPresenter.presentOpenPanel(
            request,
            presentationWindow: presentationWindowProvider(preferredRoute)
        )?.first?.path
    }

    func chooseSavePath(
        title: String,
        suggestedName: String,
        allowedExtension: String,
        preferredRoute: NativeWindowRoute? = nil
    ) async -> String? {
        let request = NativeSavePanelRequest(
            title: title,
            suggestedName: suggestedName,
            allowedExtension: allowedExtension
        )
        return await panelPresenter.presentSavePanel(
            request,
            presentationWindow: presentationWindowProvider(preferredRoute)
        )?.path
    }

    func chooseExportFormat(preferredRoute: NativeWindowRoute? = nil) async -> TableExportFormat? {
        let request = NativeAlertRequest(
            messageText: t("选择导出格式", "Choose Export Format"),
            informativeText: t("你可以导出为 Excel（.xlsx）或 CSV（.csv）。", "You can export as Excel (.xlsx) or CSV (.csv)."),
            buttons: ["Excel (.xlsx)", "CSV (.csv)", t("取消", "Cancel")]
        )
        switch await panelPresenter.presentAlert(
            request,
            presentationWindow: presentationWindowProvider(preferredRoute)
        ) {
        case .button(index: 0):
            return .xlsx
        case .button(index: 1):
            return .csv
        default:
            return nil
        }
    }

    func promptText(
        title: String,
        message: String,
        defaultValue: String,
        confirmTitle: String,
        preferredRoute: NativeWindowRoute? = nil
    ) async -> String? {
        let request = NativeTextPromptRequest(
            title: title,
            message: message,
            defaultValue: defaultValue,
            confirmTitle: confirmTitle,
            cancelTitle: t("取消", "Cancel")
        )
        return await panelPresenter.presentTextPrompt(
            request,
            presentationWindow: presentationWindowProvider(preferredRoute)
        )
    }

    func confirm(
        title: String,
        message: String,
        confirmTitle: String,
        preferredRoute: NativeWindowRoute? = nil
    ) async -> Bool {
        let request = NativeAlertRequest(
            messageText: title,
            informativeText: message,
            style: .warning,
            buttons: [confirmTitle, t("取消", "Cancel")]
        )
        return await panelPresenter.presentAlert(
            request,
            presentationWindow: presentationWindowProvider(preferredRoute)
        ) == .button(index: 0)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
