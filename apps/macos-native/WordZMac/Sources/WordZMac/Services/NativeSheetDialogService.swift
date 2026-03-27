import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
protocol NativeDialogServicing: AnyObject {
    func attach(window: NSWindow?)
    func chooseImportPaths() async -> [String]?
    func chooseDirectory(title: String, message: String) async -> String?
    func chooseSavePath(title: String, suggestedName: String, allowedExtension: String) async -> String?
    func chooseExportFormat() async -> TableExportFormat?
    func promptText(title: String, message: String, defaultValue: String, confirmTitle: String) async -> String?
    func confirm(title: String, message: String, confirmTitle: String) async -> Bool
}

@MainActor
final class NativeSheetDialogService: NativeDialogServicing {
    private weak var window: NSWindow?
    private var languageMode: AppLanguageMode {
        WordZLocalization.shared.effectiveMode
    }

    func attach(window: NSWindow?) {
        self.window = window
    }

    func chooseImportPaths() async -> [String]? {
        let panel = NSOpenPanel()
        panel.title = t("导入语料", "Import Corpora")
        panel.message = t("选择要导入的文本文件或文件夹", "Choose text files or folders to import")
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        return await presentOpenPanel(panel)?.map(\.path)
    }

    func chooseDirectory(title: String, message: String) async -> String? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.message = message
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        return await presentOpenPanel(panel)?.first?.path
    }

    func chooseSavePath(title: String, suggestedName: String, allowedExtension: String) async -> String? {
        let panel = NSSavePanel()
        panel.title = title
        panel.nameFieldStringValue = suggestedName
        if let contentType = UTType(filenameExtension: allowedExtension) {
            panel.allowedContentTypes = [contentType]
        }
        panel.canCreateDirectories = true
        return await presentSavePanel(panel)?.path
    }

    func chooseExportFormat() async -> TableExportFormat? {
        let alert = NSAlert()
        alert.messageText = t("选择导出格式", "Choose Export Format")
        alert.informativeText = t("你可以导出为 Excel（.xlsx）或 CSV（.csv）。", "You can export as Excel (.xlsx) or CSV (.csv).")
        alert.addButton(withTitle: "Excel (.xlsx)")
        alert.addButton(withTitle: "CSV (.csv)")
        alert.addButton(withTitle: t("取消", "Cancel"))
        switch await presentAlert(alert) {
        case .alertFirstButtonReturn:
            return .xlsx
        case .alertSecondButtonReturn:
            return .csv
        default:
            return nil
        }
    }

    func promptText(title: String, message: String, defaultValue: String, confirmTitle: String) async -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: t("取消", "Cancel"))
        let field = NSTextField(string: defaultValue)
        field.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
        alert.accessoryView = field
        let response = await presentAlert(alert)
        guard response == .alertFirstButtonReturn else { return nil }
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    func confirm(title: String, message: String, confirmTitle: String) async -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: confirmTitle)
        alert.addButton(withTitle: t("取消", "Cancel"))
        return await presentAlert(alert) == .alertFirstButtonReturn
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }

    private func presentOpenPanel(_ panel: NSOpenPanel) async -> [URL]? {
        await withCheckedContinuation { continuation in
            if let window {
                panel.beginSheetModal(for: window) { response in
                    continuation.resume(returning: response == .OK ? panel.urls : nil)
                }
            } else {
                let response = panel.runModal()
                continuation.resume(returning: response == .OK ? panel.urls : nil)
            }
        }
    }

    private func presentSavePanel(_ panel: NSSavePanel) async -> URL? {
        await withCheckedContinuation { continuation in
            if let window {
                panel.beginSheetModal(for: window) { response in
                    continuation.resume(returning: response == .OK ? panel.url : nil)
                }
            } else {
                let response = panel.runModal()
                continuation.resume(returning: response == .OK ? panel.url : nil)
            }
        }
    }

    private func presentAlert(_ alert: NSAlert) async -> NSApplication.ModalResponse {
        await withCheckedContinuation { continuation in
            if let window {
                alert.beginSheetModal(for: window) { response in
                    continuation.resume(returning: response)
                }
            } else {
                let response = alert.runModal()
                continuation.resume(returning: response)
            }
        }
    }
}
