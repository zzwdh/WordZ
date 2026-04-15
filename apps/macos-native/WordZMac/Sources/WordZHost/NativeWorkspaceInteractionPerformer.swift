import AppKit
import Foundation

@MainActor
package protocol NativeWorkspaceInteractionPerforming: AnyObject {
    func open(_ url: URL) -> Bool
    func revealInFileViewer(_ urls: [URL])
    func clearRecentDocuments()
    func noteRecentDocument(_ url: URL)
    func terminateApplication()
    func copyTextToClipboard(_ text: String)
}

@MainActor
package final class NativeWorkspaceInteractionPerformer: NativeWorkspaceInteractionPerforming {
    private let workspace: NSWorkspace
    private let documentController: NSDocumentController
    private let pasteboard: NSPasteboard
    private let terminateHandler: @MainActor () -> Void

    package init(
        workspace: NSWorkspace = .shared,
        documentController: NSDocumentController = .shared,
        pasteboard: NSPasteboard = .general,
        terminateHandler: @escaping @MainActor () -> Void = { NSApplication.shared.terminate(nil) }
    ) {
        self.workspace = workspace
        self.documentController = documentController
        self.pasteboard = pasteboard
        self.terminateHandler = terminateHandler
    }

    package func open(_ url: URL) -> Bool {
        workspace.open(url)
    }

    package func revealInFileViewer(_ urls: [URL]) {
        workspace.activateFileViewerSelecting(urls)
    }

    package func clearRecentDocuments() {
        documentController.clearRecentDocuments(self)
    }

    package func noteRecentDocument(_ url: URL) {
        documentController.noteNewRecentDocumentURL(url)
    }

    package func terminateApplication() {
        terminateHandler()
    }

    package func copyTextToClipboard(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
