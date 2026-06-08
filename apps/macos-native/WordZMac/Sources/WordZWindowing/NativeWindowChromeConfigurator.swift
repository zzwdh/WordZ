import AppKit
import Foundation

@MainActor
package struct NativeWindowChromeConfigurator {
    package init() {}

    package func apply(to window: NSWindow?, route: NativeWindowRoute) {
        guard let window else { return }

        if window.styleMask.contains(.fullSizeContentView) {
            window.styleMask.remove(.fullSizeContentView)
        }

        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.isMovableByWindowBackground = false

        switch route {
        case .mainWorkspace:
            window.toolbarStyle = .automatic
        case .library, .settings, .updatePrompt, .about, .help, .releaseNotes, .sourceReader:
            window.toolbarStyle = .automatic
        }
    }
}
