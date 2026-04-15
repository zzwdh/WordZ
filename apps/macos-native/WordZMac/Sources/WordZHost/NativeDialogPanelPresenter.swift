import AppKit
import Foundation
import UniformTypeIdentifiers

package struct NativeOpenPanelRequest: Equatable {
    package let title: String
    package let message: String
    package let canChooseFiles: Bool
    package let canChooseDirectories: Bool
    package let allowsMultipleSelection: Bool
    package let canCreateDirectories: Bool
    package let allowedExtensions: [String]

    package init(
        title: String,
        message: String,
        canChooseFiles: Bool,
        canChooseDirectories: Bool,
        allowsMultipleSelection: Bool,
        canCreateDirectories: Bool,
        allowedExtensions: [String] = []
    ) {
        self.title = title
        self.message = message
        self.canChooseFiles = canChooseFiles
        self.canChooseDirectories = canChooseDirectories
        self.allowsMultipleSelection = allowsMultipleSelection
        self.canCreateDirectories = canCreateDirectories
        self.allowedExtensions = allowedExtensions
    }
}

package struct NativeSavePanelRequest: Equatable {
    package let title: String
    package let suggestedName: String
    package let allowedExtension: String
    package let canCreateDirectories: Bool

    package init(
        title: String,
        suggestedName: String,
        allowedExtension: String,
        canCreateDirectories: Bool = true
    ) {
        self.title = title
        self.suggestedName = suggestedName
        self.allowedExtension = allowedExtension
        self.canCreateDirectories = canCreateDirectories
    }
}

package enum NativeAlertStyle: Equatable {
    case informational
    case warning
}

package struct NativeAlertRequest: Equatable {
    package let messageText: String
    package let informativeText: String
    package let style: NativeAlertStyle
    package let buttons: [String]

    package init(
        messageText: String,
        informativeText: String,
        style: NativeAlertStyle = .informational,
        buttons: [String]
    ) {
        self.messageText = messageText
        self.informativeText = informativeText
        self.style = style
        self.buttons = buttons
    }
}

package enum NativeAlertSelection: Equatable {
    case button(index: Int)
    case cancel
}

package struct NativeTextPromptRequest: Equatable {
    package let title: String
    package let message: String
    package let defaultValue: String
    package let confirmTitle: String
    package let cancelTitle: String

    package init(
        title: String,
        message: String,
        defaultValue: String,
        confirmTitle: String,
        cancelTitle: String
    ) {
        self.title = title
        self.message = message
        self.defaultValue = defaultValue
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
    }
}

@MainActor
package protocol NativeDialogPanelPresenting: AnyObject {
    func presentOpenPanel(_ request: NativeOpenPanelRequest, presentationWindow: NSWindow?) async -> [URL]?
    func presentSavePanel(_ request: NativeSavePanelRequest, presentationWindow: NSWindow?) async -> URL?
    func presentAlert(_ request: NativeAlertRequest, presentationWindow: NSWindow?) async -> NativeAlertSelection
    func presentTextPrompt(_ request: NativeTextPromptRequest, presentationWindow: NSWindow?) async -> String?
}

@MainActor
package final class NativeDialogPanelPresenter: NativeDialogPanelPresenting {
    package init() {}

    package func presentOpenPanel(_ request: NativeOpenPanelRequest, presentationWindow: NSWindow?) async -> [URL]? {
        let panel = NSOpenPanel()
        panel.title = request.title
        panel.message = request.message
        panel.canChooseFiles = request.canChooseFiles
        panel.canChooseDirectories = request.canChooseDirectories
        panel.allowsMultipleSelection = request.allowsMultipleSelection
        panel.canCreateDirectories = request.canCreateDirectories
        panel.allowedContentTypes = request.allowedExtensions.compactMap { UTType(filenameExtension: $0) }

        return await withCheckedContinuation { continuation in
            if let presentationWindow {
                panel.beginSheetModal(for: presentationWindow) { response in
                    continuation.resume(returning: response == .OK ? panel.urls : nil)
                }
            } else {
                let response = panel.runModal()
                continuation.resume(returning: response == .OK ? panel.urls : nil)
            }
        }
    }

    package func presentSavePanel(_ request: NativeSavePanelRequest, presentationWindow: NSWindow?) async -> URL? {
        let panel = NSSavePanel()
        panel.title = request.title
        panel.nameFieldStringValue = request.suggestedName
        panel.canCreateDirectories = request.canCreateDirectories
        if let contentType = UTType(filenameExtension: request.allowedExtension) {
            panel.allowedContentTypes = [contentType]
        }

        return await withCheckedContinuation { continuation in
            if let presentationWindow {
                panel.beginSheetModal(for: presentationWindow) { response in
                    continuation.resume(returning: response == .OK ? panel.url : nil)
                }
            } else {
                let response = panel.runModal()
                continuation.resume(returning: response == .OK ? panel.url : nil)
            }
        }
    }

    package func presentAlert(_ request: NativeAlertRequest, presentationWindow: NSWindow?) async -> NativeAlertSelection {
        let alert = NSAlert()
        alert.messageText = request.messageText
        alert.informativeText = request.informativeText
        alert.alertStyle = request.style == .warning ? .warning : .informational
        request.buttons.forEach { alert.addButton(withTitle: $0) }

        let response = await withCheckedContinuation { continuation in
            if let presentationWindow {
                alert.beginSheetModal(for: presentationWindow) { response in
                    continuation.resume(returning: response)
                }
            } else {
                continuation.resume(returning: alert.runModal())
            }
        }
        return selection(for: response, buttonCount: request.buttons.count)
    }

    package func presentTextPrompt(_ request: NativeTextPromptRequest, presentationWindow: NSWindow?) async -> String? {
        let alert = NSAlert()
        alert.messageText = request.title
        alert.informativeText = request.message
        alert.addButton(withTitle: request.confirmTitle)
        alert.addButton(withTitle: request.cancelTitle)

        let field = NSTextField(string: request.defaultValue)
        field.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
        alert.accessoryView = field

        let response = await withCheckedContinuation { continuation in
            if let presentationWindow {
                alert.beginSheetModal(for: presentationWindow) { response in
                    continuation.resume(returning: response)
                }
            } else {
                continuation.resume(returning: alert.runModal())
            }
        }

        guard selection(for: response, buttonCount: 2) == .button(index: 0) else {
            return nil
        }

        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func selection(for response: NSApplication.ModalResponse, buttonCount: Int) -> NativeAlertSelection {
        let offset = Int(response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue)
        guard offset >= 0, offset < buttonCount else {
            return .cancel
        }
        return .button(index: offset)
    }
}
