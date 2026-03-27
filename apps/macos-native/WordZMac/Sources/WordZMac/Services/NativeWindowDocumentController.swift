import AppKit
import Foundation

@MainActor
final class NativeWindowDocumentController: ObservableObject {
    private weak var window: NSWindow?

    func attach(window: NSWindow?) {
        self.window = window
    }

    func sync(displayName: String, representedPath: String, edited: Bool) {
        guard let window else { return }
        let trimmedTitle = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            window.title = trimmedTitle
        }

        let trimmedPath = representedPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPath.isEmpty {
            window.representedURL = nil
        } else {
            window.representedURL = URL(fileURLWithPath: trimmedPath)
        }

        window.isDocumentEdited = edited
    }
}
