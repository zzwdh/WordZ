import AppKit
import Foundation

@MainActor
package final class NativeWindowDocumentController: ObservableObject, WindowDocumentAttaching, WindowDocumentSyncing {
    private weak var window: NSWindow?

    package init() {}

    package func attach(window: NSWindow?) {
        self.window = window
    }

    package func sync(displayName: String, representedPath: String, edited: Bool) {
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
